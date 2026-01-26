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
from citation_renderer import CitationRenderer

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
FIXTURES_FOLDER = 'fixtures'
CHAT_HISTORY_FOLDER = 'chat_history'

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

# Ensure fixtures folder exists
if not os.path.exists(FIXTURES_FOLDER):
    os.makedirs(FIXTURES_FOLDER)

# Ensure chat history folder exists
if not os.path.exists(CHAT_HISTORY_FOLDER):
    os.makedirs(CHAT_HISTORY_FOLDER)

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

def _serialize_grounding_metadata(gm):
    """Serialize grounding metadata to a JSON-serializable format."""
    if not gm:
        return None
    result = {}
    if hasattr(gm, 'grounding_chunks') and gm.grounding_chunks:
        chunks = []
        for chunk in gm.grounding_chunks:
            chunk_data = {}
            if hasattr(chunk, 'web') and chunk.web:
                chunk_data['web'] = {
                    'title': getattr(chunk.web, 'title', None),
                    'uri': getattr(chunk.web, 'uri', None),
                }
            if hasattr(chunk, 'retrieved_context') and chunk.retrieved_context:
                rc = chunk.retrieved_context
                chunk_data['retrieved_context'] = {
                    'title': getattr(rc, 'title', None),
                    'uri': getattr(rc, 'uri', None),
                }
            chunks.append(chunk_data)
        result['grounding_chunks'] = chunks
    if hasattr(gm, 'grounding_supports') and gm.grounding_supports:
        supports = []
        for support in gm.grounding_supports:
            support_data = {}
            if hasattr(support, 'segment') and support.segment:
                segment = support.segment
                support_data['segment'] = {
                    'start_index': getattr(segment, 'start_index', None),
                    'end_index': getattr(segment, 'end_index', None),
                }
            if hasattr(support, 'grounding_chunk_indices'):
                support_data['grounding_chunk_indices'] = support.grounding_chunk_indices
            supports.append(support_data)
        result['grounding_supports'] = supports
    return result

def _deserialize_grounding_metadata(data):
    """Create a mock grounding metadata object from serialized data."""
    if not data:
        return None
    
    class MockWeb:
        def __init__(self, title, uri):
            self.title = title
            self.uri = uri
    
    class MockRetrievedContext:
        def __init__(self, title, uri):
            self.title = title
            self.uri = uri
    
    class MockChunk:
        def __init__(self, chunk_data):
            self.web = None
            self.retrieved_context = None
            if 'web' in chunk_data and chunk_data['web']:
                self.web = MockWeb(
                    chunk_data['web'].get('title'),
                    chunk_data['web'].get('uri')
                )
            if 'retrieved_context' in chunk_data and chunk_data['retrieved_context']:
                rc_data = chunk_data['retrieved_context']
                self.retrieved_context = MockRetrievedContext(
                    rc_data.get('title'),
                    rc_data.get('uri')
                )
    
    class MockSegment:
        def __init__(self, start_index, end_index):
            self.start_index = start_index
            self.end_index = end_index
    
    class MockSupport:
        def __init__(self, segment_data, chunk_indices):
            if segment_data:
                self.segment = MockSegment(
                    segment_data.get('start_index'),
                    segment_data.get('end_index')
                )
            else:
                self.segment = None
            self.grounding_chunk_indices = chunk_indices or []
    
    class MockGroundingMetadata:
        def __init__(self, data):
            chunks_data = data.get('grounding_chunks', [])
            self.grounding_chunks = [MockChunk(c) for c in chunks_data]
            supports_data = data.get('grounding_supports', [])
            self.grounding_supports = [
                MockSupport(s.get('segment'), s.get('grounding_chunk_indices'))
                for s in supports_data
            ]
    
    return MockGroundingMetadata(data)

def save_fixture(name, message, response_text, grounding_metadata):
    """Save a test fixture to disk."""
    try:
        fixture_data = {
            "name": name,
            "message": message,
            "response_text": response_text,
            "grounding_metadata": _serialize_grounding_metadata(grounding_metadata),
            "created_at": datetime.now().isoformat()
        }
        filename = f"{name}.json"
        filepath = os.path.join(FIXTURES_FOLDER, filename)
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(fixture_data, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving fixture: {e}")
        traceback.print_exc()
        return False

def load_fixture(name):
    """Load a test fixture from disk."""
    try:
        filename = f"{name}.json"
        filepath = os.path.join(FIXTURES_FOLDER, filename)
        if not os.path.exists(filepath):
            return None
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data
    except Exception as e:
        print(f"Error loading fixture: {e}")
        return None

def list_fixtures():
    """List all available fixtures."""
    try:
        fixtures = []
        for filename in os.listdir(FIXTURES_FOLDER):
            if filename.endswith('.json'):
                name = filename[:-5]  # Remove .json extension
                filepath = os.path.join(FIXTURES_FOLDER, filename)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    fixtures.append({
                        "name": name,
                        "created_at": data.get("created_at"),
                        "message": data.get("message", "")[:100] + "..." if len(data.get("message", "")) > 100 else data.get("message", "")
                    })
                except Exception:
                    pass
        return fixtures
    except Exception as e:
        print(f"Error listing fixtures: {e}")
        return []

# Create a singleton instance for backward compatibility
_citation_renderer = CitationRenderer()

# Backward compatibility functions
def _build_line_index(text):
    return CitationRenderer._build_line_index(text)

def _offset_to_line(line_ranges, offset):
    return CitationRenderer._offset_to_line(line_ranges, offset)

def extract_markdown_blocks(markdown_text):
    return _citation_renderer.extract_markdown_blocks(markdown_text)

def map_supports_to_lines(markdown_text, grounding_supports):
    return _citation_renderer.map_supports_to_lines(markdown_text, grounding_supports)

def insert_citations_into_text(text, supports_with_lines, chunk_to_citation, output_mode):
    return _citation_renderer.insert_citations_into_text(text, supports_with_lines, chunk_to_citation, output_mode)

def render_markdown_with_citations(markdown_text, grounding_supports, output_mode='html'):
    return _citation_renderer.render(markdown_text, grounding_supports, output_mode)

def _wrap_html_with_supports(html, supports_with_lines):
    return _citation_renderer._wrap_html_with_supports(html, supports_with_lines)

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
    return send_from_directory(app.static_folder, 'chat.html')

@app.route('/admin')
def admin():
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

@app.route('/api/fixtures', methods=['GET'])
def list_fixtures_endpoint():
    """List all available test fixtures."""
    fixtures = list_fixtures()
    return jsonify({"fixtures": fixtures})

@app.route('/api/fixtures/<fixture_name>', methods=['GET'])
def get_fixture(fixture_name):
    """Get a specific test fixture."""
    fixture = load_fixture(fixture_name)
    if not fixture:
        return jsonify({"error": "Fixture not found"}), 404
    return jsonify(fixture)

@app.route('/api/fixtures', methods=['POST'])
def save_fixture_endpoint():
    """Save a test fixture from the last chat response."""
    data = request.json
    name = data.get('name', '').strip()
    if not name:
        return jsonify({"error": "Fixture name is required"}), 400
    
    # This endpoint would typically be called after a chat request
    # For now, we'll require the full fixture data to be provided
    message = data.get('message')
    response_text = data.get('response_text')
    grounding_metadata_serialized = data.get('grounding_metadata')
    
    if not message or not response_text:
        return jsonify({"error": "message and response_text are required"}), 400
    
    # Deserialize and re-serialize to normalize
    gm = _deserialize_grounding_metadata(grounding_metadata_serialized) if grounding_metadata_serialized else None
    
    if save_fixture(name, message, response_text, gm):
        return jsonify({"message": f"Fixture '{name}' saved successfully"}), 201
    else:
        return jsonify({"error": "Failed to save fixture"}), 500

def save_chat_history(conversation_id, messages):
    """Save a chat conversation to disk."""
    try:
        conversation_data = {
            "id": conversation_id,
            "created_at": datetime.now().isoformat(),
            "messages": messages
        }
        filename = f"{conversation_id}.json"
        filepath = os.path.join(CHAT_HISTORY_FOLDER, filename)
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(conversation_data, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving chat history: {e}")
        traceback.print_exc()
        return False

def load_chat_history(conversation_id):
    """Load a chat conversation from disk."""
    try:
        filename = f"{conversation_id}.json"
        filepath = os.path.join(CHAT_HISTORY_FOLDER, filename)
        if not os.path.exists(filepath):
            return None
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading chat history: {e}")
        return None

def list_chat_histories():
    """List all chat conversations."""
    try:
        conversations = []
        for filename in os.listdir(CHAT_HISTORY_FOLDER):
            if filename.endswith('.json'):
                conversation_id = filename[:-5]  # Remove .json extension
                filepath = os.path.join(CHAT_HISTORY_FOLDER, filename)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    conversations.append({
                        "id": conversation_id,
                        "created_at": data.get("created_at"),
                        "message_count": len(data.get("messages", [])),
                        "preview": data.get("messages", [{}])[0].get("message", "")[:100] + "..." if data.get("messages") else ""
                    })
                except Exception:
                    pass
        # Sort by created_at descending (newest first)
        conversations.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return conversations
    except Exception as e:
        print(f"Error listing chat histories: {e}")
        return []

@app.route('/api/chat', methods=['POST'])
def chat():
    """Asks a question grounded in the FileSearchStore."""
    if not current_store:
        return jsonify({"error": "Store not initialized"}), 500
    
    data = request.json
    message = data.get('message')
    custom_instruction = data.get('system_instruction', '').strip()
    test_mode = data.get('test_mode', False)
    fixture_name = data.get('fixture_name')
    save_fixture_name = data.get('save_fixture')
    output_mode = data.get('output_mode', 'html')  # Default to 'html'
    
    # Validate output_mode
    valid_modes = ['html', 'markdown', 'raw', 'phpbb']
    if output_mode not in valid_modes:
        output_mode = 'html'
    
    if not message:
        return jsonify({"error": "No message provided"}), 400

    # Use the custom instruction if provided, otherwise fall back to base
    instruction = custom_instruction if custom_instruction else SYSTEM_INSTRUCTION
    try:
        # Test mode: load from fixture instead of calling API
        if test_mode and fixture_name:
            fixture = load_fixture(fixture_name)
            if not fixture:
                return jsonify({"error": f"Fixture '{fixture_name}' not found"}), 404
            
            # Create a mock response object
            class MockResponse:
                def __init__(self, text, grounding_metadata):
                    self.text = text
                    self.candidates = [MockCandidate(grounding_metadata)] if grounding_metadata else []
            
            class MockCandidate:
                def __init__(self, grounding_metadata):
                    self.grounding_metadata = _deserialize_grounding_metadata(grounding_metadata)
            
            response = MockResponse(
                fixture['response_text'],
                fixture.get('grounding_metadata')
            )
        else:
            # Normal mode: call the API
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
        
        print("RESPONSE", response.text)

        # Save fixture if requested (only in normal mode)
        if save_fixture_name and not test_mode:
            gm = None
            if response.candidates and response.candidates[0].grounding_metadata:
                gm = response.candidates[0].grounding_metadata
            save_fixture(save_fixture_name, message, response.text or "", gm)
        
        grounding_supports = []
        if response.candidates and response.candidates[0].grounding_metadata:
            gm = response.candidates[0].grounding_metadata
            # In test mode, skip doc lookup (URLs should be in fixture)
            # In normal mode, look up document URLs
            doc_url_by_title = {}
            if not test_mode:
                try:
                    doc_list = list(client.file_search_stores.documents.list(parent=current_store.name))
                    for doc in doc_list:
                        url = None
                        if doc.custom_metadata:
                            for item in doc.custom_metadata:
                                if item.key == 'source_url':
                                    url = getattr(item, 'string_value', None)
                                    break
                        if url:
                            doc_url_by_title[doc.display_name] = url
                except Exception as e:
                    print(f"Warning: Could not fetch document URLs: {e}")

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
                            # If no URL but we have a title, create a localhost:// link
                            if not url and title:
                                url = f"localhost://{title}"
                            key = f"{title}|{url}"
                            if url and key not in seen:
                                seen.add(key)
                                citation_urls.append({
                                    "title": title,
                                    "url": url,
                                    "chunk_idx": chunk_idx,  # Track which chunk this citation comes from
                                })
                    grounding_supports.append({
                        "segment": {
                            "start_index": getattr(segment, "start_index", 0),
                            "end_index": getattr(segment, "end_index", len(response.text)),
                        },
                        "citation_urls": citation_urls,
                        "grounding_chunk_indices": support.grounding_chunk_indices if hasattr(support, 'grounding_chunk_indices') else [],
                    })

        answer_text = response.text or ""
        # Always generate all formats for dynamic switching
        rendered_html = render_markdown_with_citations(answer_text, grounding_supports, 'html')
        rendered_markdown = render_markdown_with_citations(answer_text, grounding_supports, 'markdown')
        rendered_raw = render_markdown_with_citations(answer_text, grounding_supports, 'raw')
        rendered_phpbb = render_markdown_with_citations(answer_text, grounding_supports, 'phpbb')
        
        # Use the requested mode's rendered output as primary
        rendered = rendered_html if output_mode == 'html' else (
            rendered_markdown if output_mode == 'markdown' else (
                rendered_raw if output_mode == 'raw' else rendered_phpbb
            )
        )
        
        
        # Save to chat history if conversation_id is provided
        conversation_id = data.get('conversation_id')
        if conversation_id:
            # Load existing conversation or create new
            conversation = load_chat_history(conversation_id)
            if not conversation:
                conversation = {
                    "id": conversation_id,
                    "created_at": datetime.now().isoformat(),
                    "messages": []
                }
            
            # Add user message and bot response
            conversation["messages"].append({
                "role": "user",
                "message": message,
                "timestamp": datetime.now().isoformat()
            })
            bot_message = {
                "role": "bot",
                "answer": rendered_html["markdown"],
                "answer_raw": answer_text,
                "blocks": rendered_html["blocks"],
                "supports": rendered_html["supports"],
                "chunks": rendered_html["chunks"],  # Map of chunk_idx -> {title, url, citation_num}
                "output_mode": output_mode,  # Store the initially requested mode
                "timestamp": datetime.now().isoformat(),
                # Store all formats for dynamic switching
                "html": rendered_html.get("html", ""),
                "markdown_formatted": rendered_markdown.get("markdown_formatted", rendered_markdown["markdown"]),
                "raw": rendered_raw.get("raw", rendered_raw["markdown"]),
                "raw_citations": rendered_raw.get("raw_citations", ""),
                "phpbb": rendered_phpbb.get("phpbb", rendered_phpbb["markdown"])
            }
            
            conversation["messages"].append(bot_message)
            
            save_chat_history(conversation_id, conversation["messages"])
        
        response_data = {
            "answer": rendered_html["markdown"],
            "answer_raw": answer_text,
            "blocks": rendered_html["blocks"],
            "supports": rendered_html["supports"],
            "chunks": rendered_html["chunks"],  # Map of chunk_idx -> {title, url, citation_num}
            "output_mode": output_mode,  # The initially requested mode
            "conversation_id": conversation_id,  # Return the conversation_id
            # Include all formats for dynamic switching
            "html": rendered_html.get("html", ""),
            "markdown_formatted": rendered_markdown.get("markdown_formatted", rendered_markdown["markdown"]),
            "raw": rendered_raw.get("raw", rendered_raw["markdown"]),
            "raw_citations": rendered_raw.get("raw_citations", ""),
            "phpbb": rendered_phpbb.get("phpbb", rendered_phpbb["markdown"])
        }
        
        return jsonify(response_data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/chat/history', methods=['GET'])
def list_chat_history():
    """List all chat conversations."""
    conversations = list_chat_histories()
    return jsonify({"conversations": conversations})

@app.route('/api/chat/history/<conversation_id>', methods=['GET'])
def get_chat_history(conversation_id):
    """Get a specific chat conversation."""
    conversation = load_chat_history(conversation_id)
    if not conversation:
        return jsonify({"error": "Conversation not found"}), 404
    return jsonify(conversation)

@app.route('/api/chat/history/<conversation_id>', methods=['DELETE'])
def delete_chat_history(conversation_id):
    """Delete a chat conversation."""
    try:
        filename = f"{conversation_id}.json"
        filepath = os.path.join(CHAT_HISTORY_FOLDER, filename)
        if os.path.exists(filepath):
            os.remove(filepath)
            return jsonify({"message": "Conversation deleted successfully"})
        else:
            return jsonify({"error": "Conversation not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/history')
def history_page():
    """Serve the chat history page."""
    return send_from_directory(app.static_folder, 'history.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0',debug=True, port=5000)

