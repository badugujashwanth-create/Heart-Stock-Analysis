# HeartAnalysis Deployment Guide

This guide covers deployment for both frontend (Flutter) and backend (Flask API).

## 1) Prerequisites

- Flutter stable SDK
- Android Studio / Xcode as needed
- Python 3.10+ for backend
- Render account (for backend and optional web hosting)

## 2) Frontend Build Commands

```bash
flutter pub get
flutter analyze
flutter test
```

### Android

```bash
flutter build apk --release --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://your-api.onrender.com
```

### Web

```bash
flutter build web --release --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://your-api.onrender.com
```

## 3) Backend Local Run

```bash
python -m pip install -r requirements.txt
python app.py
```

Local API: `http://localhost:8000`

Health check: `http://localhost:8000/healthz`

## 4) Backend Deploy on Render

Create a **Web Service** using this repo.

- Language: `Python 3`
- Root Directory: *(blank)*
- Build Command: `pip install -r requirements.txt`
- Start Command: `gunicorn app:app --bind 0.0.0.0:$PORT --workers 2 --timeout 120`
- Health Check Path: `/healthz`
- SQLite mode (default): `PREDICTION_DB_PATH=/var/data/predictions.db`
- MySQL mode (optional):
  - `DB_BACKEND=mysql`
  - `DB_HOST=...`
  - `DB_PORT=3306`
  - `DB_USER=...`
  - `DB_PASSWORD=...`
  - `DB_NAME=heartanalysis`

After deployment, copy the Render URL and use it as `API_BASE_URL` in Flutter builds.

### Persistence note

- Render Free instances do not provide durable local disk storage.
- If you need records to survive redeploy/restarts, use durable storage:
  - Render Postgres, or
  - a paid instance with persistent disk.

## 5) Backend API Endpoints

- `GET /`
- `GET /healthz`
- `GET /v1/healthz`
- `GET /v1/model-card`
- `POST /predict`
- `POST /v1/predict`

## 6) CI/CD

Workflows included:

- `.github/workflows/quality-checks.yml`:
  - backend tests (`python -m unittest`)
  - `flutter analyze`
  - `flutter test`
- `.github/workflows/deploy-web.yml`:
  - deploys Flutter web to GitHub Pages

## 7) Quick Verify Checklist

1. `GET /healthz` returns `200`
2. `POST /predict` returns `stroke_prediction`, `risk_label`, `top_factors`
3. Flutter app can submit form and render recommendations/AI insights
4. CI checks pass on `main`
