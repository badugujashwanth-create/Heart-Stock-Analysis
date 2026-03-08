from __future__ import annotations


def valid_payload() -> dict:
    return {
        "age": 56,
        "gender": "Male",
        "hypertension": "Yes",
        "heart_disease": "No",
        "ever_married": "Yes",
        "work_type": "Private",
        "Residence_type": "Urban",
        "avg_glucose_level": 132.5,
        "bmi": 27.2,
        "smoking_status": "Formerly",
        "systolic_bp": 148,
        "diastolic_bp": 92,
        "alcoholic": "No",
        "family_history": "Yes",
        "sleep_hours": 6,
        "exercise_mins": 25,
        "excess_salt": "Yes",
    }


def test_healthz(client):
    res = client.get("/healthz")
    assert res.status_code == 200
    data = res.get_json()
    assert data["status"] == "ok"


def test_model_card(client):
    res = client.get("/v1/model-card")
    assert res.status_code == 200
    data = res.get_json()
    assert data["model_name"]
    assert isinstance(data["features"], list)
    assert data["disclaimer"]


def test_predict_and_history(client):
    first = client.post("/predict", json=valid_payload())
    assert first.status_code == 200
    output = first.get_json()

    assert 0 <= output["risk_probability"] <= 1
    assert output["risk_label"] in {"Low", "Moderate", "Elevated", "High", "Critical"}
    assert len(output["top_factors"]) <= 5
    assert output["assistant_context"]["current_prediction_summary"]["risk_label"] == output["risk_label"]
    assert output["ai_plan_preview"]["summary"]
    assert output["ai_plan_preview"]["disclaimer"]

    history = client.get("/v1/predictions?limit=20")
    assert history.status_code == 200
    rows = history.get_json()["records"]
    assert len(rows) == 1
    assert rows[0]["risk_label"] == output["risk_label"]


def test_assistant_context_includes_last_prediction(client):
    _ = client.post("/v1/predict", json=valid_payload())

    payload = valid_payload()
    payload["exercise_mins"] = 5
    payload["smoking_status"] = "Smokes"
    second = client.post("/v1/predict", json=payload)
    assert second.status_code == 200

    out = second.get_json()
    context = out["assistant_context"]
    assert context["latest_prediction_summary"] is not None


def test_simulate_returns_delta_and_changes(client):
    payload = valid_payload()
    response = client.post(
        "/v1/simulate",
        json={
            "input": payload,
            "overrides": {
                "bmi": 24.0,
                "sleep": 8,
                "exercise": 45,
                "smoking": "never",
            },
        },
    )
    assert response.status_code == 200
    body = response.get_json()

    assert 0 <= body["baseline"]["risk_probability"] <= 1
    assert 0 <= body["simulated"]["risk_probability"] <= 1
    assert isinstance(body["delta"]["risk_probability"], float)
    assert body["delta"]["direction"] in {"higher", "lower", "unchanged"}

    changed_fields = {item["field"] for item in body["changed_factors"]}
    assert {"bmi", "sleep_hours", "exercise_mins", "smoking_status"} <= changed_fields


def test_simulate_rejects_unknown_override(client):
    response = client.post(
        "/v1/simulate",
        json={
            "input": valid_payload(),
            "overrides": {"unknown_field": 100},
        },
    )
    assert response.status_code == 400
    body = response.get_json()
    assert body["error"] == "validation_error"
