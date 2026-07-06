# ClearMaxx AI — backend

Flask service on **Google App Engine** that analyzes a face photo with **Gemini
2.5 Flash on Vertex AI** and returns a structured skin report for the ClearMaxx
iOS app.

- **Project:** `faraz-mobile-apps`
- **Service:** `clearmaxx` (separate from the `default` service so it does not
  clobber anything else in the project)
- **URL:** https://clearmaxx-dot-faraz-mobile-apps.uc.r.appspot.com
- **AI:** Vertex AI (`aiplatform.googleapis.com`), region `us-central1`,
  model `gemini-2.5-flash` (falls back to `gemini-2.5-flash-lite`)

## Auth / security

- **No API key anywhere.** Gemini runs on **Vertex AI**, authenticated by the App
  Engine service account (`faraz-mobile-apps@appspot.gserviceaccount.com`) via
  Application Default Credentials. That SA holds `roles/aiplatform.user`.
- The **app token** is the only secret, stored in **Secret Manager**
  (`clearmaxx-app-token`). The SA has `roles/secretmanager.secretAccessor` on it.
- Every `POST /api/skin/analyze` request must send the header
  `X-App-Token: <clearmaxx-app-token>`; otherwise it returns `401`.

## Endpoints

| Method | Path                  | Notes                                    |
|--------|-----------------------|------------------------------------------|
| GET    | `/health`             | liveness + `{vertex_configured, auth_required}` |
| POST   | `/api/skin/analyze`   | body `{ "image_base64": "..." }` + token |

## Deploy

```bash
cd backend
gcloud app deploy app.yaml --project faraz-mobile-apps
```

App Engine injects `GOOGLE_CLOUD_PROJECT`; `VERTEX_LOCATION` is set in `app.yaml`.

## Rotate the app token (value never touches git)

```bash
printf '%s' 'NEW_TOKEN_VALUE' | \
  gcloud secrets versions add clearmaxx-app-token --data-file=- \
  --project faraz-mobile-apps
gcloud app deploy app.yaml --project faraz-mobile-apps   # pick up latest
# then update the iOS token: ./fetch-secrets.sh
```

## Local dev

```bash
gcloud auth application-default login   # supplies ADC for Vertex
cp .env.example .env                    # fill APP_TOKEN (git-ignored)
pip install -r requirements.txt
python main.py                          # http://localhost:8080
```
