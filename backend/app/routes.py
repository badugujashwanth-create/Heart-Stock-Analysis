from __future__ import annotations

import logging
import uuid
from datetime import UTC, datetime
from typing import Any

from flask import Blueprint, current_app, g, jsonify, request
from pydantic import ValidationError

from .ai.rate_limit import InMemoryRateLimiter
from .ai.schemas import AIChatRequest, AIPlanRequest, PredictionOutputInput
from .ai.service import AIService
from .db import session_scope
from .ml import model_card, run_model
from .repository import latest_prediction_summary, list_predictions, save_prediction
from .schemas import PredictionInput, pydantic_error_payload

api = Blueprint("api", __name__)
logger = logging.getLogger("heartanalysis-backend")


def _validation_error(details: list[dict[str, str]]):
    return jsonify({"error": "validation_error", "details": details}), 400


def _parse_json_object():
    payload = request.get_json(silent=True)
    if payload is None:
        return _validation_error([{"field": "body", "message": "JSON body is required"}])
    if not isinstance(payload, dict):
        return _validation_error([{"field": "body", "message": "JSON body must be an object"}])
    return payload


def _parse_prediction_payload(payload: Any):
    if payload is None:
        return _validation_error([{"field": "body", "message": "JSON body is required"}])
    if not isinstance(payload, dict):
        return _validation_error([{"field": "body", "message": "JSON body must be an object"}])
    try:
        return PredictionInput.model_validate(payload)
    except ValidationError as exc:
        return jsonify(pydantic_error_payload(exc)), 400


def _resolve_override_field(raw_key: str) -> str | None:
    field_map = {name.lower(): name for name in PredictionInput.model_fields}
    alias_map = {
        "smoking": "smoking_status",
        "sleep": "sleep_hours",
        "exercise": "exercise_mins",
        "residence_type": "residence_type",
    }
    key = raw_key.strip().lower()
    if key in alias_map:
        key = alias_map[key]
    return field_map.get(key)


def _current_request_id() -> str:
    request_id = getattr(g, "request_id", None)
    if isinstance(request_id, str) and request_id:
        return request_id
    return uuid.uuid4().hex


def _get_ai_service() -> AIService:
    service = current_app.config.get("AI_SERVICE")
    if not isinstance(service, AIService):
        raise RuntimeError("AI service is not configured")
    return service


def _get_ai_limiter() -> InMemoryRateLimiter:
    limiter = current_app.config.get("AI_RATE_LIMITER")
    if not isinstance(limiter, InMemoryRateLimiter):
        raise RuntimeError("AI rate limiter is not configured")
    return limiter


def _enforce_ai_rate_limit():
    limiter = _get_ai_limiter()
    client_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown")
    key = f"{request.path}:{client_ip.split(',')[0].strip()}"
    allowed, retry_after = limiter.allow(key)
    if allowed:
        return None
    return (
        jsonify(
            {
                "error": "rate_limit_exceeded",
                "message": "Too many AI requests. Please retry later.",
                "retry_after_seconds": retry_after,
            }
        ),
        429,
    )


@api.get("/healthz")
def healthz():
    return jsonify({"status": "ok", "timestamp": datetime.now(UTC).isoformat()})


@api.get("/v1/model-card")
def model_card_endpoint():
    return jsonify(model_card())


def _predict_handler():
    payload = _parse_json_object()
    if isinstance(payload, tuple):
        return payload

    parsed = _parse_prediction_payload(payload)
    if not isinstance(parsed, PredictionInput):
        return parsed
    model_input = parsed

    with session_scope() as session:
        previous = latest_prediction_summary(session)
        output = run_model(model_input)

        output["assistant_context"] = {
            "latest_prediction_summary": previous,
            "current_prediction_summary": {
                "risk_probability": output["risk_probability"],
                "risk_label": output["risk_label"],
                "interpretation": output["interpretation"],
            },
            "prompt_hint": "Use top_factors and recommendations to explain next best actions.",
        }
        output_for_storage = dict(output)

        try:
            ai_service = _get_ai_service()
            ai_plan_request = AIPlanRequest(
                user_inputs=model_input,
                prediction_output=PredictionOutputInput.model_validate(output),
            )
            ai_plan = ai_service.generate_plan(ai_plan_request)
            output["ai_plan_preview"] = ai_service.preview(ai_plan).model_dump()
            output_for_storage["ai_plan"] = ai_plan.model_dump()
        except Exception as exc:
            logger.exception("ai_preview_generation_failed: %s", exc)
            output["ai_plan_preview"] = {
                "summary": "AI plan preview is temporarily unavailable.",
                "top_priorities": [],
                "disclaimer": output.get("disclaimer", ""),
            }

        save_prediction(
            session,
            request_id=_current_request_id(),
            payload=model_input,
            output=output_for_storage,
        )

    return jsonify(output)


@api.post("/predict")
def predict_legacy():
    return _predict_handler()


@api.post("/v1/predict")
def predict_v1():
    return _predict_handler()


@api.post("/v1/simulate")
def simulate_v1():
    payload = _parse_json_object()
    if isinstance(payload, tuple):
        return payload

    overrides = payload.get("overrides", {})
    if not isinstance(overrides, dict):
        return _validation_error(
            [{"field": "overrides", "message": "overrides must be an object"}]
        )

    if "input" in payload:
        base_payload = payload["input"]
    else:
        base_payload = {k: v for k, v in payload.items() if k != "overrides"}

    parsed = _parse_prediction_payload(base_payload)
    if not isinstance(parsed, PredictionInput):
        return parsed
    baseline_input = parsed

    base_data = baseline_input.model_dump()
    merged_data = dict(base_data)
    detail_errors: list[dict[str, str]] = []

    for raw_key, raw_value in overrides.items():
        if not isinstance(raw_key, str):
            detail_errors.append(
                {
                    "field": "overrides",
                    "message": "override keys must be strings",
                }
            )
            continue

        resolved_key = _resolve_override_field(raw_key)
        if resolved_key is None:
            detail_errors.append(
                {
                    "field": f"overrides.{raw_key}",
                    "message": "unknown override field",
                }
            )
            continue
        merged_data[resolved_key] = raw_value

    if detail_errors:
        return _validation_error(detail_errors)

    try:
        simulated_input = PredictionInput.model_validate(merged_data)
    except ValidationError as exc:
        return jsonify(pydantic_error_payload(exc)), 400

    baseline_output = run_model(baseline_input)
    simulated_output = run_model(simulated_input)

    delta_risk = round(
        simulated_output["risk_probability"] - baseline_output["risk_probability"], 4
    )
    if delta_risk > 0.001:
        direction = "higher"
    elif delta_risk < -0.001:
        direction = "lower"
    else:
        direction = "unchanged"

    simulated_data = simulated_input.model_dump()
    changed_factors = [
        {
            "field": key,
            "before": base_data[key],
            "after": simulated_data[key],
        }
        for key in simulated_data
        if simulated_data[key] != base_data[key]
    ]

    return jsonify(
        {
            "baseline": {
                "risk_probability": baseline_output["risk_probability"],
                "risk_label": baseline_output["risk_label"],
            },
            "simulated": {
                "risk_probability": simulated_output["risk_probability"],
                "risk_label": simulated_output["risk_label"],
            },
            "delta": {
                "risk_probability": delta_risk,
                "direction": direction,
            },
            "changed_factors": changed_factors,
            "disclaimer": baseline_output["disclaimer"],
        }
    )


@api.post("/v1/ai/plan")
def ai_plan_v1():
    blocked = _enforce_ai_rate_limit()
    if blocked is not None:
        return blocked

    payload = _parse_json_object()
    if isinstance(payload, tuple):
        return payload

    try:
        request_data = AIPlanRequest.model_validate(payload)
    except ValidationError as exc:
        return jsonify(pydantic_error_payload(exc)), 400

    plan = _get_ai_service().generate_plan(request_data)
    return jsonify(plan.model_dump(mode="json"))


@api.post("/v1/ai/chat")
def ai_chat_v1():
    blocked = _enforce_ai_rate_limit()
    if blocked is not None:
        return blocked

    payload = _parse_json_object()
    if isinstance(payload, tuple):
        return payload

    try:
        request_data = AIChatRequest.model_validate(payload)
    except ValidationError as exc:
        return jsonify(pydantic_error_payload(exc)), 400

    response = _get_ai_service().chat(request_data)
    return jsonify(response.model_dump(mode="json"))


@api.get("/v1/predictions")
def predictions_history():
    raw_limit = request.args.get("limit", "20")
    try:
        limit = int(raw_limit)
    except ValueError:
        return (
            jsonify(
                {
                    "error": "validation_error",
                    "details": [{"field": "limit", "message": "must be an integer"}],
                }
            ),
            400,
        )

    if limit < 1 or limit > 100:
        return (
            jsonify(
                {
                    "error": "validation_error",
                    "details": [{"field": "limit", "message": "must be between 1 and 100"}],
                }
            ),
            400,
        )

    with session_scope() as session:
        records = list_predictions(session, limit)

    return jsonify({"count": len(records), "records": records})
