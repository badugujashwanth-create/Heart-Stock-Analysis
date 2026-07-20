# Development guide

## Canonical packages

Run backend commands from `backend/` and Flutter commands from `frontend/`. Do not run the historical root package for release verification.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements-dev.txt
cd ..\frontend
flutter pub get
```

For the safe local product flow, run `scripts/run-demo.ps1` from the repository root. It uses the rules provider, a localhost API, and an isolated synthetic-history database.

Verification commands are recorded in [TEST_REPORT.md](TEST_REPORT.md). Use `PERSIST_PREDICTIONS=true` only for an isolated synthetic-data demo. Never commit `.env`, databases, generated dependencies, test output, or recordings containing personal data.
