from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas import PredictionInput


class AIUserPreferences(BaseModel):
    model_config = ConfigDict(extra="forbid")

    diet_type: Literal["veg", "nonveg", "vegan", "any"] = "any"
    allergies: list[str] = Field(default_factory=list)
    cuisine: list[str] = Field(default_factory=list)
    budget: Literal["low", "medium", "high"] = "medium"
    activity_level: Literal["sedentary", "light", "moderate", "active"] = "light"
    goal: Literal[
        "reduce_risk",
        "weight_loss",
        "better_sleep",
        "better_fitness",
        "balanced",
    ] = "balanced"


class PredictionFactorInput(BaseModel):
    model_config = ConfigDict(extra="ignore")

    feature: str
    value: float = 0.0
    contribution: float = 0.0
    direction: Literal["increase", "decrease"] = "increase"


class PredictionOutputInput(BaseModel):
    model_config = ConfigDict(extra="ignore")

    risk_probability: float = Field(..., ge=0.0, le=1.0)
    risk_label: str
    top_factors: list[PredictionFactorInput] = Field(default_factory=list)
    recommendations: list[str] = Field(default_factory=list)
    interpretation: str = ""
    ai_summary: str = ""
    disclaimer: str = ""


class PriorityItem(BaseModel):
    title: str
    why: str
    how: list[str] = Field(default_factory=list)


class DietItem(BaseModel):
    name: str
    portion: str
    reason: str


class DietDayMeal(BaseModel):
    meal: Literal["breakfast", "lunch", "dinner", "snack"]
    items: list[DietItem]
    avoid: list[str] = Field(default_factory=list)


class DietWeeklyEntry(BaseModel):
    day: Literal["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    focus: str
    meals: list[str] = Field(default_factory=list)


class DietDailyTargets(BaseModel):
    water_liters: float = Field(..., ge=1.0, le=6.0)
    steps: int = Field(..., ge=3000, le=20000)
    sleep_hours: float = Field(..., ge=6.0, le=10.0)


class DietPlan(BaseModel):
    notes: list[str] = Field(default_factory=list)
    daily_targets: DietDailyTargets
    day_plan: list[DietDayMeal]
    weekly_plan: list[DietWeeklyEntry]


class ExerciseWeeklyEntry(BaseModel):
    day: Literal["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    workout: str
    duration_min: int = Field(..., ge=5, le=180)
    intensity: Literal["low", "medium", "high"]


class ExercisePlan(BaseModel):
    safety_notes: list[str] = Field(default_factory=list)
    weekly_schedule: list[ExerciseWeeklyEntry]
    progression: list[str] = Field(default_factory=list)


class HabitItem(BaseModel):
    habit: str
    target: str
    tips: list[str] = Field(default_factory=list)


class AIPlanResponse(BaseModel):
    summary: str
    top_priorities: list[PriorityItem]
    diet_plan: DietPlan
    exercise_plan: ExercisePlan
    habits: list[HabitItem]
    red_flags: list[str] = Field(default_factory=list)
    disclaimer: str


class AIPlanRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    user_inputs: PredictionInput
    prediction_output: PredictionOutputInput
    user_preferences: AIUserPreferences | None = None


class AIPlanPreview(BaseModel):
    summary: str
    top_priorities: list[dict[str, str]]
    disclaimer: str


class AIChatRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message: str = Field(..., min_length=1, max_length=600)
    user_inputs: PredictionInput | None = None
    prediction_output: PredictionOutputInput | None = None
    ai_plan: AIPlanResponse | None = None


class AIChatResponse(BaseModel):
    answer: str
    disclaimer: str
