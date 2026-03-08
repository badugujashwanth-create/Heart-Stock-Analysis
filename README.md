# HeartAnalysis Monorepo

Production-ready stroke-risk analysis system with:
- `backend/`: Flask API, validation, interpretable model, persistence, migrations, tests.
- `frontend/`: Flutter app (Android/Web/Desktop) with Form, Report, History, Assistant, and PDF export.

## Repository Structure

```text
heartanalysis/
  backend/
    app/
    alembic/
    tests/
    Dockerfile
    requirements.txt
    requirements-dev.txt
    .env.example
    RENDER.md
  frontend/
    lib/
      screens/
      services/
      state/
      widgets/
    test/
    pubspec.yaml
    .env.example
  .github/workflows/
    quality-checks.yml
    deploy-web.yml
```

## Backend

### Features
- Flask + Gunicorn entrypoint (`app.main:app`).
- Endpoints:
  - `GET /healthz`
  - `GET /v1/model-card`
  - `POST /predict`
  - `POST /v1/predict`
  - `POST /v1/simulate`
  - `POST /v1/ai/plan`
  - `POST /v1/ai/chat`
  - `GET /v1/predictions?limit=20`
- Input validation with Pydantic (400 + field-level details on invalid input).
- Interpretable logistic-style model:
  - `risk_probability`, `risk_label`
  - `top_factors` with contribution scores
  - personalized `recommendations`
  - `interpretation`, `ai_summary`, `disclaimer`
  - `assistant_context` with latest prediction summary
- Persistence:
  - SQLAlchemy model for all predictions (timestamp + input/output payloads)
  - default SQLite (`data/app.db`)
  - optional MySQL via env
- AI assistant layer:
  - provider mode: `rules`, `llama_cpp` (recommended local inference), or `openai`
  - safe structured output with disclaimer always included
  - `ai_plan_preview` attached to `/v1/predict`
  - full `ai_plan` stored in prediction output payload for history/audit
- Safety controls:
  - request body size limit (`MAX_REQUEST_SIZE_KB`)
  - in-memory AI endpoint rate limiting (`AI_RATE_LIMIT_PER_MINUTE`)
  - rate limiter scope is per process; use shared infra (Redis/API gateway) for global limits across workers
- Alembic migrations included.
- Pytest coverage for endpoint and validation behavior.

### Backend Env (`backend/.env`)

Use `backend/.env.example`:

```env
APP_ENV=development
SECRET_KEY=change-this-secret

DB_BACKEND=sqlite
SQLITE_PATH=data/app.db

MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DB=heartanalysis
MYSQL_USER=root
MYSQL_PASSWORD=change-me

CORS_ORIGINS=*

AI_PROVIDER=llama_cpp
LLAMA_CPP_MODEL=local-model
LLAMA_CPP_BASE_URL=http://127.0.0.1:8080
LLAMA_CPP_TIMEOUT_SECONDS=60

OPENAI_API_KEY=
OPENAI_MODEL=gpt-4.1-mini
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_TIMEOUT_SECONDS=20

MAX_REQUEST_SIZE_KB=256
AI_RATE_LIMIT_PER_MINUTE=30
```

### AI Provider Modes

Rules mode (no model server required):

```env
AI_PROVIDER=rules
```

llama.cpp mode (recommended, no external API key):

```env
AI_PROVIDER=llama_cpp
LLAMA_CPP_MODEL=local-model
LLAMA_CPP_BASE_URL=http://127.0.0.1:8080
LLAMA_CPP_TIMEOUT_SECONDS=60
```

Run a local `llama.cpp` server first, for example:

```bash
llama-server -m /path/to/model.gguf --host 0.0.0.0 --port 8080
```

OpenAI mode:

```env
AI_PROVIDER=openai
OPENAI_API_KEY=your_key_here
OPENAI_MODEL=gpt-4.1-mini
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_TIMEOUT_SECONDS=20
```

### Run Backend Locally

```bash
cd backend
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
alembic upgrade head
gunicorn app.main:app --bind 0.0.0.0:8000 --workers 2 --timeout 120
```

Alternative dev run:

```bash
cd backend
python -m app.main
```

For mobile testing on the same Wi-Fi network, point the Flutter app to your PC IP instead of `localhost`.
On this machine that address is `192.168.0.2`, so use `http://192.168.0.2:8000`.
For USB testing on a connected Android device, run `adb reverse tcp:8000 tcp:8000` and use `http://127.0.0.1:8000`.

### Backend Quality Checks

```bash
cd backend
ruff check app tests
pytest -q
```

### Backend Docker

```bash
cd backend
docker build -t heartanalysis-backend .
docker run --rm -p 8000:8000 --env-file .env heartanalysis-backend
```

Render-specific setup is documented in `backend/RENDER.md`.

### Sample cURL Requests

Generate prediction:

```bash
curl -X POST http://localhost:8000/v1/predict \
  -H "Content-Type: application/json" \
  -d '{
    "age": 56,
    "gender": "Male",
    "hypertension": "Yes",
    "heart_disease": "No",
    "ever_married": "Yes",
    "work_type": "Private",
    "Residence_type": "Urban",
    "avg_glucose_level": 132.5,
    "bmi": 27.2,
    "smoking_status": "Formerly",
    "systolic_bp": 148,
    "diastolic_bp": 92,
    "alcoholic": "No",
    "family_history": "Yes",
    "sleep_hours": 6,
    "exercise_mins": 25,
    "excess_salt": "Yes"
  }'
```

Generate full AI plan:

```bash
curl -X POST http://localhost:8000/v1/ai/plan \
  -H "Content-Type: application/json" \
  -d '{
    "user_inputs": {
      "age": 56,
      "gender": "Male",
      "hypertension": "Yes",
      "heart_disease": "No",
      "ever_married": "Yes",
      "work_type": "Private",
      "Residence_type": "Urban",
      "avg_glucose_level": 132.5,
      "bmi": 27.2,
      "smoking_status": "Formerly",
      "systolic_bp": 148,
      "diastolic_bp": 92,
      "alcoholic": "No",
      "family_history": "Yes",
      "sleep_hours": 6,
      "exercise_mins": 25,
      "excess_salt": "Yes"
    },
    "prediction_output": {
      "risk_probability": 0.62,
      "risk_label": "High",
      "top_factors": [{"feature":"bmi","value":0.3,"contribution":0.4,"direction":"increase"}],
      "recommendations": ["Increase activity"],
      "interpretation": "Estimated risk is high",
      "ai_summary": "Short summary",
      "disclaimer": "Educational only"
    },
    "user_preferences": {
      "diet_type": "veg",
      "allergies": [],
      "cuisine": ["indian"],
      "budget": "medium",
      "activity_level": "light",
      "goal": "reduce_risk"
    }
  }'
```

AI chat:

```bash
curl -X POST http://localhost:8000/v1/ai/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What should I focus on this week?",
    "prediction_output": {
      "risk_probability": 0.62,
      "risk_label": "High",
      "top_factors": [{"feature":"bmi","value":0.3,"contribution":0.4,"direction":"increase"}],
      "recommendations": ["Increase activity"],
      "interpretation": "Estimated risk is high",
      "ai_summary": "Short summary",
      "disclaimer": "Educational only"
    }
  }'
```

## Frontend (Flutter)

### Features
- Multi-platform Flutter app (Android/Web/Desktop).
- Tabs:
  1. Input form
  2. Risk report (gauge, interpretation, factors, recommendations, AI Plan)
  3. History (`/v1/predictions?limit=20`) with trend chart
  4. What-If simulator (`/v1/simulate`) for BMI/sleep/exercise/smoking changes
  5. Assistant tab backed by `/v1/ai/chat` with safe disclaimers
- AI Plan UI includes:
  - top priorities
  - diet day plan + weekly focus
  - exercise weekly schedule
  - habits checklist
- API base URL from config using `--dart-define=API_BASE_URL=...` (preferred).

### Run Frontend On Android Device

```bash
cd frontend
flutter pub get
flutter run -d A001 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```
- PDF export using `pdf` + `printing`.
- PDF includes AI priorities + diet/exercise plan and disclaimer footer on each page.
- Responsive layout with API timeout/error handling.

### Frontend Config

Use `frontend/.env.example` for local reference:

```env
API_BASE_URL=http://localhost:8000
```

Set the API URL at run/build time:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

### Run Frontend Locally

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

Useful targets:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8000
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Frontend Quality Checks

```bash
cd frontend
flutter analyze
flutter test
```

## CI

GitHub Actions workflow in `.github/workflows/quality-checks.yml` runs on push and pull requests:
- Backend: `ruff check` + `pytest`
- Frontend: `flutter analyze` + `flutter test`

## Production Notes

- Do not store secrets in git.
- SQLite is fine for local/testing; use managed MySQL in production.
- AI features are educational planning support and not medical diagnosis/treatment advice.
