from __future__ import annotations


def test_validation_error_returns_details(client):
    bad_payload = {
        "age": -1,
        "gender": "Unknown",
    }
    res = client.post("/v1/predict", json=bad_payload)
    assert res.status_code == 400
    body = res.get_json()
    assert body["error"] == "validation_error"
    assert isinstance(body["details"], list)
    assert len(body["details"]) > 0


def test_limit_validation(client):
    res = client.get("/v1/predictions?limit=200")
    assert res.status_code == 400
    body = res.get_json()
    assert body["error"] == "validation_error"
