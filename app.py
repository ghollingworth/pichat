import os
import time
import tarfile
import shutil
import mimetypes
import re
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from google import genai
from google.genai import types
from dotenv import load_dotenv
import tempfile
import traceback

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

@app.route('/api/chat', methods=['POST'])
def chat():
    """Asks a question grounded in the FileSearchStore."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    data = request.json
    message = data.get('message')
    use_bbcode = data.get('bbcode', False)
    custom_instruction = data.get('system_instruction', '').strip()
    
    if not message:
        return jsonify({"error": "No message provided"}), 400

    # Use the custom instruction if provided, otherwise fall back to base
    instruction = custom_instruction if custom_instruction else SYSTEM_INSTRUCTION
    if use_bbcode:
        instruction += (
            "\n\nCRITICAL FORMATTING RULES FOR phpBB:\n"
            "1. NEVER use Markdown (no backticks `code`, no stars **bold**, etc.).\n"
            "2. phpBB [code] tags are BLOCK-LEVEL ONLY. Never use them inside a sentence.\n"
            "3. For inline code (filenames, short commands), use [b]bold[/b] or [i]italics[/i] instead of [code].\n"
            "4. Use [code][/code] ONLY for multi-line blocks of code or terminal output.\n"
            "5. Use [b] for bold, [i] for italics, and [url=...] for links.\n"
            "6. Wrap your ENTIRE response in a single [quote] tag."
        )

    try:
        response = client.models.generate_content(
            model='gemini-3-flash-preview',
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

        # Process citations/grounding metadata and insert inline links
        citations = []
        annotated_answer = response.text
        citation_map = {}  # Map chunk index to citation data
        
        try:
            if response.candidates and response.candidates[0].grounding_metadata:
                gm = response.candidates[0].grounding_metadata
                
                # First, build a map of chunk indices to citation data
                if hasattr(gm, 'grounding_chunks') and gm.grounding_chunks:
                    seen_urls = {}
                    citation_id = 1
                    
                    for chunk_idx, chunk in enumerate(gm.grounding_chunks):
                        title = None
                        url = None
                        
                        if hasattr(chunk, 'web') and chunk.web:
                            title = chunk.web.title
                            url = chunk.web.uri
                        elif hasattr(chunk, 'retrieved_context') and chunk.retrieved_context:
                            rc = chunk.retrieved_context
                            title = getattr(rc, 'title', None)
                            if title:
                                # Lookup the document to get the display name and custom URL
                                try:
                                    doc_list = client.file_search_stores.documents.list(parent=current_store.name)
                                    for doc in doc_list:
                                        if doc.display_name == title:
                                            if doc.custom_metadata:
                                                for item in doc.custom_metadata:
                                                    if item.key == 'source_url':
                                                        url = getattr(item, 'string_value', None)
                                                        break
                                except Exception as e:
                                    print(f"Warning: Could not fetch details for citation {title}: {e}")
                        
                        if title:
                            # Use URL as key to avoid duplicates, or title if no URL
                            key = url if url else title
                            if key not in seen_urls:
                                citation_map[chunk_idx] = {
                                    "title": title,
                                    "url": url,
                                    "id": citation_id
                                }
                                seen_urls[key] = citation_id
                                citations.append({"title": title, "url": url, "id": citation_id})
                                citation_id += 1
                            else:
                                # Map this chunk to existing citation
                                citation_map[chunk_idx] = {
                                    "title": title,
                                    "url": url,
                                    "id": seen_urls[key]
                                }
                
                # Now use grounding_supports to insert inline citations
                if hasattr(gm, 'grounding_supports') and gm.grounding_supports and citation_map:
                    # Sort supports by end_index (descending) so we insert from end to start
                    # This prevents index shifting issues
                    supports = sorted(gm.grounding_supports, key=lambda s: s.segment.end_index if s.segment else 0, reverse=True)
                    
                    for support in supports:
                        if not support.segment:
                            continue
                            
                        segment = support.segment
                        end_idx = segment.end_index
                        
                        # Get the citation IDs for the chunks that support this segment
                        citation_ids = set()
                        if support.grounding_chunk_indices:
                            for chunk_idx in support.grounding_chunk_indices:
                                if chunk_idx in citation_map:
                                    citation_ids.add(citation_map[chunk_idx]["id"])
                        
                        if citation_ids:
                            # Create citation links
                            if use_bbcode:
                                # BBCode format: [url=...][1][/url]
                                links = []
                                for cid in sorted(citation_ids):
                                    citation = next((c for c in citations if c["id"] == cid), None)
                                    if citation and citation["url"]:
                                        links.append(f'[url={citation["url"]}][{cid}][/url]')
                                    elif citation:
                                        links.append(f'[{cid}]')
                                link_text = ' ' + ' '.join(links) if links else ''
                            else:
                                # HTML format: <a href="...">[1]</a>
                                links = []
                                for cid in sorted(citation_ids):
                                    citation = next((c for c in citations if c["id"] == cid), None)
                                    if citation and citation["url"]:
                                        links.append(f'<a href="{citation["url"]}" target="_blank" style="color: var(--primary); text-decoration: none; font-weight: bold;" title="{citation["title"]}">[{cid}]</a>')
                                    elif citation:
                                        links.append(f'<span style="color: var(--primary); font-weight: bold;" title="{citation["title"]}">[{cid}]</span>')
                                link_text = ' ' + ' '.join(links) if links else ''
                            
                            # Insert the citation link at the end of the segment
                            if end_idx <= len(annotated_answer):
                                annotated_answer = annotated_answer[:end_idx] + link_text + annotated_answer[end_idx:]

        except Exception as e:
            print(f"Error processing grounding metadata: {e}")
            traceback.print_exc()

        return jsonify({
            "answer": annotated_answer,
            "citations": citations
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True, port=5000)

