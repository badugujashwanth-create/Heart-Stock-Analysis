import threading
from collections.abc import Generator
from contextlib import contextmanager

from sqlalchemy import Engine, create_engine
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session, declarative_base, sessionmaker

Base = declarative_base()

_engine: Engine | None = None
_SessionLocal: sessionmaker[Session] | None = None
_engine_lock = threading.Lock()


def _normalize_database_uri(database_uri: str) -> str:
    try:
        return make_url(database_uri).render_as_string(hide_password=False)
    except Exception:
        return database_uri.strip()


def init_engine(database_uri: str) -> None:
    global _engine, _SessionLocal

    requested_uri = _normalize_database_uri(database_uri)
    with _engine_lock:
        if _engine is not None:
            current_uri = _normalize_database_uri(str(_engine.url))
            if current_uri == requested_uri:
                return

        _engine = create_engine(database_uri, pool_pre_ping=True, future=True)
        _SessionLocal = sessionmaker(
            bind=_engine,
            autoflush=False,
            autocommit=False,
            expire_on_commit=False,
            future=True,
        )


def get_engine() -> Engine:
    if _engine is None:
        raise RuntimeError("Database engine is not initialized")
    return _engine


def get_session_factory() -> sessionmaker[Session]:
    if _SessionLocal is None:
        raise RuntimeError("Database session factory is not initialized")
    return _SessionLocal


@contextmanager
def session_scope() -> Generator[Session, None, None]:
    session = get_session_factory()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
