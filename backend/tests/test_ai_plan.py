from __future__ import annotations

import json
import os
from pathlib import Path

from app.ai.constants import SAFE_MEDICAL_DISCLAIMER
from app.ai.llama_cpp_provider import LlamaCppProvider
from app.ai.openai_provider import OpenAIProvider
from app.ai.provider import AIProviderError
from app.ai.schemas import AIPlanRequest, PredictionOutputInput
from app.schemas import PredictionInput


def valid_payload() -> dict:
    return {
        "age": 52,
        "gender": "Female",
        "hypertension": "Yes",
        "heart_disease": "No",
        "ever_married": "Yes",
        "work_type": "Private",
        "Residence_type": "Urban",
        "avg_glucose_level": 145.0,
        "bmi": 29.3,
        "smoking_status": "Formerly",
        "systolic_bp": 150,
        "diastolic_bp": 95,
        "alcoholic": "No",
        "family_history": "Yes",
        "sleep_hours": 6,
        "exercise_mins": 15,
        "excess_salt": "Yes",
    }


def _fake_plan_json() -> dict:
    return {
        "summary": "Personalized lifestyle plan generated from risk profile.",
        "top_priorities": [
            {
                "title": "Control blood pressure habits",
                "why": "BP trends are a leading risk driver.",
                "how": ["Reduce sodium", "Track BP daily"],
            },
            {
                "title": "Improve daily movement",
                "why": "More activity supports vascular health.",
                "how": ["Walk 30 minutes", "Use step goal"],
            },
            {
                "title": "Improve sleep quality",
                "why": "Low sleep can worsen metabolic stress.",
                "how": ["Fixed bedtime", "Reduce late screen time"],
            },
            {
                "title": "Food quality focus",
                "why": "Balanced meals improve glucose and weight trends.",
                "how": ["Half plate vegetables", "Limit sugary drinks"],
            },
            {
                "title": "Smoking reduction",
                "why": "Smoking increases vascular risk.",
                "how": ["Set quit date", "Use craving delay strategy"],
            },
        ],
        "diet_plan": {
            "notes": ["Balanced diet", "Low sodium focus"],
            "daily_targets": {
                "water_liters": 2.4,
                "steps": 8000,
                "sleep_hours": 7.5,
            },
            "day_plan": [
                {
                    "meal": "breakfast",
                    "items": [
                        {"name": "Oats", "portion": "1 bowl", "reason": "Fiber support"}
                    ],
                    "avoid": ["Sugary drinks"],
                },
                {
                    "meal": "lunch",
                    "items": [
                        {
                            "name": "Lentil bowl",
                            "portion": "1 plate",
                            "reason": "Protein + fiber",
                        }
                    ],
                    "avoid": ["High-sodium processed foods"],
                },
                {
                    "meal": "dinner",
                    "items": [
                        {
                            "name": "Vegetable + lean protein",
                            "portion": "1 plate",
                            "reason": "Balanced meal",
                        }
                    ],
                    "avoid": ["Deep-fried fast food"],
                },
                {
                    "meal": "snack",
                    "items": [
                        {
                            "name": "Fruit + nuts",
                            "portion": "small",
                            "reason": "Better satiety",
                        }
                    ],
                    "avoid": ["Candy"],
                },
            ],
            "weekly_plan": [
                {"day": "Mon", "focus": "Low sodium", "meals": ["Oats", "Salad", "Soup"]},
                {"day": "Tue", "focus": "Fiber", "meals": ["Fruit", "Dal", "Veg plate"]},
                {"day": "Wed", "focus": "Balanced", "meals": ["Oats", "Rice bowl", "Soup"]},
                {"day": "Thu", "focus": "Hydration", "meals": ["Eggs", "Salad", "Dal"]},
                {"day": "Fri", "focus": "Low sugar", "meals": ["Oats", "Grain plate", "Soup"]},
                {"day": "Sat", "focus": "Home cooked", "meals": ["Fruit", "Veg bowl", "Dal"]},
                {"day": "Sun", "focus": "Weekly review", "meals": ["Oats", "Salad", "Soup"]},
            ],
        },
        "exercise_plan": {
            "safety_notes": [
                "Start gradually",
                "Consult clinician if concerns arise",
            ],
            "weekly_schedule": [
                {"day": "Mon", "workout": "Walk", "duration_min": 25, "intensity": "low"},
                {"day": "Tue", "workout": "Stretching", "duration_min": 20, "intensity": "low"},
                {"day": "Wed", "workout": "Walk", "duration_min": 30, "intensity": "medium"},
                {"day": "Thu", "workout": "Cycling", "duration_min": 25, "intensity": "low"},
                {"day": "Fri", "workout": "Walk", "duration_min": 30, "intensity": "medium"},
                {"day": "Sat", "workout": "Light strength", "duration_min": 25, "intensity": "low"},
                {"day": "Sun", "workout": "Recovery walk", "duration_min": 20, "intensity": "low"},
            ],
            "progression": ["Add 5 minutes per week"],
        },
        "habits": [
            {
                "habit": "Sleep consistency",
                "target": "7-8 hours",
                "tips": ["Fixed bedtime", "No late caffeine"],
            }
        ],
        "red_flags": ["If trend worsens, consult clinician"],
        "disclaimer": SAFE_MEDICAL_DISCLAIMER,
    }


def _configure_env(tmp_path: Path, *, ai_provider: str, api_key: str = "") -> None:
    os.environ["APP_ENV"] = "test"
    os.environ["DB_BACKEND"] = "sqlite"
    os.environ["SQLITE_PATH"] = str(tmp_path / "test.db")
    os.environ["CORS_ORIGINS"] = "*"
    os.environ["SECRET_KEY"] = "test-secret"
    os.environ["AI_PROVIDER"] = ai_provider
    os.environ["OPENAI_API_KEY"] = api_key
    os.environ["OPENAI_MODEL"] = "gpt-4.1-mini"
    os.environ["OPENAI_BASE_URL"] = "https://api.openai.com/v1"
    os.environ["OPENAI_TIMEOUT_SECONDS"] = "20"
    os.environ["LLAMA_CPP_MODEL"] = "local-model"
    os.environ["LLAMA_CPP_BASE_URL"] = "http://127.0.0.1:8080"
    os.environ["LLAMA_CPP_TIMEOUT_SECONDS"] = "60"
    os.environ["AI_RATE_LIMIT_PER_MINUTE"] = "50"


def _sample_plan_request() -> AIPlanRequest:
    return AIPlanRequest(
        user_inputs=PredictionInput.model_validate(valid_payload()),
        prediction_output=PredictionOutputInput(
            risk_probability=0.74,
            risk_label="High",
            top_factors=[
                {
                    "feature": "bmi",
                    "contribution": 0.4,
                    "value": 1.0,
                    "direction": "increase",
                }
            ],
            recommendations=["Increase activity"],
            interpretation="Test output",
            ai_summary="Test",
            disclaimer=SAFE_MEDICAL_DISCLAIMER,
        ),
    )


def _build_client(tmp_path: Path, *, ai_provider: str, api_key: str = ""):
    _configure_env(tmp_path, ai_provider=ai_provider, api_key=api_key)
    from app.db import Base, get_engine
    from app.main import create_app

    app = create_app()
    app.config["TESTING"] = True
    Base.metadata.drop_all(bind=get_engine())
    Base.metadata.create_all(bind=get_engine())
    return app.test_client()


def test_ai_plan_rules_fallback_contains_disclaimer(client):
    predict = client.post("/v1/predict", json=valid_payload())
    assert predict.status_code == 200
    prediction_output = predict.get_json()

    res = client.post(
        "/v1/ai/plan",
        json={
            "user_inputs": valid_payload(),
            "prediction_output": prediction_output,
            "user_preferences": {
                "diet_type": "veg",
                "budget": "medium",
                "activity_level": "light",
                "goal": "reduce_risk",
            },
        },
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["summary"]
    assert 5 <= len(body["top_priorities"]) <= 10
    assert body["diet_plan"]["day_plan"]
    assert body["exercise_plan"]["weekly_schedule"]
    assert body["disclaimer"]


def test_ai_plan_openai_provider_mocked(monkeypatch, tmp_path):
    def fake_post_json(self, payload):
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(_fake_plan_json()),
                    }
                }
            ]
        }

    monkeypatch.setattr(OpenAIProvider, "_post_json", fake_post_json)
    client = _build_client(tmp_path, ai_provider="openai", api_key="test-key")

    with client:
        res = client.post(
            "/v1/ai/plan",
            json={
                "user_inputs": valid_payload(),
                "prediction_output": {
                    "risk_probability": 0.74,
                    "risk_label": "High",
                    "top_factors": [{"feature": "bmi", "contribution": 0.4, "value": 1.0, "direction": "increase"}],
                    "recommendations": ["Increase activity"],
                    "interpretation": "Test output",
                    "ai_summary": "Test",
                    "disclaimer": SAFE_MEDICAL_DISCLAIMER,
                },
            },
        )

    assert res.status_code == 200
    body = res.get_json()
    assert body["summary"] == "Personalized lifestyle plan generated from risk profile."
    assert body["disclaimer"] == SAFE_MEDICAL_DISCLAIMER


def test_ai_chat_includes_disclaimer(client):
    res = client.post(
        "/v1/ai/chat",
        json={
            "message": "What should I prioritize this week?",
            "prediction_output": {
                "risk_probability": 0.55,
                "risk_label": "Elevated",
                "top_factors": [{"feature": "bmi", "contribution": 0.4, "value": 1.0, "direction": "increase"}],
                "recommendations": ["Increase activity"],
                "interpretation": "Estimated risk is elevated",
                "ai_summary": "short summary",
                "disclaimer": SAFE_MEDICAL_DISCLAIMER,
            },
        },
    )
    assert res.status_code == 200
    body = res.get_json()
    assert body["answer"]
    assert body["disclaimer"]


def test_ai_plan_llama_cpp_provider_mocked(monkeypatch, tmp_path):
    def fake_post_json(self, payload):
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(_fake_plan_json()),
                    }
                }
            ]
        }

    monkeypatch.setattr(LlamaCppProvider, "_post_json", fake_post_json)
    client = _build_client(tmp_path, ai_provider="llama_cpp")

    with client:
        res = client.post(
            "/v1/ai/plan",
            json={
                "user_inputs": valid_payload(),
                "prediction_output": {
                    "risk_probability": 0.74,
                    "risk_label": "High",
                    "top_factors": [{"feature": "bmi", "contribution": 0.4, "value": 1.0, "direction": "increase"}],
                    "recommendations": ["Increase activity"],
                    "interpretation": "Test output",
                    "ai_summary": "Test",
                    "disclaimer": SAFE_MEDICAL_DISCLAIMER,
                },
            },
        )

    assert res.status_code == 200
    body = res.get_json()
    assert body["summary"] == "Personalized lifestyle plan generated from risk profile."
    assert body["disclaimer"] == SAFE_MEDICAL_DISCLAIMER


def test_ai_chat_llama_cpp_provider_mocked(monkeypatch, tmp_path):
    def fake_post_json(self, payload):
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(
                            {
                                "answer": "Focus on sleep, blood pressure habits, and daily walking.",
                                "disclaimer": SAFE_MEDICAL_DISCLAIMER,
                            }
                        ),
                    }
                }
            ]
        }

    monkeypatch.setattr(LlamaCppProvider, "_post_json", fake_post_json)
    client = _build_client(tmp_path, ai_provider="llama_cpp")

    with client:
        res = client.post(
            "/v1/ai/chat",
            json={
                "message": "What should I focus on this week?",
                "prediction_output": {
                    "risk_probability": 0.61,
                    "risk_label": "High",
                    "top_factors": [{"feature": "bmi", "contribution": 0.4, "value": 1.0, "direction": "increase"}],
                    "recommendations": ["Increase activity"],
                    "interpretation": "Test output",
                    "ai_summary": "Test",
                    "disclaimer": SAFE_MEDICAL_DISCLAIMER,
                },
            },
        )

    assert res.status_code == 200
    body = res.get_json()
    assert "sleep" in body["answer"].lower()
    assert body["disclaimer"] == SAFE_MEDICAL_DISCLAIMER


def test_llama_cpp_provider_uses_json_schema_and_auth_header(monkeypatch):
    captured_payload = {}

    def fake_post_json(self, payload):
        captured_payload["payload"] = payload
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(_fake_plan_json()),
                    }
                }
            ]
        }

    monkeypatch.setattr(LlamaCppProvider, "_post_json", fake_post_json)
    provider = LlamaCppProvider(
        model="local-model",
        base_url="http://127.0.0.1:8080",
        timeout_seconds=60,
    )

    plan = provider.generate_plan(_sample_plan_request())
    payload = captured_payload["payload"]

    assert plan.summary == "Personalized lifestyle plan generated from risk profile."
    assert payload["response_format"]["type"] == "json_schema"
    assert payload["response_format"]["schema"]["type"] == "object"
    assert payload["response_format"]["schema"]["additionalProperties"] is False
    assert provider._headers()["Authorization"] == "Bearer no-key"


def test_llama_cpp_provider_retries_without_schema_on_400(monkeypatch):
    payload_types = []
    call_count = 0

    def fake_post_json(self, payload):
        nonlocal call_count
        call_count += 1
        payload_types.append(payload["response_format"]["type"])
        if call_count == 1:
            raise AIProviderError(
                "llama.cpp HTTP error 400: response_format json_schema is not supported"
            )
        return {
            "choices": [
                {
                    "message": {
                        "content": json.dumps(_fake_plan_json()),
                    }
                }
            ]
        }

    monkeypatch.setattr(LlamaCppProvider, "_post_json", fake_post_json)
    provider = LlamaCppProvider(
        model="local-model",
        base_url="http://127.0.0.1:8080",
        timeout_seconds=60,
    )

    first = provider.generate_plan(_sample_plan_request())
    assert first.summary == "Personalized lifestyle plan generated from risk profile."
    assert payload_types == ["json_schema", "json_object"]

    payload_types.clear()
    second = provider.generate_plan(_sample_plan_request())
    assert second.summary == "Personalized lifestyle plan generated from risk profile."
    assert payload_types == ["json_object"]
