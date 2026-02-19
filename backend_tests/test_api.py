import os
import tempfile
import unittest
from pathlib import Path

TEST_DB = Path(tempfile.gettempdir()) / "heartanalysis_test_predictions.db"
os.environ["PREDICTION_DB_PATH"] = str(TEST_DB)
os.environ["DB_BACKEND"] = "sqlite"

from app import app  # noqa: E402


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if TEST_DB.exists():
            TEST_DB.unlink()

    def setUp(self):
        self.client = app.test_client()
        self.valid_payload = {
            "age": 52,
            "gender": "Male",
            "hypertension": "Yes",
            "heart_disease": "No",
            "ever_married": "Yes",
            "work_type": "Private",
            "Residence_type": "Urban",
            "avg_glucose_level": 138.2,
            "bmi": 28.5,
            "smoking_status": "Formerly",
            "systolic_bp": 146,
            "diastolic_bp": 92,
            "alcoholic": "No",
            "family_history": "Yes",
            "sleep_hours": 6,
            "exercise_mins": 20,
            "excess_salt": "Yes",
        }

    def test_healthz(self):
        response = self.client.get("/healthz")
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertEqual(body["status"], "ok")
        self.assertIn("api_version", body)

    def test_model_card(self):
        response = self.client.get("/v1/model-card")
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertEqual(body["model"]["name"], "CardioRisk AI")
        self.assertIn("feature_count", body)

    def test_predict_success(self):
        response = self.client.post("/predict", json=self.valid_payload)
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertIn("stroke_prediction", body)
        self.assertIn("risk_label", body)
        self.assertIn("top_factors", body)
        self.assertIn("recommendations", body)
        self.assertIn("X-Request-ID", response.headers)
        self.assertGreaterEqual(body["stroke_prediction"], 0.0)
        self.assertLessEqual(body["stroke_prediction"], 1.0)

    def test_predict_validation_error(self):
        broken = dict(self.valid_payload)
        broken["age"] = -1
        broken["smoking_status"] = "unknown"
        response = self.client.post("/v1/predict", json=broken)
        self.assertEqual(response.status_code, 400)
        body = response.get_json()
        self.assertEqual(body["error"], "validation_error")
        self.assertTrue(len(body["errors"]) >= 2)

    def test_predictions_are_persisted(self):
        create = self.client.post("/v1/predict", json=self.valid_payload)
        self.assertEqual(create.status_code, 200)

        response = self.client.get("/v1/predictions?limit=5")
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertEqual(body["storage_backend"], "sqlite")
        self.assertGreaterEqual(body["count"], 1)
        self.assertTrue(len(body["records"]) >= 1)
        self.assertIn("input", body["records"][0])
        self.assertIn("result", body["records"][0])


if __name__ == "__main__":
    unittest.main()
