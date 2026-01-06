import os
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from google import genai
from google.genai import types
from dotenv import load_dotenv
import tempfile


# Initialize Gemini Client
API_KEY = os.getenv("GEMINI_API_KEY")
if not API_KEY:
    raise ValueError("GEMINI_API_KEY not found in environment variables")

client = genai.Client(api_key=API_KEY)
STORE_DISPLAY_NAME = "Raspberry Pi Knowledge Base"

def get_store():
  for store in client.file_search_stores.list():
    if(store.display_name == STORE_DISPLAY_NAME):
        return store

current_store = get_store()
documents_pager = client.file_search_stores.documents.list(
        parent=current_store.name
    )

for doc in documents_pager:
   print(f"- Display Name: {doc.display_name}")
   print(f"  Resource Name: {doc.name}")
   print(f"  Create Time: {doc.create_time}")
   print("-" * 20)


