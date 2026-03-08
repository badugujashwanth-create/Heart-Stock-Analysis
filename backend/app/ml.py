from __future__ import annotations

import math
from typing import Any

from .schemas import PredictionInput

DISCLAIMER = (
    "This tool provides an AI-assisted risk estimate for educational support only and "
    "does not replace clinical diagnosis or emergency medical care."
)

FEATURE_DESCRIPTIONS = {
    "age": "Age in years",
    "hypertension": "History of hypertension",
    "heart_disease": "History of heart disease",
    "family_history": "Family history of stroke",
    "systolic_bp": "Systolic blood pressure",
    "diastolic_bp": "Diastolic blood pressure",
    "glucose": "Average glucose level",
    "bmi": "Body mass index",
    "smoking": "Smoking status",
    "exercise": "Daily exercise minutes",
    "sleep": "Daily sleep hours",
    "alcohol": "Alcohol consumption",
    "salt": "Excess salt consumption",
}

FEATURE_WEIGHTS = {
    "age": 1.15,
    "hypertension": 1.05,
    "heart_disease": 1.20,
    "family_history": 0.72,
    "systolic_bp": 0.78,
    "diastolic_bp": 0.48,
    "glucose": 0.95,
    "bmi": 0.42,
    "smoking": 0.90,
    "exercise": -0.45,
    "sleep": -0.22,
    "alcohol": 0.30,
    "salt": 0.40,
}
BIAS = -2.10

MODEL_CARD = {
    "model_name": "StrokeRisk Logistic Heuristic",
    "model_version": "0.2.0",
    "framework": "hand-coded logistic scoring",
    "features": [
        {"name": key, "description": value}
        for key, value in FEATURE_DESCRIPTIONS.items()
    ],
    "limitations": [
        "Not trained on your local hospital cohort.",
        "Does not include imaging, ECG, labs beyond provided inputs.",
        "Cannot diagnose acute stroke; emergency care is required for symptoms.",
    ],
    "intended_use": "Preventive risk awareness and triage support.",
    "disclaimer": DISCLAIMER,
}


def model_card() -> dict[str, Any]:
    return MODEL_CARD


def _sigmoid(value: float) -> float:
    if value >= 0:
        z = math.exp(-value)
        return 1 / (1 + z)
    z = math.exp(value)
    return z / (1 + z)


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _smoking_numeric(status: str) -> float:
    normalized = status.strip().lower()
    if normalized == "smokes":
        return 1.0
    if normalized == "formerly":
        return 0.5
    return 0.0


def _exercise_score(minutes: int) -> float:
    # Lower risk when exercise increases; normalized around 30 mins/day.
    return _clamp((30 - minutes) / 60.0, -1.0, 1.5)


def _sleep_score(hours: int) -> float:
    # 7-8h tends to be protective; short/long sleep adds risk.
    if 7 <= hours <= 8:
        return -0.6
    if hours < 6:
        return 0.8
    if hours > 9:
        return 0.4
    return 0.0


def _feature_values(data: PredictionInput) -> dict[str, float]:
    return {
        "age": data.age / 100.0,
        "hypertension": 1.0 if data.hypertension else 0.0,
        "heart_disease": 1.0 if data.heart_disease else 0.0,
        "family_history": 1.0 if data.family_history else 0.0,
        "systolic_bp": (data.systolic_bp - 120) / 70.0,
        "diastolic_bp": (data.diastolic_bp - 80) / 40.0,
        "glucose": (data.avg_glucose_level - 100) / 120.0,
        "bmi": (data.bmi - 24) / 18.0,
        "smoking": _smoking_numeric(data.smoking_status),
        "exercise": _exercise_score(data.exercise_mins),
        "sleep": _sleep_score(data.sleep_hours),
        "alcohol": 1.0 if data.alcoholic else 0.0,
        "salt": 1.0 if data.excess_salt else 0.0,
    }


def _risk_label(probability: float) -> str:
    if probability < 0.20:
        return "Low"
    if probability < 0.40:
        return "Moderate"
    if probability < 0.60:
        return "Elevated"
    if probability < 0.80:
        return "High"
    return "Critical"


def _recommendations(data: PredictionInput, label: str, top_factors: list[dict[str, Any]]) -> list[str]:
    recs: list[str] = []
    factor_keys = {item["feature"] for item in top_factors}

    if "systolic_bp" in factor_keys or "diastolic_bp" in factor_keys or data.hypertension:
        recs.append("Track blood pressure daily and discuss BP targets with your clinician.")
    if "glucose" in factor_keys:
        recs.append("Monitor glucose trends and reduce high-glycemic food intake.")
    if "smoking" in factor_keys and data.smoking_status != "Never":
        recs.append("Start a smoking cessation plan with structured support.")
    if data.exercise_mins < 30:
        recs.append("Increase activity toward at least 150 minutes/week of moderate exercise.")
    if data.excess_salt:
        recs.append("Reduce sodium intake and avoid highly processed foods.")
    if data.sleep_hours < 6:
        recs.append("Aim for at least 7 hours of sleep to improve cardiometabolic recovery.")

    if label in {"High", "Critical"}:
        recs.append("Book a clinical review soon for targeted prevention planning.")

    if not recs:
        recs.append("Maintain current healthy habits and continue routine preventive checkups.")

    return recs[:6]


def _interpretation(label: str, probability: float) -> str:
    pct = probability * 100
    if label == "Critical":
        return f"Estimated risk is very high at {pct:.1f}%. Multiple major factors are elevated and urgent clinical follow-up is advised."
    if label == "High":
        return f"Estimated risk is high at {pct:.1f}%. Several meaningful risk factors are present and should be actively managed."
    if label == "Elevated":
        return f"Estimated risk is elevated at {pct:.1f}%. Targeted lifestyle and medical follow-up can reduce future risk."
    if label == "Moderate":
        return f"Estimated risk is moderate at {pct:.1f}%. Prevention-focused improvements can move this profile lower."
    return f"Estimated risk is low at {pct:.1f}%. Continue healthy habits and periodic checkups."


def _ai_summary(label: str, probability: float, top_factors: list[dict[str, Any]]) -> str:
    factor_text = ", ".join(item["feature"] for item in top_factors[:3]) or "overall profile"
    return (
        f"The model estimates a {probability * 100:.1f}% stroke risk ({label}). "
        f"The most influential drivers were {factor_text}. "
        "Use this as a preventive guide and confirm decisions with a healthcare professional."
    )


def run_model(data: PredictionInput) -> dict[str, Any]:
    values = _feature_values(data)
    contributions = {
        key: FEATURE_WEIGHTS[key] * value
        for key, value in values.items()
    }
    logit = BIAS + sum(contributions.values())
    probability = _clamp(_sigmoid(logit), 0.01, 0.99)
    label = _risk_label(probability)

    top_factors = sorted(
        [
            {
                "feature": key,
                "value": round(values[key], 4),
                "contribution": round(contributions[key], 4),
                "direction": "increase" if contributions[key] >= 0 else "decrease",
            }
            for key in values
        ],
        key=lambda item: abs(item["contribution"]),
        reverse=True,
    )[:5]

    recommendations = _recommendations(data, label, top_factors)
    interpretation = _interpretation(label, probability)
    ai_summary = _ai_summary(label, probability, top_factors)

    return {
        "risk_probability": round(probability, 4),
        "risk_label": label,
        "top_factors": top_factors,
        "recommendations": recommendations,
        "interpretation": interpretation,
        "ai_summary": ai_summary,
        "disclaimer": DISCLAIMER,
    }
