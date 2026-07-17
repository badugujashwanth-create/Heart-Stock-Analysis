# Development guide

## Purpose

Flutter client and Flask API for educational heart-risk estimation, history, explanations, and local or MySQL persistence.

## Prerequisites

Flutter/Dart, Flask, Pydantic, SQLAlchemy, Alembic, SQLite/MySQL.

## Install

```powershell
flutter pub get; cd backend; python -m venv .venv; .\.venv\Scripts\python -m pip install -r requirements-dev.txt
```

## Run

```powershell
Run the Flask backend, then `flutter run` from the selected Flutter client directory
```

## Verify

- Tests: `Backend: pytest; Flutter: flutter test`
- Build: `Flutter platform build (not executed in this audit)`

See [TEST_REPORT.md](TEST_REPORT.md) for the latest audited results. Copy example environment files instead of committing real values. Generated dependencies, caches, logs, databases, and build output must remain untracked.

