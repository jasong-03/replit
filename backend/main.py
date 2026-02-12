"""
HabitCards API Backend — Replit Integration
Provides AI parsing (via Replit AI) and cloud persistence (via Replit DB)
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os
import uuid
from datetime import datetime

app = Flask(__name__)
CORS(app)

# API key for iOS app auth
API_KEY = os.environ.get("HABITCARDS_API_KEY", "habitcards-dev-key")

# --- Storage (Replit DB or in-memory fallback) ---
try:
    from replit import db as replit_db
    USE_REPLIT_DB = True
except ImportError:
    USE_REPLIT_DB = False
    replit_db = {}

def db_get(key, default="[]"):
    if USE_REPLIT_DB:
        val = replit_db.get(key)
        return val if val else default
    return replit_db.get(key, default)

def db_set(key, value):
    if USE_REPLIT_DB:
        replit_db[key] = value
    else:
        replit_db[key] = value

def db_items(prefix):
    items = json.loads(db_get(prefix, "[]"))
    return items

def db_add(prefix, item):
    items = db_items(prefix)
    items.append(item)
    db_set(prefix, json.dumps(items))
    return item

def db_delete(prefix, item_id):
    items = db_items(prefix)
    items = [i for i in items if i.get("id") != item_id]
    db_set(prefix, json.dumps(items))

# --- Auth middleware ---
def check_auth():
    key = request.headers.get("X-API-KEY", "")
    if key != API_KEY:
        return jsonify({"error": "Unauthorized"}), 401
    return None

# --- AI Parsing (Replit AI Integration) ---
def get_ai_client():
    """Try Replit AI (OpenAI-compatible), fall back to Anthropic, then Google."""
    # Try OpenAI SDK (Replit auto-provisions this)
    try:
        from openai import OpenAI
        client = OpenAI()
        return "openai", client
    except Exception:
        pass
    # Try Anthropic
    try:
        import anthropic
        client = anthropic.Anthropic()
        return "anthropic", client
    except Exception:
        pass
    return None, None

def build_prompt(mode, text):
    base = "You are a voice command parser for a personal assistant app. Parse the user's voice input into structured JSON. Be creative and helpful. Fill in reasonable defaults for anything not mentioned."
    schemas = {
        "alarm": 'Return JSON: {"label":"alarm name","time":"HH:mm","icon":"SF Symbol","routine":[{"title":"step","duration":"e.g. 5 min","icon":"SF Symbol"}]}',
        "meeting": 'Return JSON: {"title":"name","date":"day","time":"h:mm a","icon":"SF Symbol","checklist":[{"title":"step","duration":"time","icon":"SF Symbol"}],"notes":"context"}',
        "mood": 'Return JSON: {"mood":"one word","level":0.0to1.0,"trigger":"cause","suggestion":"action"}',
        "inbox": 'Return JSON: {"source":"Email/Slack/etc","sourceIcon":"SF Symbol","priority":"High/Medium/Low","actionItems":[{"title":"task","duration":"time","icon":"SF Symbol"}]}',
        "schedule": 'Return JSON: {"blocks":[{"title":"activity","startTime":"h:mm a","endTime":"h:mm a","duration":"e.g. 1h","icon":"SF Symbol","colorName":"blue/green/purple/orange/teal/red"}]}'
    }
    schema = schemas.get(mode, schemas["alarm"])
    return f"{base}\n\n{schema}\n\nVoice input: \"{text}\""

def parse_with_ai(text, mode):
    provider, client = get_ai_client()
    prompt = build_prompt(mode, text)

    if provider == "openai":
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0.1
        )
        return json.loads(response.choices[0].message.content)

    elif provider == "anthropic":
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt + "\n\nReturn ONLY valid JSON, no other text."}]
        )
        text_content = response.content[0].text
        return json.loads(text_content)

    else:
        raise Exception("No AI provider available")

# --- Routes ---

@app.route("/", methods=["GET"])
def index():
    return jsonify({
        "name": "HabitCards API",
        "version": "1.0",
        "endpoints": ["/api/parse", "/api/alarms", "/api/meetings", "/api/moods", "/api/inbox", "/api/schedule"],
        "replit_db": USE_REPLIT_DB
    })

# AI Parse endpoint
@app.route("/api/parse", methods=["POST"])
def parse_voice():
    auth_error = check_auth()
    if auth_error:
        return auth_error

    data = request.json or {}
    text = data.get("text", "")
    mode = data.get("mode", "alarm")

    if not text:
        return jsonify({"error": "No text provided"}), 400

    try:
        result = parse_with_ai(text, mode)
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- CRUD for each model type ---

def make_crud(prefix, display_name):
    """Generate CRUD routes for a model type."""

    def list_items():
        auth_error = check_auth()
        if auth_error:
            return auth_error
        return jsonify(db_items(prefix))

    def create_item():
        auth_error = check_auth()
        if auth_error:
            return auth_error
        data = request.json or {}
        if "id" not in data:
            data["id"] = str(uuid.uuid4())
        data["createdAt"] = datetime.now().isoformat()
        item = db_add(prefix, data)
        return jsonify(item), 201

    def get_item(item_id):
        auth_error = check_auth()
        if auth_error:
            return auth_error
        items = db_items(prefix)
        item = next((i for i in items if i.get("id") == item_id), None)
        if not item:
            return jsonify({"error": "Not found"}), 404
        return jsonify(item)

    def delete_item(item_id):
        auth_error = check_auth()
        if auth_error:
            return auth_error
        db_delete(prefix, item_id)
        return jsonify({"deleted": True})

    # Register routes
    app.add_url_rule(f"/api/{prefix}", f"list_{prefix}", list_items, methods=["GET"])
    app.add_url_rule(f"/api/{prefix}", f"create_{prefix}", create_item, methods=["POST"])
    app.add_url_rule(f"/api/{prefix}/<item_id>", f"get_{prefix}", get_item, methods=["GET"])
    app.add_url_rule(f"/api/{prefix}/<item_id>", f"delete_{prefix}", delete_item, methods=["DELETE"])

# Register CRUD for all model types
make_crud("alarms", "Alarm")
make_crud("meetings", "Meeting")
make_crud("moods", "Mood")
make_crud("inbox", "Inbox")
make_crud("schedule", "Schedule")
make_crud("profiles", "Profile")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
