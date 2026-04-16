# Render Deployment (Backend)

Use the root `render.yaml` blueprint when possible. If you prefer manual setup,
create a Render **Web Service** from this repository and set:

- Root Directory: `backend`
- Build Command: `pip install -r requirements.txt`
- Start Command: `gunicorn app.main:app --bind 0.0.0.0:$PORT --workers 2 --timeout 120`
- Health Check Path: `/healthz`
- Runtime config note: `APP_ENV=production` now fails fast if `SECRET_KEY` is left
  at the default value or if `CORS_ORIGINS=*`.

## Required Environment Variables

- `APP_ENV=production`
- `SECRET_KEY=<random-secret>`
- `CORS_ORIGINS=https://your-frontend-domain`
- `AI_PROVIDER=rules` (or `openai`; use `llama_cpp` only if your model server is reachable from Render)
- `OPENAI_MODEL=gpt-4.1-mini`
- `OPENAI_TIMEOUT_SECONDS=20`

Optional when using OpenAI mode:

- `OPENAI_API_KEY=<secret-key>`
- `OPENAI_BASE_URL=https://api.openai.com/v1`

Optional when using llama.cpp mode:

- `LLAMA_CPP_MODEL=local-model`
- `LLAMA_CPP_BASE_URL=http://your-llama-host:8080`
- `LLAMA_CPP_TIMEOUT_SECONDS=60`
- The backend uses llama.cpp's OpenAI-compatible `POST /v1/chat/completions`
  route and will fall back from `json_schema` to plain `json_object` output if
  the server build does not support schema-constrained responses.

Safety controls:

- `MAX_REQUEST_SIZE_KB=256`
- `AI_RATE_LIMIT_PER_MINUTE=30`
- Note: the built-in limiter is in-memory per worker process. For strict global limits across multiple workers/instances, use an external shared limiter (Redis/API gateway).

## Database Configuration

Choose one backend:

### SQLite (default)

- `DB_BACKEND=sqlite`
- `SQLITE_PATH=data/app.db`
- Use this only for local/dev or demos. On Render free instances, local filesystem data is ephemeral and can be lost on redeploy/restart.
- For persistent production data, prefer MySQL (or attach a persistent disk on a paid plan).

### MySQL

- `DB_BACKEND=mysql`
- `MYSQL_HOST=<host>`
- `MYSQL_PORT=3306`
- `MYSQL_DB=heartanalysis`
- `MYSQL_USER=<user>`
- `MYSQL_PASSWORD=<password>`

## Migrations

Run during deploy or one-off shell:

```bash
alembic upgrade head
```
