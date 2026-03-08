from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

YES_NO_FIELDS = (
    "hypertension",
    "heart_disease",
    "ever_married",
    "alcoholic",
    "family_history",
    "excess_salt",
)


class PredictionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    age: int = Field(..., ge=1, le=120)
    gender: Literal["Male", "Female", "Other"]

    hypertension: bool
    heart_disease: bool
    ever_married: bool

    work_type: Literal["Private", "Self-employed", "Govt", "Children", "Never worked"]
    Residence_type: Literal["Urban", "Rural"]

    avg_glucose_level: float = Field(..., ge=20, le=600)
    bmi: float = Field(..., ge=10, le=80)

    smoking_status: Literal["Never", "Formerly", "Smokes"]

    systolic_bp: int = Field(..., ge=60, le=260)
    diastolic_bp: int = Field(..., ge=30, le=180)

    alcoholic: bool
    family_history: bool
    sleep_hours: int = Field(..., ge=0, le=24)
    exercise_mins: int = Field(..., ge=0, le=600)
    excess_salt: bool

    @field_validator(*YES_NO_FIELDS, mode="before")
    @classmethod
    def yes_no_to_bool(cls, value):
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return bool(value)
        if isinstance(value, str):
            text = value.strip().lower()
            if text in {"yes", "y", "true", "1"}:
                return True
            if text in {"no", "n", "false", "0"}:
                return False
        raise ValueError("must be Yes or No")

    @field_validator("smoking_status", mode="before")
    @classmethod
    def normalize_smoking(cls, value):
        if not isinstance(value, str):
            raise ValueError("must be Never, Formerly, or Smokes")
        text = value.strip().lower()
        mapping = {
            "never smoked": "Never",
            "never": "Never",
            "formerly smoked": "Formerly",
            "formerly": "Formerly",
            "smokes": "Smokes",
            "smoker": "Smokes",
        }
        if text not in mapping:
            raise ValueError("must be Never, Formerly, or Smokes")
        return mapping[text]


class PredictionFactor(BaseModel):
    feature: str
    value: float
    contribution: float
    direction: Literal["increase", "decrease"]


class PredictionOutput(BaseModel):
    risk_probability: float
    risk_label: Literal["Low", "Moderate", "Elevated", "High", "Critical"]
    top_factors: list[PredictionFactor]
    recommendations: list[str]
    interpretation: str
    ai_summary: str
    disclaimer: str
    assistant_context: dict


def pydantic_error_payload(exc: ValidationError) -> dict:
    details = []
    for err in exc.errors():
        loc = ".".join(str(part) for part in err["loc"])
        details.append({"field": loc, "message": err["msg"]})
    return {"error": "validation_error", "details": details}
