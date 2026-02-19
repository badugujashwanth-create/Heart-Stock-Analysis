# HeartAnalysis

HeartAnalysis is a cross-platform Flutter app for stroke risk screening with a production-style Python backend API.
The backend now includes an interpretable AI scoring model, strict request validation, explainability output, and versioned API endpoints.

## Highlights

- Flutter app with onboarding, local session management, risk input form, assistant, settings, and PDF report export.
- AI-enhanced backend (`CardioRisk AI v2`) with:
  - validated request schema
  - calibrated risk scoring
  - top contributing factors
  - personalized recommendations
  - model/version metadata
- Contract compatibility: frontend accepts both legacy and enriched API responses.
- CI quality gates for both Flutter and backend.

## Architecture

- Frontend: Flutter (`lib/`)
- Backend API: Flask (`app.py`)
- API tests: `backend_tests/`
- CI workflows:
  - `.github/workflows/quality-checks.yml`
  - `.github/workflows/deploy-web.yml`

## Runtime Configuration

Use Dart defines instead of hardcoding environments:

```bash
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter build apk --release --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://your-api.onrender.com
```

Config source: `lib/config.dart`.

## Backend API

### Endpoints

- `GET /` : service metadata
- `GET /healthz` and `GET /v1/healthz` : health checks
- `GET /v1/model-card` : AI model metadata
- `POST /predict` and `POST /v1/predict` : risk prediction
- `GET /v1/predictions?limit=20` : recently stored prediction records

## Data Storage

- Backend predictions are persisted in a database.
- Default backend: SQLite (`data/predictions.db`).
- Optional MySQL backend via env vars:
  - `DB_BACKEND=mysql`
  - `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- SQLite path can be changed with `PREDICTION_DB_PATH`.
- On Render Free instances, local filesystem data is not durable across rebuilds/redeploys.
- For durable storage in production, use a managed database (for example Render Postgres) or a paid plan with persistent disk.

### Request body

`POST /predict` accepts:

- `age` (int)
- `gender` (`Male|Female|Other`)
- `hypertension`, `heart_disease`, `ever_married`, `alcoholic`, `family_history`, `excess_salt` (`Yes|No`)
- `work_type` (`Private|Self-employed|Govt|Children|Never worked`)
- `Residence_type` (`Urban|Rural`)
- `avg_glucose_level` (number)
- `bmi` (number)
- `smoking_status` (`Never|Formerly|Smokes`)
- `systolic_bp`, `diastolic_bp`, `sleep_hours`, `exercise_mins` (int)

### Response fields

Core fields:

- `stroke_prediction` (0-1)
- `stroke_probability` (0-100)
- `risk_label`
- `interpretation`

AI enrichments:

- `ai_summary`
- `top_factors` (list)
- `recommendations` (list)
- `model_name`, `model_version`
- `api_version`, `request_id`
- `disclaimer`

## Local Development

### Frontend

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Backend

```bash
python -m pip install -r requirements.txt
python app.py
```

Backend runs by default on `http://localhost:8000`.

## Testing

- Flutter tests: `flutter test`
- Backend tests: `python -m unittest discover -s backend_tests -p "test_*.py"`

## Render Deployment (Backend)

Use Render Web Service with:

- Language: `Python 3`
- Build: `pip install -r requirements.txt`
- Start: `gunicorn app:app --bind 0.0.0.0:$PORT --workers 2 --timeout 120`
- Health check path: `/healthz`

After deploy, update `API_BASE_URL` in Flutter build/run via `--dart-define`.

## Notes

This app provides educational risk estimation and is not a substitute for clinical diagnosis.
