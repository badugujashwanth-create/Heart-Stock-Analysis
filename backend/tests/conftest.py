from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest
from flask.testing import FlaskClient


def _configure_test_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("DB_BACKEND", "sqlite")
    monkeypatch.setenv("SQLITE_PATH", str(tmp_path / "test.db"))
    monkeypatch.setenv("CORS_ORIGINS", "*")
    monkeypatch.setenv("SECRET_KEY", "test-secret")
    monkeypatch.setenv("AI_PROVIDER", "rules")
    monkeypatch.setenv("OPENAI_API_KEY", "")
    monkeypatch.setenv("OPENAI_MODEL", "gpt-4.1-mini")
    monkeypatch.setenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
    monkeypatch.setenv("OPENAI_TIMEOUT_SECONDS", "20")
    monkeypatch.setenv("MAX_REQUEST_SIZE_KB", "256")
    monkeypatch.setenv("AI_RATE_LIMIT_PER_MINUTE", "50")


@pytest.fixture()
def client(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> Generator[FlaskClient, None, None]:
    _configure_test_env(tmp_path, monkeypatch)

    from app.db import Base, get_engine
    from app.main import create_app

    app = create_app()
    app.config["TESTING"] = True

    # Clean schema for each test.
    Base.metadata.drop_all(bind=get_engine())
    Base.metadata.create_all(bind=get_engine())

    with app.test_client() as test_client:
        yield test_client
