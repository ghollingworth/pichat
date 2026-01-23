import os
import time
import tarfile
import shutil
import mimetypes
import re
import json
from bisect import bisect_right
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from google import genai
from google.genai import types
from dotenv import load_dotenv
import tempfile
import traceback
from datetime import datetime

load_dotenv()

app = Flask(__name__, static_folder='static')
CORS(app)

# Initialize Gemini Client
API_KEY = os.getenv("GEMINI_API_KEY")
if not API_KEY:
    raise ValueError("GEMINI_API_KEY not found in environment variables")

client = genai.Client(api_key=API_KEY)
STORE_DISPLAY_NAME = "Raspberry Pi Knowledge Base"
SYSTEM_INSTRUCTION = "You are a helpful and expert Raspberry Pi assistant. "
SYSTEM_INSTRUCTION += "Your goal is to provide accurate, clear, and safe instructions about Raspberry Pi hardware and software. "
SYSTEM_INSTRUCTION += "Use the provided knowledge base to ground your answers. If the information is not in the knowledge base, state that you don't know rather than making up information. Be concise but thorough. "
UPLOAD_FOLDER = 'uploads'
SYSTEM_INSTRUCTIONS_FILE = 'system_instructions.json'

def extract_url_from_file(file_path):
    """Scans the file for a line starting with 'URL: ' and returns the URL."""
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            # Check first 50 lines to be safe
            for _ in range(50):
                line = f.readline()
                if not line:
                    break
                # Match URL: https://... (with optional whitespace)
                match = re.search(r'^URL:\s*(https?://\S+)', line.strip())
                if match:
                    return match.group(1)
    except Exception as e:
        print(f"Error extracting URL from {file_path}: {e}")
    return None

# Ensure upload folder exists
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

def load_custom_instructions():
    """Load custom system instructions from JSON file."""
    if os.path.exists(SYSTEM_INSTRUCTIONS_FILE):
        try:
            with open(SYSTEM_INSTRUCTIONS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading custom instructions: {e}")
            return []
    return []

def save_custom_instructions(instructions):
    """Save custom system instructions to JSON file."""
    try:
        with open(SYSTEM_INSTRUCTIONS_FILE, 'w', encoding='utf-8') as f:
            json.dump(instructions, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving custom instructions: {e}")
        return False

def _build_line_index(text):
    """Return list of (start_offset, end_offset) for each line."""
    lines = text.splitlines(keepends=True)
    line_ranges = []
    offset = 0
    for line in lines:
        start = offset
        offset += len(line)
        line_ranges.append((start, offset))
    if not lines:
        line_ranges.append((0, 0))
    return line_ranges

def _offset_to_line(line_ranges, offset):
    """Map a character offset to a 1-based line number."""
    if not line_ranges:
        return 1
    starts = [start for start, _ in line_ranges]
    index = bisect_right(starts, max(0, offset)) - 1
    if index < 0:
        return 1
    if index >= len(line_ranges):
        return len(line_ranges)
    return index + 1

def extract_markdown_blocks(markdown_text):
    """Extract contiguous non-empty line blocks with line ranges."""
    if markdown_text is None:
        markdown_text = ""
    lines = markdown_text.splitlines()
    blocks = []
    block_start = None
    for idx, line in enumerate(lines, start=1):
        if line.strip():
            if block_start is None:
                block_start = idx
        else:
            if block_start is not None:
                blocks.append({"start_line": block_start, "end_line": idx - 1})
                block_start = None
    if block_start is not None:
        blocks.append({"start_line": block_start, "end_line": len(lines)})
    return blocks

def map_supports_to_lines(markdown_text, grounding_supports):
    """Add start_line/end_line for each grounding support using offsets."""
    if markdown_text is None:
        markdown_text = ""
    line_ranges = _build_line_index(markdown_text)
    supports_with_lines = []
    for support in grounding_supports or []:
        if isinstance(support, dict):
            segment = support.get("segment") or {}
            start_offset = segment.get("start_index", 0)
            end_offset = segment.get("end_index", len(markdown_text))
        else:
            segment = getattr(support, "segment", None)
            if segment and getattr(segment, "start_index", None) is not None:
                start_offset = segment.start_index
            else:
                start_offset = 0
            if segment and getattr(segment, "end_index", None) is not None:
                end_offset = segment.end_index
            else:
                end_offset = len(markdown_text)
        supports_with_lines.append({
            "support": support,
            "start_offset": start_offset,
            "end_offset": end_offset,
            "start_line": _offset_to_line(line_ranges, start_offset),
            "end_line": _offset_to_line(line_ranges, end_offset),
        })
    return supports_with_lines

def render_markdown_with_citations(markdown_text, grounding_supports):
    """
    Convert markdown to HTML and append citation links at the end of the line
    corresponding to each grounding support's end offset.
    """
    if markdown_text is None:
        markdown_text = ""
    blocks = extract_markdown_blocks(markdown_text)
    supports_with_lines = map_supports_to_lines(markdown_text, grounding_supports)

    lines = markdown_text.splitlines()
    line_citations = {}
    for item in supports_with_lines:
        support = item["support"]
        line_no = item["end_line"]
        url = None
        title = None
        citation_urls = None
        if isinstance(support, dict):
            citation_urls = support.get("citation_urls")
        elif hasattr(support, "citation_urls"):
            citation_urls = support.citation_urls
        if citation_urls:
            first = citation_urls[0]
            if isinstance(first, dict):
                url = first.get("url")
                title = first.get("title")
            else:
                url = getattr(first, "url", None)
                title = getattr(first, "title", None)
        if url:
            line_citations.setdefault(line_no, []).append({
                "url": url,
                "title": title,
            })

    # Merge identical citations across consecutive lines by keeping them
    # on the last line of each consecutive block.
    if line_citations:
        sorted_lines = sorted(line_citations.keys())
        last_line_for_url = {}
        for line_no in sorted_lines:
            citations = line_citations.get(line_no, [])
            if not citations:
                continue
            kept = []
            for citation in citations:
                url = citation.get("url")
                if not url:
                    continue
                prev_line = last_line_for_url.get(url)
                if prev_line is not None and prev_line == line_no - 1:
                    # Remove from previous line, keep on current line
                    line_citations[prev_line] = [
                        c for c in line_citations[prev_line]
                        if c.get("url") != url
                    ]
                kept.append(citation)
                last_line_for_url[url] = line_no
            line_citations[line_no] = kept

    for line_no, citations in line_citations.items():
        if 1 <= line_no <= len(lines):
            suffix_parts = []
            for idx, citation in enumerate(citations, start=1):
                label = f"{idx}"
                link = f"[{label}]({citation['url']})"
                suffix_parts.append(link)
            lines[line_no - 1] = lines[line_no - 1].rstrip() + " " + " ".join(suffix_parts)

    annotated_markdown = "\n".join(lines)
    try:
        import importlib
        markdown_it = importlib.import_module("markdown_it")
        markdown_it_class = getattr(markdown_it, "MarkdownIt")
    except Exception as exc:
        raise ImportError("markdown-it-py is required to render markdown to HTML") from exc
    html = markdown_it_class("commonmark").render(annotated_markdown)

    return {
        "markdown": annotated_markdown,
        "html": html,
        "blocks": blocks,
        "supports": [
            {
                "start_line": item["start_line"],
                "end_line": item["end_line"],
                "start_offset": item["start_offset"],
                "end_offset": item["end_offset"],
            }
            for item in supports_with_lines
        ],
    }

def _annotate_text_with_support_brackets(text, grounding_supports):
    """Insert [ at start offsets and ] at end offsets for debugging."""
    if text is None:
        text = ""
    supports_with_lines = map_supports_to_lines(text, grounding_supports)
    insertions = []
    for item in supports_with_lines:
        insertions.append((item["start_offset"], "["))
        insertions.append((item["end_offset"], "]"))
    insertions.sort(key=lambda x: (x[0], 0 if x[1] == "[" else 1))
    result = []
    last = 0
    for offset, marker in insertions:
        offset = max(0, min(offset, len(text)))
        if offset < last:
            continue
        result.append(text[last:offset])
        result.append(marker)
        last = offset
    result.append(text[last:])
    return "".join(result)

def _get_chunk_debug_text(chunk):
    """Best-effort extraction of chunk text/snippet for debugging."""
    if hasattr(chunk, 'retrieved_context') and chunk.retrieved_context:
        rc = chunk.retrieved_context
        for field in ("text", "content", "snippet"):
            value = getattr(rc, field, None)
            if value:
                return value
    if hasattr(chunk, 'web') and chunk.web:
        web = chunk.web
        for field in ("snippet", "text", "content"):
            value = getattr(web, field, None)
            if value:
                return value
    return None

def get_or_create_store():
    """Finds or creates the persistent FileSearchStore."""
    try:
        # Check for existing store
        for store in client.file_search_stores.list():
            if store.display_name == STORE_DISPLAY_NAME:
                return store
        
        # Create new one if not found
        return client.file_search_stores.create(config={'display_name': STORE_DISPLAY_NAME})
    except Exception as e:
        print(f"Error managing store: {e}")
        return None

# Initialize the store reference
current_store = get_or_create_store()
print(current_store)

@app.route('/')
def index():
    return send_from_directory(app.static_folder, 'index.html')

@app.route('/api/files', methods=['GET'])
def list_files():
    """Lists files in the current FileSearchStore with metadata."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    try:
        files = []
        documents_pager = client.file_search_stores.documents.list(
                parent=current_store.name
            )

        for doc in documents_pager:
            files.append({
                "name": doc.name,
                "display_name": doc.display_name,
                "create_time": doc.create_time,
                "size_bytes": getattr(doc, 'size_bytes', 0),
                "mime_type": getattr(doc, 'mime_type', 'unknown'),
                "state": str(doc.state) if hasattr(doc, 'state') else 'unknown'
            })
        return jsonify(files)
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/api/files/<path:file_id>', methods=['GET'])
def get_file_details(file_id):
    """Retrieves full details for a specific file in the FileSearchStore."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    try:
        doc = client.file_search_stores.documents.get(name=file_id)
        
        # Convert CustomMetadata list to a flat dictionary for JSON serialization and easier UI display
        custom_meta_dict = {}
        if doc.custom_metadata:
            for item in doc.custom_metadata:
                # Try to find which value field is set
                val = getattr(item, 'string_value', None)
                if val is None:
                    val = getattr(item, 'numeric_value', None)
                if val is None:
                    val = getattr(item, 'string_list_value', None)
                custom_meta_dict[item.key] = val

        return jsonify({
            "name": doc.name,
            "display_name": doc.display_name,
            "create_time": doc.create_time,
            "update_time": getattr(doc, 'update_time', None),
            "size_bytes": getattr(doc, 'size_bytes', 0),
            "mime_type": getattr(doc, 'mime_type', 'unknown'),
            "state": str(doc.state) if hasattr(doc, 'state') else 'unknown',
            "custom_metadata": custom_meta_dict if custom_meta_dict else None
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/upload', methods=['POST'])
def upload_file():
    """Uploads a file to the FileSearchStore and saves a local copy."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    try:
        print("Starting UPLOADING... ", file.filename)
        
        # Save local copy
        local_path = os.path.join(UPLOAD_FOLDER, file.filename)
        file.save(local_path)
        
        # Extract URL for citation
        source_url = extract_url_from_file(local_path)
        
        # Upload and index (re-open the file for stream)
        with open(local_path, 'rb') as f:
            config = {
                'display_name': file.filename,
                'mime_type': file.content_type
            }
            if source_url:
                config['custom_metadata'] = [{'key': 'source_url', 'string_value': source_url}]
                
            uploaded_operation = client.file_search_stores.upload_to_file_search_store(
                file_search_store_name=current_store.name,
                file=f,
                config=config
            )
            
            while not uploaded_operation.done:
                time.sleep(1)
                print("UPLOADING...")
                uploaded_operation = client.operations.get(uploaded_operation)

        print("UPLOAD finished")
        
        return jsonify({
            "message": "File upload successful",
            "file_name": file.filename
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/upload-tar', methods=['POST'])
def upload_tar_file():
    """Uploads a .tar.gz file, extracts it, adds files to FileSearchStore, and saves local copies."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    if not (file.filename.endswith('.tar.gz') or file.filename.endswith('.tgz')):
        return jsonify({"error": "Invalid file type. Please upload a .tar.gz file"}), 400

    try:
        print(f"Starting TAR UPLOAD... {file.filename}")
        with tempfile.TemporaryDirectory() as temp_dir:
            tar_path = os.path.join(temp_dir, file.filename)
            file.save(tar_path)
            
            with tarfile.open(tar_path, "r:gz") as tar:
                tar.extractall(path=temp_dir)
            
            os.remove(tar_path)
            
            uploaded_files = []
            for root, dirs, files in os.walk(temp_dir):
                for filename in files:
                    file_path = os.path.join(root, filename)
                    
                    if filename.startswith('.'):
                        continue
                        
                    mime_type, _ = mimetypes.guess_type(file_path)
                    if mime_type is None:
                        mime_type = 'text/plain'

                    # Save local copy
                    local_path = os.path.join(UPLOAD_FOLDER, filename)
                    shutil.copy2(file_path, local_path)

                    # Extract URL for citation
                    source_url = extract_url_from_file(local_path)

                    print(f"Uploading {filename} (type: {mime_type})...")
                    
                    with open(local_path, 'rb') as f:
                        config = {
                            'display_name': filename,
                            'mime_type': mime_type
                        }
                        if source_url:
                            config['custom_metadata'] = [{'key': 'source_url', 'string_value': source_url}]

                        uploaded_operation = client.file_search_stores.upload_to_file_search_store(
                            file_search_store_name=current_store.name,
                            file=f,
                            config=config
                        )
                        
                        while not uploaded_operation.done:
                            time.sleep(1)
                            print(f"UPLOADING {filename}...")
                            uploaded_operation = client.operations.get(uploaded_operation)
                    
                    uploaded_files.append(filename)
                    print(f"Finished uploading {filename}")

            return jsonify({
                "message": f"Successfully uploaded {len(uploaded_files)} files from archive",
                "files": uploaded_files
            })
            
    except Exception as e:
        print(f"Error during tar upload: {e}")
        print(traceback.format_exc())
        return jsonify({"error": str(e)}), 500

@app.route('/api/files/<path:file_id>', methods=['DELETE'])
def delete_file(file_id):
    """Deletes a file from the FileSearchStore and its local copy."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    try:
        # Get details first to find the display name
        doc = client.file_search_stores.documents.get(name=file_id)
        display_name = doc.display_name
        
        # Delete from store
        client.file_search_stores.documents.delete(name=file_id, config={'force': True})
        
        # Delete local copy
        local_path = os.path.join(UPLOAD_FOLDER, display_name)
        if os.path.exists(local_path):
            os.remove(local_path)
            
        return jsonify({"message": "File deleted successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/store/clear', methods=['POST'])
def clear_store():
    """Deletes the entire FileSearchStore and all local copies."""
    global current_store
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    try:
        # Delete the store from Google with force=True to handle non-empty stores
        print(f"Deleting store (force): {current_store.name}")
        client.file_search_stores.delete(name=current_store.name, config={'force': True})
        
        # Clear the local uploads folder
        if os.path.exists(UPLOAD_FOLDER):
            shutil.rmtree(UPLOAD_FOLDER)
            os.makedirs(UPLOAD_FOLDER)
            
        # Re-initialize/Re-create the store
        current_store = get_or_create_store()
        
        return jsonify({"message": "Knowledge base cleared successfully"})
    except Exception as e:
        print(f"Error clearing store: {e}")
        print(traceback.format_exc())
        return jsonify({"error": str(e)}), 500

@app.route('/api/files/content/<filename>')
def get_file_content(filename):
    """Serves the content of a locally stored file."""
    try:
        return send_from_directory(UPLOAD_FOLDER, filename)
    except Exception as e:
        return jsonify({"error": str(e)}), 404

@app.route('/api/files/save', methods=['POST'])
def save_file():
    """Saves a new or edited file locally and uploads it to the FileSearchStore."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    data = request.json
    filename = data.get('filename')
    content = data.get('content')
    
    if not filename or content is None:
        return jsonify({"error": "Missing filename or content"}), 400

    # Ensure filename doesn't have path traversal and has a valid extension
    filename = os.path.basename(filename)
    if not filename.endswith('.txt'):
        filename += '.txt'

    try:
        local_path = os.path.join(UPLOAD_FOLDER, filename)
        
        # Save local copy
        with open(local_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        # Extract URL for citation
        source_url = extract_url_from_file(local_path)
        
        # Upload to Gemini (if it already exists in the store, we should ideally delete the old one first, 
        # but for simplicity we'll just upload and the store will handle it or we can let the user delete it)
        # To be clean, let's check if it exists and delete it if so
        documents_pager = client.file_search_stores.documents.list(parent=current_store.name)
        for doc in documents_pager:
            if doc.display_name == filename:
                client.file_search_stores.documents.delete(name=doc.name, config={'force': True})
                break

        with open(local_path, 'rb') as f:
            config = {
                'display_name': filename,
                'mime_type': 'text/plain'
            }
            if source_url:
                config['custom_metadata'] = [{'key': 'source_url', 'string_value': source_url}]

            uploaded_operation = client.file_search_stores.upload_to_file_search_store(
                file_search_store_name=current_store.name,
                file=f,
                config=config
            )
            
            while not uploaded_operation.done:
                time.sleep(1)
                uploaded_operation = client.operations.get(uploaded_operation)

        return jsonify({
            "message": "File saved and uploaded successfully",
            "filename": filename
        })
    except Exception as e:
        print(f"Error saving file: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/system-instruction', methods=['GET'])
def get_system_instruction():
    """Returns the base system instruction for editing."""
    return jsonify({"system_instruction": SYSTEM_INSTRUCTION})

@app.route('/api/system-instructions', methods=['GET'])
def get_all_system_instructions():
    """Returns all system instructions (default + custom)."""
    custom_instructions = load_custom_instructions()
    
    # Build response with default first, then custom ones
    result = [
        {
            "id": "default",
            "name": "Default",
            "instruction": SYSTEM_INSTRUCTION,
            "is_default": True
        }
    ]
    
    for custom in custom_instructions:
        result.append({
            "id": custom.get("id"),
            "name": custom.get("name"),
            "instruction": custom.get("instruction"),
            "is_default": False,
            "created_at": custom.get("created_at")
        })
    
    return jsonify({"instructions": result})

@app.route('/api/system-instructions', methods=['POST'])
def create_system_instruction():
    """Creates a new custom system instruction."""
    data = request.json
    name = data.get('name', '').strip()
    instruction = data.get('instruction', '').strip()
    
    if not name:
        return jsonify({"error": "Name is required"}), 400
    if not instruction:
        return jsonify({"error": "Instruction is required"}), 400
    
    custom_instructions = load_custom_instructions()
    
    # Generate a unique ID
    new_id = f"custom_{int(datetime.now().timestamp() * 1000)}"
    
    new_instruction = {
        "id": new_id,
        "name": name,
        "instruction": instruction,
        "created_at": datetime.now().isoformat()
    }
    
    custom_instructions.append(new_instruction)
    
    if save_custom_instructions(custom_instructions):
        return jsonify(new_instruction), 201
    else:
        return jsonify({"error": "Failed to save instruction"}), 500

@app.route('/api/system-instructions/<instruction_id>', methods=['DELETE'])
def delete_system_instruction(instruction_id):
    """Deletes a custom system instruction."""
    if instruction_id == "default":
        return jsonify({"error": "Cannot delete default instruction"}), 400
    
    custom_instructions = load_custom_instructions()
    original_count = len(custom_instructions)
    custom_instructions = [inst for inst in custom_instructions if inst.get("id") != instruction_id]
    
    if len(custom_instructions) == original_count:
        return jsonify({"error": "Instruction not found"}), 404
    
    if save_custom_instructions(custom_instructions):
        return jsonify({"message": "Instruction deleted successfully"}), 200
    else:
        return jsonify({"error": "Failed to delete instruction"}), 500

@app.route('/api/system-instructions/<instruction_id>', methods=['GET'])
def get_system_instruction_by_id(instruction_id):
    """Gets a specific system instruction by ID."""
    if instruction_id == "default":
        return jsonify({
            "id": "default",
            "name": "Default",
            "instruction": SYSTEM_INSTRUCTION,
            "is_default": True
        })
    
    custom_instructions = load_custom_instructions()
    for inst in custom_instructions:
        if inst.get("id") == instruction_id:
            return jsonify({
                "id": inst.get("id"),
                "name": inst.get("name"),
                "instruction": inst.get("instruction"),
                "is_default": False,
                "created_at": inst.get("created_at")
            })
    
    return jsonify({"error": "Instruction not found"}), 404

@app.route('/api/chat', methods=['POST'])
def chat():
    """Asks a question grounded in the FileSearchStore."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    data = request.json
    message = data.get('message')
    custom_instruction = data.get('system_instruction', '').strip()
    
    if not message:
        return jsonify({"error": "No message provided"}), 400

    # Use the custom instruction if provided, otherwise fall back to base
    instruction = custom_instruction if custom_instruction else SYSTEM_INSTRUCTION
    try:
       
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=message,
            config=types.GenerateContentConfig(
                system_instruction=instruction,
                tools=[
                    types.Tool(
                        file_search=types.FileSearch(
                            file_search_store_names=[current_store.name]
                        )
                    )
                ]
            )
        )
        grounding_supports = []
        if response.candidates and response.candidates[0].grounding_metadata:
            gm = response.candidates[0].grounding_metadata
            doc_list = list(client.file_search_stores.documents.list(parent=current_store.name))
            doc_url_by_title = {}
            for doc in doc_list:
                url = None
                if doc.custom_metadata:
                    for item in doc.custom_metadata:
                        if item.key == 'source_url':
                            url = getattr(item, 'string_value', None)
                            break
                if url:
                    doc_url_by_title[doc.display_name] = url

            if hasattr(gm, 'grounding_supports') and gm.grounding_supports:
                for support in gm.grounding_supports:
                    segment = getattr(support, 'segment', None)
                    if not segment:
                        continue
                    citation_urls = []
                    seen = set()
                    if support.grounding_chunk_indices and hasattr(gm, 'grounding_chunks'):
                        for chunk_idx in support.grounding_chunk_indices:
                            if chunk_idx >= len(gm.grounding_chunks):
                                continue
                            chunk = gm.grounding_chunks[chunk_idx]
                            title = None
                            url = None
                            if hasattr(chunk, 'web') and chunk.web:
                                title = getattr(chunk.web, 'title', None)
                                url = getattr(chunk.web, 'uri', None)
                            elif hasattr(chunk, 'retrieved_context') and chunk.retrieved_context:
                                rc = chunk.retrieved_context
                                title = getattr(rc, 'title', None)
                                url = doc_url_by_title.get(title) or getattr(rc, 'uri', None)
                            key = f"{title}|{url}"
                            if url and key not in seen:
                                seen.add(key)
                                citation_urls.append({
                                    "title": title,
                                    "url": url,
                                })
                    grounding_supports.append({
                        "segment": {
                            "start_index": getattr(segment, "start_index", 0),
                            "end_index": getattr(segment, "end_index", len(response.text)),
                        },
                        "citation_urls": citation_urls,
                    })

        answer_text = response.text or ""
        rendered = render_markdown_with_citations(answer_text, grounding_supports)
        return jsonify({
            "answer": rendered["markdown"],
            "answer_raw": answer_text,
            "html": rendered["html"],
            "blocks": rendered["blocks"],
            "supports": rendered["supports"],
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True, port=5000)

