from __future__ import annotations

from collections.abc import Iterable

from .constants import SAFE_MEDICAL_DISCLAIMER
from .provider import AIProvider
from .schemas import (
    AIChatRequest,
    AIChatResponse,
    AIPlanRequest,
    AIPlanResponse,
    AIUserPreferences,
    DietDailyTargets,
    DietDayMeal,
    DietItem,
    DietPlan,
    DietWeeklyEntry,
    ExercisePlan,
    ExerciseWeeklyEntry,
    HabitItem,
    PredictionOutputInput,
    PriorityItem,
)

DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


class RulesAIProvider(AIProvider):
    def generate_plan(self, request_data: AIPlanRequest) -> AIPlanResponse:
        user = request_data.user_inputs
        prediction = request_data.prediction_output
        prefs = request_data.user_preferences or AIUserPreferences()

        top_priorities = self._build_top_priorities(prediction)
        diet_plan = self._build_diet_plan(user=user, prediction=prediction, prefs=prefs)
        exercise_plan = self._build_exercise_plan(user=user, prefs=prefs)
        habits = self._build_habits(user=user, prediction=prediction)
        red_flags = self._build_red_flags(prediction)

        summary = (
            f"Educational profile band is {prediction.risk_label} "
            f"({prediction.risk_probability * 100:.1f}/100). "
            "This demonstration organizes general lifestyle ideas around the configured factors."
        )

        return AIPlanResponse(
            summary=summary,
            top_priorities=top_priorities,
            diet_plan=diet_plan,
            exercise_plan=exercise_plan,
            habits=habits,
            red_flags=red_flags,
            disclaimer=SAFE_MEDICAL_DISCLAIMER,
        )

    def chat(self, request_data: AIChatRequest) -> AIChatResponse:
        question = request_data.message.strip()
        normalized = question.lower()

        plan = request_data.ai_plan
        prediction = request_data.prediction_output

        lines: list[str] = []
        matched_topic = False
        if prediction is not None:
            lines.append(
                f"Current educational profile: {prediction.risk_label} "
                f"({prediction.risk_probability * 100:.1f}/100)."
            )

        if "diet" in normalized or "food" in normalized:
            matched_topic = True
            if plan is not None:
                lines.append("Diet focus from your plan:")
                for note in plan.diet_plan.notes[:3]:
                    lines.append(f"- {note}")
            else:
                lines.append(
                    "- Build meals around vegetables, whole grains, and lean protein."
                )
                lines.append("- Reduce sugary drinks and high-sodium packaged foods.")

        if "exercise" in normalized or "workout" in normalized:
            matched_topic = True
            if plan is not None and plan.exercise_plan.weekly_schedule:
                lines.append("Exercise focus from your weekly schedule:")
                for row in plan.exercise_plan.weekly_schedule[:3]:
                    lines.append(
                        f"- {row.day}: {row.workout} ({row.duration_min} min, {row.intensity})"
                    )
            else:
                lines.append("- Aim for at least 30 minutes of moderate activity most days.")

        if "sleep" in normalized:
            matched_topic = True
            lines.append("- Keep a consistent sleep schedule and target 7-8 hours nightly.")

        if "smok" in normalized:
            matched_topic = True
            lines.append("- Set a quit date and use craving-delay techniques to reduce smoking.")

        if not matched_topic:
            lines.append("Most important actions now:")
            if plan is not None:
                for item in plan.top_priorities[:3]:
                    lines.append(f"- {item.title}: {item.why}")
            elif prediction is not None and prediction.recommendations:
                for recommendation in prediction.recommendations[:3]:
                    lines.append(f"- {recommendation}")
            else:
                lines.append("- Follow your top recommendations consistently this week.")
                lines.append("- Maintain balanced meals, regular activity, and sleep routine.")

        lines.append("For personalized medical decisions, consult a qualified clinician.")
        lines.append(SAFE_MEDICAL_DISCLAIMER)

        return AIChatResponse(
            answer="\n".join(lines),
            disclaimer=SAFE_MEDICAL_DISCLAIMER,
        )

    def _build_top_priorities(
        self,
        prediction: PredictionOutputInput,
    ) -> list[PriorityItem]:
        priorities: list[PriorityItem] = []
        seen: set[str] = set()

        if prediction.risk_label in {"High", "Very high"}:
            priorities.append(
                PriorityItem(
                    title="Discuss the inputs with a clinician",
                    why="A high educational band must not be interpreted as personal medical risk.",
                    how=[
                        "If these were real inputs, ask a clinician how to interpret them.",
                        "Do not make treatment decisions from this demonstration.",
                    ],
                )
            )
            seen.add("clinical")

        for feature in (factor.feature for factor in prediction.top_factors):
            mapped = self._priority_for_feature(feature)
            if mapped is None:
                continue
            key = mapped.title.lower()
            if key in seen:
                continue
            priorities.append(mapped)
            seen.add(key)

        fallbacks = [
            PriorityItem(
                title="Improve meal quality",
                why="Balanced nutrition supports blood pressure, glucose, and weight control.",
                how=[
                    "Use half-plate vegetables for lunch and dinner.",
                    "Reduce processed salty foods and sugary beverages.",
                ],
            ),
            PriorityItem(
                title="Build consistent activity",
                why="This demo assigns more activity a lower heuristic contribution.",
                how=[
                    "Target at least 150 minutes of moderate activity weekly.",
                    "Break activity into short sessions if time is limited.",
                ],
            ),
            PriorityItem(
                title="Protect sleep routine",
                why="Sleep quality influences blood pressure and metabolic recovery.",
                how=[
                    "Keep a fixed sleep/wake schedule.",
                    "Avoid screens and heavy meals close to bedtime.",
                ],
            ),
            PriorityItem(
                title="Track progress weekly",
                why="Simple tracking improves adherence and reveals which habits work.",
                how=[
                    "Log sleep, steps, and smoking status daily.",
                    "Review weekly trend and adjust one habit at a time.",
                ],
            ),
        ]

        for item in fallbacks:
            if len(priorities) >= 7:
                break
            key = item.title.lower()
            if key in seen:
                continue
            priorities.append(item)
            seen.add(key)

        return priorities[:7]

    def _priority_for_feature(self, feature: str) -> PriorityItem | None:
        feature = feature.lower()
        if feature in {"systolic_bp", "diastolic_bp", "hypertension"}:
            return PriorityItem(
                title="Stabilize blood pressure habits",
                why="Blood pressure is a prominent input in this configured educational heuristic.",
                how=[
                    "Reduce sodium from packaged and restaurant foods.",
                    "Track BP at consistent times and review trends weekly.",
                ],
            )
        if feature in {"glucose"}:
            return PriorityItem(
                title="Improve glucose-friendly eating",
                why="Glucose is one configured input in this educational heuristic.",
                how=[
                    "Pair carbs with protein/fiber at meals.",
                    "Limit sweetened drinks and late-night sugary snacks.",
                ],
            )
        if feature in {"smoking"}:
            return PriorityItem(
                title="Move toward smoke-free routine",
                why="Smoking status has a positive weight in this educational heuristic.",
                how=[
                    "Set a quit or reduction date this week.",
                    "Use a craving plan: delay, hydrate, and short walk.",
                ],
            )
        if feature in {"bmi"}:
            return PriorityItem(
                title="Support healthy weight trajectory",
                why="BMI is one configured input in this educational heuristic.",
                how=[
                    "Create a modest calorie deficit with whole foods.",
                    "Combine food quality goals with regular movement.",
                ],
            )
        if feature in {"exercise"}:
            return PriorityItem(
                title="Increase weekly physical activity",
                why="Activity has a negative weight in this educational heuristic.",
                how=[
                    "Start with manageable sessions and progress gradually.",
                    "Aim for activity on at least 5 days per week.",
                ],
            )
        if feature in {"sleep"}:
            return PriorityItem(
                title="Improve sleep consistency",
                why="Sleep duration changes the configured educational score.",
                how=[
                    "Target 7-8 hours with fixed sleep/wake timing.",
                    "Avoid caffeine late in the day and reduce screen time at night.",
                ],
            )
        if feature in {"salt"}:
            return PriorityItem(
                title="Lower sodium exposure",
                why="Excess salt has a positive weight in this educational heuristic.",
                how=[
                    "Cook more meals at home with herbs instead of salt-heavy sauces.",
                    "Read labels and choose lower-sodium options.",
                ],
            )
        return None

    def _build_diet_plan(
        self,
        *,
        user,
        prediction: PredictionOutputInput,
        prefs: AIUserPreferences,
    ) -> DietPlan:
        high_glucose = any(f.feature.lower() == "glucose" for f in prediction.top_factors)
        high_bp = any(
            f.feature.lower() in {"systolic_bp", "diastolic_bp", "hypertension"}
            for f in prediction.top_factors
        )
        high_bmi = any(f.feature.lower() == "bmi" for f in prediction.top_factors)

        notes = [
            f"Diet style selected: {prefs.diet_type}.",
            f"Budget preference: {prefs.budget}.",
            "Prioritize balanced meals with vegetables, fiber, and lean protein.",
        ]
        if prefs.cuisine:
            notes.append(f"Preferred cuisines considered: {', '.join(prefs.cuisine)}.")
        if prefs.allergies:
            notes.append(f"Allergy-aware substitutions applied: {', '.join(prefs.allergies)}.")

        water_liters = 2.2
        if high_bmi:
            water_liters += 0.2
        if prefs.activity_level in {"moderate", "active"}:
            water_liters += 0.2
        steps = {
            "sedentary": 6000,
            "light": 7500,
            "moderate": 9000,
            "active": 11000,
        }.get(prefs.activity_level, 7500)
        sleep_hours = 8.0 if user.sleep_hours < 7 else 7.5

        daily_targets = DietDailyTargets(
            water_liters=round(water_liters, 1),
            steps=steps,
            sleep_hours=sleep_hours,
        )

        avoid_items = self._collect_avoid_items(
            allergies=prefs.allergies,
            high_glucose=high_glucose,
            high_bp=high_bp,
        )

        proteins = self._protein_options(prefs.diet_type)
        carbs = self._carb_options(prefs.budget)
        veggie = "mixed vegetables"
        fruit = "seasonal fruit"

        day_plan = [
            DietDayMeal(
                meal="breakfast",
                items=[
                    DietItem(
                        name=f"{carbs[0]} bowl",
                        portion="1 medium bowl",
                        reason="Steady energy and fiber support.",
                    ),
                    DietItem(
                        name=proteins[0],
                        portion="1 serving",
                        reason="Adds protein for better satiety and glucose balance.",
                    ),
                ],
                avoid=avoid_items,
            ),
            DietDayMeal(
                meal="lunch",
                items=[
                    DietItem(
                        name=proteins[1],
                        portion="1 palm-sized serving",
                        reason="Lean protein supports recovery and stable appetite.",
                    ),
                    DietItem(
                        name=veggie,
                        portion="half plate",
                        reason="High volume and micronutrient support.",
                    ),
                    DietItem(
                        name=carbs[1],
                        portion="1 fist-sized serving",
                        reason="Controlled complex carbohydrate source.",
                    ),
                ],
                avoid=avoid_items,
            ),
            DietDayMeal(
                meal="dinner",
                items=[
                    DietItem(
                        name="vegetable soup + protein plate",
                        portion="1 bowl + 1 serving protein",
                        reason="Lighter, lower-sodium evening meal.",
                    ),
                    DietItem(
                        name=carbs[2],
                        portion="small serving",
                        reason="Moderate carb intake supports overnight glucose control.",
                    ),
                ],
                avoid=avoid_items,
            ),
            DietDayMeal(
                meal="snack",
                items=[
                    DietItem(
                        name=f"{fruit} + nuts",
                        portion="1 fruit + small handful nuts",
                        reason="Fiber and healthy fats reduce unhealthy snacking.",
                    ),
                ],
                avoid=avoid_items,
            ),
        ]

        weekly_plan = [
            DietWeeklyEntry(
                day=day,
                focus=self._weekly_focus(day, prefs.goal),
                meals=self._weekly_meals(day, prefs.diet_type),
            )
            for day in DAY_NAMES
        ]

        return DietPlan(
            notes=notes,
            daily_targets=daily_targets,
            day_plan=day_plan,
            weekly_plan=weekly_plan,
        )

    def _build_exercise_plan(self, *, user, prefs: AIUserPreferences) -> ExercisePlan:
        beginner = prefs.activity_level in {"sedentary", "light"} or user.exercise_mins < 25

        if beginner:
            template = [
                ("Mon", "Brisk walking", 20, "low"),
                ("Tue", "Mobility and stretching", 15, "low"),
                ("Wed", "Walk + light bodyweight", 25, "medium"),
                ("Thu", "Easy cycling or walking", 20, "low"),
                ("Fri", "Walk intervals", 25, "medium"),
                ("Sat", "Recreational activity", 30, "low"),
                ("Sun", "Recovery walk and stretching", 20, "low"),
            ]
            progression = [
                "Increase total activity time by 5 minutes every 1-2 weeks.",
                "Keep effort moderate and focus on consistency first.",
            ]
        else:
            template = [
                ("Mon", "Brisk walk or jog", 35, "medium"),
                ("Tue", "Strength training (full body)", 30, "medium"),
                ("Wed", "Cycling or fast walk", 35, "medium"),
                ("Thu", "Mobility + core", 25, "low"),
                ("Fri", "Interval cardio", 30, "medium"),
                ("Sat", "Strength + conditioning", 40, "medium"),
                ("Sun", "Recovery walk", 30, "low"),
            ]
            progression = [
                "Add 5-10% volume every 2 weeks if recovery is good.",
                "Keep at least one low-intensity recovery day per week.",
            ]

        weekly_schedule = [
            ExerciseWeeklyEntry(
                day=day,
                workout=workout,
                duration_min=duration,
                intensity=intensity,
            )
            for (day, workout, duration, intensity) in template
        ]

        safety_notes = [
            "Start gradually and stop if you feel unwell.",
            "Use comfortable pace and proper hydration.",
            "Consult a clinician before major exercise changes if you have health concerns.",
        ]

        return ExercisePlan(
            safety_notes=safety_notes,
            weekly_schedule=weekly_schedule,
            progression=progression,
        )

    def _build_habits(self, *, user, prediction: PredictionOutputInput) -> list[HabitItem]:
        habits = [
            HabitItem(
                habit="Sleep routine",
                target="7-8 hours nightly",
                tips=[
                    "Set fixed bedtime and wake-up time.",
                    "Keep screens off 45 minutes before bed.",
                ],
            ),
            HabitItem(
                habit="Daily movement",
                target="At least 30 minutes activity",
                tips=[
                    "Use two 15-minute sessions if schedule is busy.",
                    "Add short walks after meals.",
                ],
            ),
            HabitItem(
                habit="Meal structure",
                target="Half-plate vegetables at lunch/dinner",
                tips=[
                    "Prep vegetables in advance.",
                    "Use smaller plates for portion control.",
                ],
            ),
        ]

        if user.smoking_status.lower() != "never":
            habits.append(
                HabitItem(
                    habit="Smoking reduction",
                    target="Move toward smoke-free days",
                    tips=[
                        "Track cravings and delay each urge by 5 minutes.",
                        "Replace smoking triggers with walk/water breathing routine.",
                    ],
                )
            )

        if prediction.risk_label in {"High", "Very high"}:
            habits.append(
                HabitItem(
                    habit="Interpretation checkpoint",
                    target="Do not treat the score as medical advice",
                    tips=[
                        "If inputs are real, discuss them with a qualified clinician.",
                        "Use the demo only to inspect configured score behavior.",
                    ],
                )
            )

        return habits[:6]

    def _build_red_flags(self, prediction: PredictionOutputInput) -> list[str]:
        flags = [
            "Do not use score changes to assess symptoms or medical urgency.",
            "For real symptoms or personal medical questions, seek qualified care.",
        ]
        if prediction.risk_label in {"High", "Very high"}:
            flags.insert(
                0,
                "High educational band: do not interpret this as a clinical classification.",
            )
        return flags

    def _collect_avoid_items(
        self,
        *,
        allergies: list[str],
        high_glucose: bool,
        high_bp: bool,
    ) -> list[str]:
        avoid = set(item.strip() for item in allergies if item.strip())
        if high_glucose:
            avoid.update({"sugary drinks", "high-sugar desserts"})
        if high_bp:
            avoid.update({"high-sodium packaged foods", "frequent deep-fried fast food"})
        return sorted(avoid) or ["highly processed snacks"]

    def _protein_options(self, diet_type: str) -> list[str]:
        if diet_type == "vegan":
            return ["tofu scramble", "lentil curry", "chickpea salad"]
        if diet_type == "veg":
            return ["greek yogurt", "paneer/tofu mix", "lentil dal"]
        if diet_type == "nonveg":
            return ["boiled eggs", "grilled chicken/fish", "lentil + chicken soup"]
        return ["eggs or tofu", "lean protein bowl", "beans/lentil mix"]

    def _carb_options(self, budget: str) -> list[str]:
        if budget == "low":
            return ["oats", "brown rice", "whole wheat roti"]
        if budget == "high":
            return ["quinoa", "millet", "whole grain wrap"]
        return ["oats", "brown rice", "whole wheat roti"]

    def _weekly_focus(self, day: str, goal: str) -> str:
        by_day = {
            "Mon": "Low-sodium meal prep",
            "Tue": "Fiber-rich meals",
            "Wed": "Balanced protein and carbs",
            "Thu": "Hydration and portion control",
            "Fri": "Low-sugar dinner focus",
            "Sat": "Home-cooked whole foods",
            "Sun": "Weekly review and grocery planning",
        }
        if goal == "better_sleep":
            by_day["Thu"] = "Evening light meals and sleep-friendly routine"
        if goal == "weight_loss":
            by_day["Fri"] = "Calorie-aware meal structure"
        if goal == "better_fitness":
            by_day["Tue"] = "Higher protein recovery meals"
        return by_day[day]

    def _weekly_meals(self, day: str, diet_type: str) -> list[str]:
        prefix = "plant-forward" if diet_type in {"veg", "vegan"} else "balanced"
        meals_map: dict[str, Iterable[str]] = {
            "Mon": [f"{prefix} breakfast bowl", "lean lunch plate", "light dinner soup"],
            "Tue": [f"{prefix} smoothie + nuts", "fiber lunch", "grilled dinner plate"],
            "Wed": ["protein breakfast", "balanced grain lunch", "vegetable-rich dinner"],
            "Thu": ["oats + fruit", "low-sodium lunch", "early light dinner"],
            "Fri": ["yogurt or tofu bowl", "mixed salad lunch", "low-sugar dinner"],
            "Sat": ["home-cooked breakfast", "family-style healthy lunch", "portion-aware dinner"],
            "Sun": ["simple breakfast", "meal prep lunch", "recovery dinner"],
        }
        return list(meals_map[day])
