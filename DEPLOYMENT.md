# HeartAnalysis Deployment Guide

This repository’s deployable targets are:

- `backend/`: Flask API deployed as a Python web service
- `frontend/`: Flutter web app deployed as static files

The older root-level Flutter/Python prototype is not the deployment target for
CI or production.

## 1) Backend Deployment

### Recommended: Render blueprint

The repository now includes [`render.yaml`](./render.yaml). In Render:

1. Create a new Blueprint instance from this repository.
2. Review the generated backend service.
3. Set `CORS_ORIGINS` to your deployed frontend URL.
4. If you use OpenAI, add `OPENAI_API_KEY` and set `AI_PROVIDER=openai`.

The backend service uses:

- Root directory: `backend`
- Build command: `pip install -r requirements.txt`
- Start command: `gunicorn app.main:app --bind 0.0.0.0:$PORT --workers 2 --timeout 120`
- Health check path: `/healthz`

### Manual Render setup

If you do not use the blueprint, the same settings are documented in
[`backend/RENDER.md`](./backend/RENDER.md).

### Required production environment variables

Set these before first deploy:

```env
APP_ENV=production
SECRET_KEY=<strong-random-secret>
CORS_ORIGINS=https://your-frontend-host
AI_PROVIDER=rules
DB_BACKEND=sqlite
SQLITE_PATH=data/app.db
MAX_REQUEST_SIZE_KB=256
AI_RATE_LIMIT_PER_MINUTE=30
```

Important runtime checks:

- `APP_ENV=production` now fails startup if `SECRET_KEY` is left at a default value.
- `APP_ENV=production` now fails startup if `CORS_ORIGINS=*`.
- `AI_PROVIDER=openai` now fails startup unless `OPENAI_API_KEY` is set.

### Persistence note

SQLite is fine for demos and smoke deployments. It is not durable on ephemeral
instances. For persistent history in production, use managed MySQL or attach
persistent disk.

## 2) Frontend Deployment

### GitHub Pages workflow

The repository includes `.github/workflows/deploy-web.yml` to publish
`frontend/build/web` to GitHub Pages.

Before running it, set the repository variable:

```text
FRONTEND_API_BASE_URL=https://your-backend-host
```

The workflow now fails fast if this variable is missing, which prevents a broken
web deploy that points at `http://localhost:8000`.

### Manual web build

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://your-backend-host
```

### Android release build

```bash
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend-host
```

## 3) CI Coverage

`.github/workflows/quality-checks.yml` now verifies:

- backend linting with `ruff`
- backend tests with `pytest`
- frontend static analysis
- frontend widget/unit tests
- frontend release web build with an explicit `API_BASE_URL`

## 4) Post-Deploy Smoke Checklist

1. Open `GET /healthz` on the backend and confirm it returns `200`.
2. Send `POST /v1/predict` with a valid payload and confirm `risk_probability`, `risk_label`, and `ai_plan_preview` are returned.
3. Open the deployed web app and submit the form successfully.
4. Check browser network requests and confirm the frontend is calling your deployed backend host, not `localhost`.
