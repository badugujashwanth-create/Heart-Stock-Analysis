from __future__ import annotations

from pathlib import Path

import pytest

from app.config import load_settings
from app.main import create_app


def _base_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("DB_BACKEND", "sqlite")
    monkeypatch.setenv("SQLITE_PATH", str(tmp_path / "deploy.db"))
    monkeypatch.setenv("AI_PROVIDER", "rules")
    monkeypatch.setenv("SECRET_KEY", "production-secret")
    monkeypatch.setenv("CORS_ORIGINS", "https://heart.example.com")
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)


def test_create_app_rejects_default_secret_in_production(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _base_env(tmp_path, monkeypatch)
    monkeypatch.setenv("SECRET_KEY", "change-me")

    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        create_app()


def test_create_app_rejects_wildcard_cors_in_production(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _base_env(tmp_path, monkeypatch)
    monkeypatch.setenv("CORS_ORIGINS", "*")

    with pytest.raises(RuntimeError, match="CORS_ORIGINS"):
        create_app()


def test_openai_provider_requires_api_key(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _base_env(tmp_path, monkeypatch)
    monkeypatch.setenv("AI_PROVIDER", "openai")
    monkeypatch.setenv("OPENAI_API_KEY", "")

    settings = load_settings()
    assert settings.startup_errors() == [
        "OPENAI_API_KEY is required when AI_PROVIDER=openai."
    ]
