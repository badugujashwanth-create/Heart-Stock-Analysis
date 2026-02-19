import math
import os
from typing import Any

from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)
CORS(app)


def _to_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        text = value.strip().replace("%", "")
        try:
            return float(text)
        except ValueError:
            return default
    return default


def _to_int(value: Any, default: int = 0) -> int:
    return int(round(_to_float(value, float(default))))


def _yes(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value > 0
    if isinstance(value, str):
        return value.strip().lower() in {"yes", "y", "true", "t", "1"}
    return False


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _risk_bucket(probability: float) -> str:
    if probability >= 0.75:
        return "Very High Risk"
    if probability >= 0.50:
        return "High Risk"
    if probability >= 0.25:
        return "Moderate Risk"
    return "Low Risk"


def _interpretation(probability: float) -> str:
    if probability >= 0.75:
        return "Multiple high-impact risk factors detected. Consult a clinician soon."
    if probability >= 0.50:
        return "Elevated risk profile. Lifestyle changes and medical review are advised."
    if probability >= 0.25:
        return "Some risk factors are present. Preventive steps can reduce risk."
    return "Risk is currently lower, but healthy habits should be maintained."


def _predict_probability(payload: dict[str, Any]) -> float:
    age = _to_int(payload.get("age"))
    systolic_bp = _to_int(payload.get("systolic_bp"))
    diastolic_bp = _to_int(payload.get("diastolic_bp"))
    bmi = _to_float(payload.get("bmi"))
    glucose = _to_float(payload.get("avg_glucose_level"))
    sleep_hours = _to_float(payload.get("sleep_hours"))
    exercise_mins = _to_float(payload.get("exercise_mins"))

    smoking_status = str(payload.get("smoking_status", "")).strip().lower()
    work_type = str(payload.get("work_type", "")).strip().lower()
    residence = str(payload.get("Residence_type", "")).strip().lower()

    score = 0.03  # baseline risk

    if age > 20:
        score += min((age - 20) * 0.0035, 0.25)

    if _yes(payload.get("hypertension")):
        score += 0.14
    if _yes(payload.get("heart_disease")):
        score += 0.16
    if _yes(payload.get("family_history")):
        score += 0.10
    if _yes(payload.get("alcoholic")):
        score += 0.05
    if _yes(payload.get("excess_salt")):
        score += 0.07

    if systolic_bp >= 180:
        score += 0.18
    elif systolic_bp >= 160:
        score += 0.14
    elif systolic_bp >= 140:
        score += 0.10
    elif systolic_bp >= 130:
        score += 0.05

    if diastolic_bp >= 110:
        score += 0.12
    elif diastolic_bp >= 100:
        score += 0.09
    elif diastolic_bp >= 90:
        score += 0.06

    if bmi >= 35:
        score += 0.12
    elif bmi >= 30:
        score += 0.08
    elif bmi >= 25:
        score += 0.04

    if glucose >= 200:
        score += 0.20
    elif glucose >= 140:
        score += 0.12
    elif glucose >= 100:
        score += 0.05

    if smoking_status == "smokes":
        score += 0.11
    elif smoking_status == "formerly":
        score += 0.05

    if sleep_hours < 6:
        score += 0.06
    elif sleep_hours > 9:
        score += 0.03
    elif 7 <= sleep_hours <= 8:
        score -= 0.02

    if exercise_mins < 15:
        score += 0.08
    elif exercise_mins < 30:
        score += 0.04
    elif exercise_mins >= 60:
        score -= 0.03

    if work_type == "children":
        score -= 0.03
    if residence == "urban":
        score += 0.01

    score = _clamp(score, -0.2, 1.3)
    probability = 1.0 / (1.0 + math.exp(-((score - 0.35) * 4.0)))
    return _clamp(probability, 0.01, 0.99)


@app.get("/")
def root():
    return jsonify(
        {
            "service": "heart-stroke-api",
            "status": "ok",
            "endpoints": ["/predict", "/healthz"],
        }
    )


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.post("/predict")
def predict():
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "Request body must be a JSON object."}), 400

    probability = _predict_probability(payload)
    stroke_probability = round(probability * 100.0, 2)
    no_stroke_probability = round(100.0 - stroke_probability, 2)

    return jsonify(
        {
            "stroke_prediction": round(probability, 4),
            "stroke_probability": stroke_probability,
            "no_stroke_probability": no_stroke_probability,
            "risk_label": _risk_bucket(probability),
            "interpretation": _interpretation(probability),
        }
    )


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
