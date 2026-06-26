# ClearMaxx AI — backend

Flask service on **Google App Engine** that analyzes a face photo with **Gemini
2.5 Flash** and returns a structured skin report for the ClearMaxx iOS app.

- **Project:** `ai-backend-project-482118`
- **Service:** `clearmaxx` (separate from the `default` service so it does not
  clobber the chartsense backend in the same project)
- **URL:** https://clearmaxx-dot-ai-backend-project-482118.uc.r.appspot.com

## Security

- The Gemini key and the app token are stored **only in Google Secret Manager**
  (`clearmaxx-gemini-key`, `clearmaxx-app-token`). They are never in the code,
  in `app.yaml`, or in the iOS app.
- Every `POST /api/skin/analyze` request must send the header
  `X-App-Token: <clearmaxx-app-token>`; otherwise it returns `401`.

## Endpoints

| Method | Path                  | Notes                                   |
|--------|-----------------------|-----------------------------------------|
| GET    | `/health`             | liveness + config flags                 |
| POST   | `/api/skin/analyze`   | body `{ "image_base64": "..." }` + token |

## Deploy

```bash
cd backend
gcloud app deploy app.yaml --project ai-backend-project-482118
```

## Rotate / set a secret value (value never touches git)

```bash
printf '%s' 'NEW_KEY_VALUE' | \
  gcloud secrets versions add clearmaxx-gemini-key --data-file=- \
  --project ai-backend-project-482118
gcloud app deploy app.yaml --project ai-backend-project-482118   # pick up latest
```

## Local dev

```bash
cp .env.example .env          # fill GEMINI_API_KEY + APP_TOKEN (git-ignored)
pip install -r requirements.txt
python main.py                # http://localhost:8080
```
