from __future__ import annotations

import json
import logging
import time
import uuid

from flask import Flask, g, jsonify, request
from flask_cors import CORS
from sqlalchemy.exc import SQLAlchemyError

from .ai.rate_limit import InMemoryRateLimiter
from .ai.service import AIService
from .config import load_settings
from .db import Base, get_engine, init_engine
from .ml import model_card
from .routes import api

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("heartanalysis-backend")


def create_app() -> Flask:
    settings = load_settings()

    app = Flask(__name__)
    app.config["APP_ENV"] = settings.app_env
    app.config["SECRET_KEY"] = settings.secret_key
    app.config["DB_BACKEND"] = settings.db_backend
    app.config["SQLALCHEMY_DATABASE_URI"] = settings.sqlalchemy_database_uri
    app.config["AI_PROVIDER"] = settings.ai_provider
    app.config["OPENAI_MODEL"] = settings.openai_model
    app.config["MAX_CONTENT_LENGTH"] = settings.max_request_size_kb * 1024
    app.config["AI_RATE_LIMIT_PER_MINUTE"] = settings.ai_rate_limit_per_minute
    app.config["AI_SERVICE"] = AIService.from_settings(settings)
    app.config["AI_RATE_LIMITER"] = InMemoryRateLimiter(
        limit_per_minute=settings.ai_rate_limit_per_minute
    )

    CORS(app, resources={r"/*": {"origins": settings.cors_origins}})

    init_engine(settings.sqlalchemy_database_uri)
    Base.metadata.create_all(bind=get_engine())

    app.register_blueprint(api)

    @app.get("/")
    def root():
        return jsonify(
            {
                "service": "heartanalysis-api",
                "status": "ok",
                "env": settings.app_env,
                "db_backend": settings.db_backend,
                "endpoints": [
                    "/healthz",
                    "/v1/model-card",
                    "/predict",
                    "/v1/predict",
                    "/v1/simulate",
                    "/v1/ai/plan",
                    "/v1/ai/chat",
                    "/v1/predictions",
                ],
                "model": {
                    "name": model_card()["model_name"],
                    "version": model_card()["model_version"],
                },
            }
        )

    @app.before_request
    def before_request() -> None:
        g.request_id = uuid.uuid4().hex
        g.start_time = time.perf_counter()

    @app.after_request
    def after_request(response):
        request_id = getattr(g, "request_id", uuid.uuid4().hex)
        start_time = getattr(g, "start_time", None)
        elapsed_ms = None
        if isinstance(start_time, float):
            elapsed_ms = round((time.perf_counter() - start_time) * 1000, 2)

        response.headers["X-Request-ID"] = request_id
        logger.info(
            json.dumps(
                {
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.path,
                    "status": response.status_code,
                    "duration_ms": elapsed_ms,
                }
            )
        )
        return response

    @app.errorhandler(SQLAlchemyError)
    def database_error(error):
        logger.exception("database error")
        return (
            jsonify(
                {
                    "error": "database_error",
                    "message": "Internal database error.",
                    "request_id": getattr(g, "request_id", None),
                }
            ),
            500,
        )

    @app.errorhandler(404)
    def not_found(_error):
        return jsonify({"error": "not_found"}), 404

    @app.errorhandler(413)
    def request_too_large(_error):
        return (
            jsonify(
                {
                    "error": "request_too_large",
                    "message": "Request body exceeds maximum allowed size.",
                }
            ),
            413,
        )

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
