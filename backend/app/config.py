import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote_plus

from dotenv import load_dotenv


def _parse_origins(raw: str) -> list[str]:
    if not raw:
        return ["*"]
    return [item.strip() for item in raw.split(",") if item.strip()]


@dataclass(slots=True)
class Settings:
    app_env: str
    secret_key: str
    db_backend: str
    sqlite_path: str
    mysql_host: str
    mysql_port: int
    mysql_db: str
    mysql_user: str
    mysql_password: str
    cors_origins: list[str]
    ai_provider: str
    openai_api_key: str
    openai_model: str
    openai_base_url: str
    openai_timeout_seconds: int
    llama_cpp_model: str
    llama_cpp_base_url: str
    llama_cpp_timeout_seconds: int
    max_request_size_kb: int
    ai_rate_limit_per_minute: int

    @property
    def sqlalchemy_database_uri(self) -> str:
        if self.db_backend == "mysql":
            user = quote_plus(self.mysql_user)
            password = quote_plus(self.mysql_password)
            return (
                f"mysql+pymysql://{user}:{password}@{self.mysql_host}:{self.mysql_port}/"
                f"{self.mysql_db}?charset=utf8mb4"
            )

        sqlite_path = Path(self.sqlite_path)
        if not sqlite_path.is_absolute():
            sqlite_path = Path.cwd() / sqlite_path
        sqlite_path.parent.mkdir(parents=True, exist_ok=True)
        return f"sqlite:///{sqlite_path.as_posix()}"


def load_settings() -> Settings:
    backend_root = Path(__file__).resolve().parents[1]
    load_dotenv(backend_root / ".env")
    load_dotenv()

    db_backend = os.getenv("DB_BACKEND", "sqlite").lower().strip()
    if db_backend not in {"sqlite", "mysql"}:
        db_backend = "sqlite"

    ai_provider = os.getenv("AI_PROVIDER", "rules").lower().strip()
    if ai_provider not in {"openai", "rules", "llama_cpp"}:
        ai_provider = "rules"
    openai_model = os.getenv("OPENAI_MODEL", "gpt-4.1-mini").strip() or "gpt-4.1-mini"
    openai_base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").strip() or "https://api.openai.com/v1"
    llama_cpp_model = os.getenv("LLAMA_CPP_MODEL", "local-model").strip() or "local-model"
    llama_cpp_base_url = os.getenv("LLAMA_CPP_BASE_URL", "http://127.0.0.1:8080").strip() or "http://127.0.0.1:8080"

    return Settings(
        app_env=os.getenv("APP_ENV", "development"),
        secret_key=os.getenv("SECRET_KEY", "change-me-in-production"),
        db_backend=db_backend,
        sqlite_path=os.getenv("SQLITE_PATH", "data/app.db"),
        mysql_host=os.getenv("MYSQL_HOST", "localhost"),
        mysql_port=int(os.getenv("MYSQL_PORT", "3306")),
        mysql_db=os.getenv("MYSQL_DB", "heartanalysis"),
        mysql_user=os.getenv("MYSQL_USER", "root"),
        mysql_password=os.getenv("MYSQL_PASSWORD", ""),
        cors_origins=_parse_origins(os.getenv("CORS_ORIGINS", "*")),
        ai_provider=ai_provider,
        openai_api_key=os.getenv("OPENAI_API_KEY", ""),
        openai_model=openai_model,
        openai_base_url=openai_base_url,
        openai_timeout_seconds=int(os.getenv("OPENAI_TIMEOUT_SECONDS", "20")),
        llama_cpp_model=llama_cpp_model,
        llama_cpp_base_url=llama_cpp_base_url,
        llama_cpp_timeout_seconds=int(os.getenv("LLAMA_CPP_TIMEOUT_SECONDS", "60")),
        max_request_size_kb=int(os.getenv("MAX_REQUEST_SIZE_KB", "256")),
        ai_rate_limit_per_minute=int(os.getenv("AI_RATE_LIMIT_PER_MINUTE", "30")),
    )
