"""
ClearMaxx AI — skin/face analysis backend.

Flask service for Google App Engine. Receives a face photo from the ClearMaxx
iOS app, sends it to Gemini (via Vertex AI), and returns a structured skin
analysis that maps directly onto the app's Results dashboard (per-metric scores
+ an overall ClearScore + suggestions).

Auth / security model:
  * Gemini runs on VERTEX AI — there is NO API key anywhere. Auth uses the App
    Engine service account's Application Default Credentials (ADC), which holds
    the `roles/aiplatform.user` role on the project. Locally, `gcloud auth
    application-default login` supplies ADC.
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
from google import genai
from google.genai import types
from google.genai.types import HttpOptions
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

# Vertex config. GOOGLE_CLOUD_PROJECT is injected automatically by App Engine;
# VERTEX_LOCATION is set in app.yaml (must be a region that serves Gemini).
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("VERTEX_PROJECT")
LOCATION = os.getenv("VERTEX_LOCATION", "us-central1")


# --------------------------------------------------------------------------- #
# Secrets (only the app token now — Vertex needs no key)
# --------------------------------------------------------------------------- #
def _access_secret(secret_id: str) -> str | None:
    """Read a secret value from Secret Manager (preferred) or env (dev fallback)."""
    # Local/dev fallback first so you don't need cloud creds to run locally.
    env_map = {"clearmaxx-app-token": "APP_TOKEN"}
    env_val = os.getenv(env_map.get(secret_id, ""))
    if env_val:
        return env_val.strip()

    try:
        from google.cloud import secretmanager
        if not PROJECT_ID:
            return None
        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/{PROJECT_ID}/secrets/{secret_id}/versions/latest"
        resp = client.access_secret_version(request={"name": name})
        # .strip() guards against trailing newlines introduced when a secret
        # value is piped in from a file.
        return resp.payload.data.decode("UTF-8").strip()
    except Exception as e:  # pragma: no cover
        print(f"[WARN] Could not read secret {secret_id} from Secret Manager: {e}")
        return None


APP_TOKEN = _access_secret("clearmaxx-app-token")

# One Vertex client for the process, authenticated via ADC (the App Engine SA).
_client = None
if PROJECT_ID:
    try:
        _client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION,
                               http_options=HttpOptions(api_version="v1"))
        print(f"[OK] Vertex AI client ready (project={PROJECT_ID}, location={LOCATION}).")
    except Exception as e:
        print(f"[WARN] Could not init Vertex client: {e}")
else:
    print("[WARN] No GOOGLE_CLOUD_PROJECT — /api/skin/analyze will 500.")


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
  "routineSteps": [
    {{
      "time": <"AM" or "PM">,
      "category": <e.g. "Cleanser","Treatment","Moisturizer","Sunscreen">,
      "title": <short product/step name, max 40 chars>,
      "detail": <one sentence on why/how, max 140 chars>,
      "tags": [<0-3 short tags, e.g. "Fragrance-free">]
    }}
    // 4-8 steps total, a mix of AM and PM, tailored to the metrics above
  ]
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


def _normalize_routine_step(s: dict) -> dict:
    """Coerce one routine-step object into the exact shape the app expects."""
    time = s.get("time") if s.get("time") in {"AM", "PM"} else "AM"
    return {
        "time": time,
        "category": str(s.get("category", ""))[:40],
        "title": str(s.get("title", ""))[:40],
        "detail": str(s.get("detail", ""))[:160],
        "tags": [str(x) for x in (s.get("tags") or [])][:3],
    }


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
        "routineSteps": [
            _normalize_routine_step(s) for s in (parsed.get("routineSteps") or [])
            if isinstance(s, dict)
        ][:8],
    }


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #
@app.route("/")
def home():
    return jsonify({"service": "ClearMaxx AI backend", "status": "running",
                    "vertex_configured": _client is not None,
                    "project": PROJECT_ID, "location": LOCATION})


@app.route("/health")
def health():
    return jsonify({"status": "ok", "vertex_configured": _client is not None,
                    "auth_required": APP_TOKEN is not None})


def _authorized(req) -> bool:
    """Constant-time check of the X-App-Token header against the secret."""
    if not APP_TOKEN:
        return True  # no token configured (e.g. early local dev) → allow
    sent = req.headers.get("X-App-Token", "")
    return hmac.compare_digest(sent, APP_TOKEN)


def _generate(img_bytes: bytes) -> str:
    """Call Vertex Gemini with the prompt + image; retry on the lite tier."""
    image_part = types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg")
    config = types.GenerateContentConfig(response_mime_type="application/json",
                                         temperature=0.4)
    last_err = None
    for model in (PRIMARY_MODEL, FALLBACK_MODEL):
        try:
            resp = _client.models.generate_content(
                model=model, contents=[ANALYSIS_PROMPT, image_part], config=config)
            return (resp.text or "").strip()
        except Exception as e:  # e.g. model unavailable in region → try lite
            last_err = e
            print(f"[WARN] {model} failed ({e}); trying next tier.")
    raise last_err or RuntimeError("No Vertex model succeeded")


@app.route("/api/skin/analyze", methods=["POST"])
def analyze_skin():
    if _client is None:
        return jsonify({"error": "Server not configured (Vertex client unavailable)"}), 500
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
        # Normalize to JPEG bytes so Vertex always gets a valid, known mime type.
        buf = io.BytesIO()
        image.convert("RGB").save(buf, format="JPEG", quality=90)
        img_bytes = buf.getvalue()
    except Exception as e:
        return jsonify({"error": f"Could not read image: {e}"}), 400

    try:
        raw = _generate(img_bytes)
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
