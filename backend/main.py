"""
ClearMaxx AI — skin/face analysis backend.

Flask service for Google App Engine. Receives a face photo from the ClearMaxx
iOS app, sends it to Gemini vision, and returns a structured skin analysis that
maps directly onto the app's Results dashboard (per-metric scores + an overall
ClearScore + suggestions).

Security model:
  * The Gemini API key is loaded ONLY from Google Secret Manager
    (secret: `clearmaxx-gemini-key`). It is never in this file, in app.yaml,
    or in the iOS app. A local `.env` (git-ignored) may supply it for dev only.
  * Requests must carry a shared `X-App-Token` header that matches the secret
    `clearmaxx-app-token`, so the public URL can't be used to burn the quota.
"""

import os
import io
import json
import base64
import hmac

from flask import Flask, request, jsonify
from flask_cors import CORS
import google.generativeai as genai
from PIL import Image

try:
    from dotenv import load_dotenv
    load_dotenv()  # local dev only; no-op on App Engine
except Exception:
    pass

app = Flask(__name__)
CORS(app)

PRIMARY_MODEL = "gemini-2.5-flash"
FALLBACK_MODEL = "gemini-2.5-flash-lite"


# --------------------------------------------------------------------------- #
# Secrets
# --------------------------------------------------------------------------- #
def _access_secret(secret_id: str) -> str | None:
    """Read a secret value from Secret Manager (preferred) or env (dev fallback)."""
    # Local/dev fallback first so you don't need cloud creds to run locally.
    env_map = {"clearmaxx-gemini-key": "GEMINI_API_KEY",
               "clearmaxx-app-token": "APP_TOKEN"}
    env_val = os.getenv(env_map.get(secret_id, ""))
    if env_val:
        return env_val.strip()

    try:
        from google.cloud import secretmanager
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        if not project_id:
            return None
        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
        resp = client.access_secret_version(request={"name": name})
        # .strip() guards against trailing newlines introduced when a secret
        # value is piped in from a file.
        return resp.payload.data.decode("UTF-8").strip()
    except Exception as e:  # pragma: no cover
        print(f"[WARN] Could not read secret {secret_id} from Secret Manager: {e}")
        return None


API_KEY = _access_secret("clearmaxx-gemini-key")
APP_TOKEN = _access_secret("clearmaxx-app-token")

if API_KEY:
    genai.configure(api_key=API_KEY)
    print(f"[OK] Gemini configured (key {API_KEY[:6]}…).")
else:
    print("[WARN] No Gemini key found — /api/skin/analyze will 500.")


def _model():
    """Return the best available configured model, preferring the cheap flash tiers."""
    try:
        available = {
            m.name.replace("models/", "")
            for m in genai.list_models()
            if "generateContent" in m.supported_generation_methods
        }
        for name in (PRIMARY_MODEL, FALLBACK_MODEL, "gemini-1.5-flash"):
            if name in available:
                return genai.GenerativeModel(name)
    except Exception as e:
        print(f"[WARN] list_models failed ({e}); using {PRIMARY_MODEL}.")
    return genai.GenerativeModel(PRIMARY_MODEL)


# --------------------------------------------------------------------------- #
# Prompt + schema
# --------------------------------------------------------------------------- #
METRICS = ["Acne", "Pores", "Hydration", "Dark Spots",
           "Redness", "Wrinkles", "Oiliness", "Dark Circles"]

ANALYSIS_PROMPT = f"""
You are a dermatology-aware skin analysis assistant for a consumer skincare app.
Analyze the FACE in the image and return ONLY a JSON object (no markdown) with EXACTLY this shape:

{{
  "clearScore": <int 0-100, overall skin health, higher is better>,
  "confidence": <int 0-100, how confident you are given image quality>,
  "skinType": <one of "Oily","Dry","Combination","Normal","Sensitive">,
  "summary": <one upbeat sentence, max 140 chars>,
  "metrics": [
    {{
      "name": <one of {METRICS}>,
      "value": <int 0-100; for issues like Acne/Pores/Dark Spots/Redness/Wrinkles/Oiliness/Dark Circles this is SEVERITY (higher = worse); for Hydration higher = better>,
      "severity": <one of "Good","Mild","Moderate","Severe">,
      "summary": <short plain-language explanation, max 120 chars>,
      "ingredients": [<2-4 recommended skincare ingredient names>],
      "tips": [<2-3 short actionable tips>]
    }}
    // EXACTLY one object per metric in {METRICS}, in that order
  ],
  "routineSuggestions": [<3-5 short routine steps tailored to this face>]
}}

Rules:
- If the image is not a clear human face, set confidence below 30 and give neutral mid values.
- Be encouraging and non-diagnostic; never claim to detect medical conditions.
- Output raw JSON only.
""".strip()


def _safe_int(v, default=0):
    try:
        return max(0, min(100, int(round(float(v)))))
    except Exception:
        return default


def _normalize(parsed: dict) -> dict:
    """Coerce the model output into the exact shape the app expects."""
    by_name = {m.get("name"): m for m in parsed.get("metrics", []) if isinstance(m, dict)}
    metrics = []
    for name in METRICS:
        m = by_name.get(name, {})
        metrics.append({
            "name": name,
            "value": _safe_int(m.get("value"), 0),
            "severity": m.get("severity") if m.get("severity") in {"Good", "Mild", "Moderate", "Severe"} else "Mild",
            "summary": str(m.get("summary", ""))[:160],
            "ingredients": [str(x) for x in (m.get("ingredients") or [])][:4],
            "tips": [str(x) for x in (m.get("tips") or [])][:3],
        })
    return {
        "clearScore": _safe_int(parsed.get("clearScore"), 0),
        "confidence": _safe_int(parsed.get("confidence"), 0),
        "skinType": parsed.get("skinType", "Normal"),
        "summary": str(parsed.get("summary", ""))[:200],
        "metrics": metrics,
        "routineSuggestions": [str(x) for x in (parsed.get("routineSuggestions") or [])][:5],
    }


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #
@app.route("/")
def home():
    return jsonify({"service": "ClearMaxx AI backend", "status": "running",
                    "gemini_configured": API_KEY is not None})


@app.route("/health")
def health():
    return jsonify({"status": "ok", "gemini_configured": API_KEY is not None,
                    "auth_required": APP_TOKEN is not None})


def _authorized(req) -> bool:
    """Constant-time check of the X-App-Token header against the secret."""
    if not APP_TOKEN:
        return True  # no token configured (e.g. early local dev) → allow
    sent = req.headers.get("X-App-Token", "")
    return hmac.compare_digest(sent, APP_TOKEN)


@app.route("/api/skin/analyze", methods=["POST"])
def analyze_skin():
    if not API_KEY:
        return jsonify({"error": "Server not configured (no Gemini key)"}), 500
    if not _authorized(request):
        return jsonify({"error": "Unauthorized"}), 401

    # Accept JSON {image_base64: ...} (iOS) or multipart 'image'.
    try:
        if request.is_json:
            data = request.get_json(silent=True) or {}
            b64 = data.get("image_base64")
            if not b64:
                return jsonify({"error": "Missing image_base64"}), 400
            if "," in b64:  # strip data URL prefix if present
                b64 = b64.split(",", 1)[1]
            image = Image.open(io.BytesIO(base64.b64decode(b64)))
        elif "image" in request.files:
            image = Image.open(io.BytesIO(request.files["image"].read()))
        else:
            return jsonify({"error": "No image provided"}), 400
    except Exception as e:
        return jsonify({"error": f"Could not read image: {e}"}), 400

    try:
        model = _model()
        resp = model.generate_content(
            [ANALYSIS_PROMPT, image],
            generation_config={"response_mime_type": "application/json", "temperature": 0.4},
        )
        raw = (resp.text or "").strip()
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            # last-resort: pull the outermost JSON object
            s, e = raw.find("{"), raw.rfind("}")
            parsed = json.loads(raw[s:e + 1]) if s != -1 and e != -1 else {}
        return jsonify({"success": True, "result": _normalize(parsed)})
    except Exception as e:
        print(f"[ERROR] analyze failed: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(debug=True, host="0.0.0.0", port=port)
