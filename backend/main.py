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

def _build_analysis_prompt(profile: dict | None = None) -> str:
    """Builds ANALYSIS_PROMPT, optionally injecting the user's onboarding-quiz
    answers so routineSteps/tone are personalized to their stated goal and
    concerns. Always subordinate to what's actually visible in the photo —
    self-reported skin type never overrides the visual read."""
    profile_section = ""
    if profile:
        lines = []
        if profile.get("skin_type"):
            lines.append(f'- Self-reported skin type: {profile["skin_type"]}')
        if profile.get("goal"):
            lines.append(f'- Primary goal: {profile["goal"]}')
        concerns = profile.get("concerns")
        if isinstance(concerns, list) and concerns:
            lines.append(f'- Specific concerns they flagged: {", ".join(str(c) for c in concerns[:6])}')
        if lines:
            profile_section = (
                "\nUSER-REPORTED PROFILE (from onboarding quiz — context, not ground truth;\n"
                "ALWAYS trust what you visually observe in the photo for skinType and metric\n"
                "values, but use this to prioritize which concerns routineSteps address and to\n"
                "tailor ingredient choices/tone toward their stated goal):\n"
                + "\n".join(lines) + "\n"
            )
    return f"""
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
      "detail": <one sentence, max 140 chars, naming the SPECIFIC metric/severity from
                 THIS scan that this step addresses — e.g. "Targets your Moderate acne
                 with gentle exfoliation" not a generic "cleanses skin">,
      "tags": [<0-3 short tags, e.g. "Fragrance-free">]
    }}
    // 4-8 steps total, a mix of AM and PM
  ]
}}
{profile_section}
Rules:
- If the image is not a clear human face, set confidence below 30 and give neutral mid values.
- Be encouraging and non-diagnostic; never claim to detect medical conditions.
- routineSteps MUST be derived from THIS face's actual metrics, not generic boilerplate:
  prioritize steps that address whichever metrics scored "Moderate" or "Severe" here (if
  none did, focus on maintenance for the mildest/lowest-scoring ones instead), and pick
  product types appropriate to the detected skinType (e.g. don't recommend heavy oils for
  Oily skin, don't recommend harsh actives for Sensitive skin). Two different faces with
  different metrics/skinType must get visibly different routines — same metrics/skinType
  should still get independently-generated, not templated, wording.
- If USER-REPORTED PROFILE is present above, routineSteps must also visibly address their
  stated concerns and lean toward their stated goal (e.g. goal "Anti-Aging" → favor
  retinoid/peptide-style treatment steps; goal "Clear Acne" → favor exfoliation/salicylic
  steps) whenever that's consistent with what the photo actually shows.
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


VERDICTS = {"improving", "steady", "worsening"}

PROGRESS_PROMPT = """
You are a dermatology-aware skin progress analyst for a consumer skincare app.
You are given TWO photos of the SAME person's face — the FIRST photo is their
earliest scan, the SECOND photo is their most recent scan — plus PRECOMPUTED,
ALREADY-CORRECT trend facts comparing their metrics between those two scans.

CRITICAL: The numeric trends given below are already computed correctly by
the app. Do NOT recompute, re-derive, or contradict them. Treat every value
in TRENDS as ground truth. Your job is to (1) visually compare the two
photos ONLY to describe what changed (texture, clarity, redness, etc.) — if
lighting, angle, or distance differ enough that the photos aren't visually
comparable, say so implicitly by relying on the given trends rather than
guessing from the images, (2) explain WHY the trends look the way they do in
plain, encouraging language, and (3) adapt the routine.

TRENDS (ground truth, do not alter the numbers):
{trends_json}

CURRENT ROUTINE:
{routine_json}

Return ONLY a JSON object (no markdown) with EXACTLY this shape:
{{
  "verdict": <one of "improving","steady","worsening">,
  "headline": <one short encouraging sentence, max 80 chars, consistent with verdict>,
  "narrative": <2-3 sentences explaining the trend in plain language, max 400 chars>,
  "working": [<metric names from TRENDS whose direction is "better">],
  "stalled": [<metric names from TRENDS whose direction is "flat">],
  "watch": [<metric names from TRENDS whose direction is "worse">],
  "updatedRoutine": [
    {{
      "time": <"AM" or "PM">,
      "category": <e.g. "Cleanser","Treatment","Moisturizer","Sunscreen">,
      "title": <short product/step name, max 40 chars>,
      "detail": <one sentence, max 140 chars, tied to a specific trend above>,
      "tags": [<0-3 short tags>]
    }}
    // 4-8 steps, adapted from CURRENT ROUTINE: keep steps tied to metrics
    // that are "working" as-is, and change the approach (different active
    // ingredient, different category) for steps tied to "stalled" or
    // "watch" metrics rather than repeating what evidently isn't moving them
  ]
}}

Rules:
- verdict MUST be consistent with the given trends: "improving" only if the
  overall trend or at least one metric is "better" and none are "worse";
  "worsening" only if at least one is "worse" and none improved; otherwise
  "steady".
- Never claim to detect medical conditions. Be encouraging but honest — do
  not claim improvement that the given trends do not support.
- Output raw JSON only.
""".strip()


def _normalize_progress(parsed: dict, trends: list) -> dict:
    """Coerce progress-analysis model output into the exact shape the app expects.

    working/stalled/watch are derived directly from `trends` (the Swift-computed,
    ground-truth direction per metric) — NEVER from the model's own bucketing —
    so a model mistake or hallucination can never mislabel a metric's trend.
    """
    verdict = parsed.get("verdict") if parsed.get("verdict") in VERDICTS else "steady"
    valid_trends = [t for t in trends if isinstance(t, dict) and t.get("name")]

    return {
        "verdict": verdict,
        "headline": str(parsed.get("headline", ""))[:120],
        "narrative": str(parsed.get("narrative", ""))[:400],
        "working": [t["name"] for t in valid_trends if t.get("direction") == "better"],
        "stalled": [t["name"] for t in valid_trends if t.get("direction") == "flat"],
        "watch": [t["name"] for t in valid_trends if t.get("direction") == "worse"],
        "updatedRoutine": [
            _normalize_routine_step(s) for s in (parsed.get("updatedRoutine") or [])
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


def _generate(parts: list, prompt: str) -> str:
    """Call Vertex Gemini with an arbitrary prompt + content parts; retry on the lite tier.

    Shared by /api/skin/analyze and /api/skin/progress so both endpoints get
    the same model-fallback behavior and the same bounded output budget.
    """
    config = types.GenerateContentConfig(response_mime_type="application/json",
                                         temperature=0.4, max_output_tokens=4096)
    last_err = None
    for model in (PRIMARY_MODEL, FALLBACK_MODEL):
        try:
            resp = _client.models.generate_content(
                model=model, contents=[prompt, *parts], config=config)
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
    profile = None
    try:
        if request.is_json:
            data = request.get_json(silent=True) or {}
            b64 = data.get("image_base64")
            if not b64:
                return jsonify({"error": "Missing image_base64"}), 400
            if "," in b64:  # strip data URL prefix if present
                b64 = b64.split(",", 1)[1]
            image = Image.open(io.BytesIO(base64.b64decode(b64)))
            profile = {
                "skin_type": data.get("skin_type"),
                "goal": data.get("goal"),
                "concerns": data.get("concerns"),
            }
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
        image_part = types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg")
        raw = _generate([image_part], _build_analysis_prompt(profile))
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            # last-resort: pull the outermost JSON object
            s, e = raw.find("{"), raw.rfind("}")
            parsed = json.loads(raw[s:e + 1]) if s != -1 and e != -1 else {}
        if not raw.strip() or not parsed:
            raise RuntimeError("Model returned no usable content")
        return jsonify({"success": True, "result": _normalize(parsed)})
    except Exception as e:
        print(f"[ERROR] analyze failed: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/api/skin/progress", methods=["POST"])
def analyze_progress():
    if _client is None:
        return jsonify({"error": "Server not configured (Vertex client unavailable)"}), 500
    if not _authorized(request):
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    trends = data.get("trends")
    overall = data.get("overall")
    if not isinstance(trends, list) or not trends or not isinstance(overall, dict):
        return jsonify({"error": "Missing or invalid trends/overall"}), 400

    # Defensive caps regardless of what the client actually sent.
    trends = trends[:12]
    history = (data.get("history") or [])[:8]
    current_routine = (data.get("current_routine") or [])[:8]

    def _decode_image(b64):
        if not b64:
            return None
        if "," in b64:
            b64 = b64.split(",", 1)[1]
        if len(b64) > 8_000_000:
            return None
        try:
            image = Image.open(io.BytesIO(base64.b64decode(b64)))
        except Exception:
            return None
        buf = io.BytesIO()
        image.convert("RGB").save(buf, format="JPEG", quality=90)
        return buf.getvalue()

    parts = []
    for key in ("first_image_base64", "latest_image_base64"):
        img_bytes = _decode_image(data.get(key))
        if img_bytes:
            parts.append(types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"))

    prompt = PROGRESS_PROMPT.format(
        trends_json=json.dumps({
            "overall": overall,
            "metrics": trends,
            "history": history,
            "spanDays": data.get("span_days"),
            "scanCount": data.get("scan_count"),
        }),
        routine_json=json.dumps(current_routine),
    )
    if not parts:
        prompt = ("NOTE: No photos were provided for this comparison — rely entirely on "
                  "TRENDS below; do not describe or reference any visual appearance.\n\n") + prompt

    try:
        raw = _generate(parts, prompt)
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            s, e = raw.find("{"), raw.rfind("}")
            parsed = json.loads(raw[s:e + 1]) if s != -1 and e != -1 else {}
        if not raw.strip() or not parsed:
            raise RuntimeError("Model returned no usable content")
        return jsonify({"success": True, "result": _normalize_progress(parsed, trends)})
    except Exception as e:
        print(f"[ERROR] progress analysis failed: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(debug=True, host="0.0.0.0", port=port)
