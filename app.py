import json
import logging
import math
import os
import sqlite3
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from flask import Flask, g, jsonify, request
from flask_cors import CORS

try:
    import pymysql
    from pymysql.cursors import DictCursor
except Exception:  # pragma: no cover - optional dependency at runtime
    pymysql = None
    DictCursor = None

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO, format='%(message)s')
logger = logging.getLogger('heart-stroke-api')

API_VERSION = '1.1.0'
MODEL_META = {
    'name': 'CardioRisk AI',
    'version': '2.0.0',
    'type': 'interpretable-logistic-model',
}
DISCLAIMER = (
    'This output is an AI-assisted risk estimate for educational use and is not a clinical diagnosis. '
    'Always consult a licensed clinician for medical decisions.'
)
DB_PATH = os.getenv('PREDICTION_DB_PATH', 'data/predictions.db')
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = int(os.getenv('DB_PORT', '3306'))
DB_USER = os.getenv('DB_USER', 'root')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')
DB_NAME = os.getenv('DB_NAME', 'heartanalysis')
DB_BACKEND = os.getenv(
    'DB_BACKEND',
    'mysql' if os.getenv('DB_HOST') and os.getenv('DB_USER') else 'sqlite',
).lower()
if DB_BACKEND not in {'sqlite', 'mysql'}:
    DB_BACKEND = 'sqlite'


@dataclass
class ValidationError:
    field: str
    message: str


YES_VALUES = {'yes', 'y', 'true', 't', '1'}
NO_VALUES = {'no', 'n', 'false', 'f', '0'}
GENDER_VALUES = {'male', 'female', 'other'}
WORK_TYPE_VALUES = {'private', 'self-employed', 'govt', 'children', 'never worked'}
RESIDENCE_VALUES = {'urban', 'rural'}
SMOKING_VALUES = {'never', 'formerly', 'smokes'}


def _ensure_db_dir() -> None:
    db_dir = Path(DB_PATH).parent
    if str(db_dir) and str(db_dir) != '.':
        db_dir.mkdir(parents=True, exist_ok=True)


def _get_db() -> Any:
    conn = getattr(g, '_db_conn', None)
    if conn is None:
        _init_db()
        if DB_BACKEND == 'mysql':
            if pymysql is None:
                raise RuntimeError('PyMySQL is required for MySQL backend.')
            conn = pymysql.connect(
                host=DB_HOST,
                port=DB_PORT,
                user=DB_USER,
                password=DB_PASSWORD,
                database=DB_NAME,
                autocommit=True,
                cursorclass=DictCursor,
                connect_timeout=10,
                read_timeout=30,
                write_timeout=30,
            )
        else:
            _ensure_db_dir()
            conn = sqlite3.connect(DB_PATH)
            conn.row_factory = sqlite3.Row
        g._db_conn = conn
    return conn


def _close_db() -> None:
    conn = getattr(g, '_db_conn', None)
    if conn is not None:
        conn.close()


def _init_db() -> None:
    if DB_BACKEND == 'mysql':
        if pymysql is None:
            raise RuntimeError('PyMySQL is required for MySQL backend.')
        bootstrap = pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            autocommit=True,
            cursorclass=DictCursor,
            connect_timeout=10,
            read_timeout=30,
            write_timeout=30,
        )
        try:
            with bootstrap.cursor() as cur:
                cur.execute(
                    f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                )
        finally:
            bootstrap.close()

        conn = pymysql.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            autocommit=True,
            cursorclass=DictCursor,
            connect_timeout=10,
            read_timeout=30,
            write_timeout=30,
        )
        try:
            with conn.cursor() as cur:
                cur.execute(
                    '''
                    CREATE TABLE IF NOT EXISTS predictions (
                        id BIGINT PRIMARY KEY AUTO_INCREMENT,
                        request_id VARCHAR(64) NOT NULL,
                        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                        risk_label VARCHAR(64) NOT NULL,
                        stroke_probability DOUBLE NOT NULL,
                        input_json LONGTEXT NOT NULL,
                        result_json LONGTEXT NOT NULL
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                    '''
                )
        finally:
            conn.close()
        return

    _ensure_db_dir()
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            '''
            CREATE TABLE IF NOT EXISTS predictions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                request_id TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                risk_label TEXT NOT NULL,
                stroke_probability REAL NOT NULL,
                input_json TEXT NOT NULL,
                result_json TEXT NOT NULL
            )
            '''
        )
        conn.commit()
    finally:
        conn.close()


def _store_prediction(request_id: str, data: dict[str, Any], result: dict[str, Any]) -> None:
    conn = _get_db()
    values = (
        request_id,
        str(result.get('risk_label', 'Unknown')),
        float(result.get('stroke_probability', 0.0)),
        json.dumps(data),
        json.dumps(result),
    )
    if DB_BACKEND == 'mysql':
        with conn.cursor() as cur:
            cur.execute(
                '''
                INSERT INTO predictions (request_id, risk_label, stroke_probability, input_json, result_json)
                VALUES (%s, %s, %s, %s, %s)
                ''',
                values,
            )
        return
    conn.execute(
        '''
        INSERT INTO predictions (request_id, risk_label, stroke_probability, input_json, result_json)
        VALUES (?, ?, ?, ?, ?)
        ''',
        values,
    )
    conn.commit()


def _as_text(value: Any) -> str:
    if value is None:
        return ''
    return str(value).strip()


def _as_float(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = _as_text(value).replace('%', '')
    try:
        return float(text)
    except ValueError:
        return None


def _as_int(value: Any) -> int | None:
    parsed = _as_float(value)
    if parsed is None:
        return None
    return int(round(parsed))


def _as_yes_no(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    text = _as_text(value).lower()
    if text in YES_VALUES:
        return True
    if text in NO_VALUES:
        return False
    return None


def _canonical_smoking(value: Any) -> str | None:
    text = _as_text(value).lower()
    if not text:
        return None
    if text in {'never smoked', 'never'}:
        return 'Never'
    if text in {'formerly smoked', 'formerly'}:
        return 'Formerly'
    if text in {'smokes', 'smoker'}:
        return 'Smokes'
    return None


def _validate_payload(payload: Any) -> tuple[dict[str, Any] | None, list[ValidationError]]:
    errors: list[ValidationError] = []
    if not isinstance(payload, dict):
        return None, [ValidationError(field='body', message='Request body must be a JSON object.')]

    data: dict[str, Any] = {}

    def read_int(field: str, min_v: int, max_v: int) -> None:
        val = _as_int(payload.get(field))
        if val is None:
            errors.append(ValidationError(field, 'must be an integer'))
            return
        if val < min_v or val > max_v:
            errors.append(ValidationError(field, f'must be between {min_v} and {max_v}'))
            return
        data[field] = val

    def read_float(field: str, min_v: float, max_v: float) -> None:
        val = _as_float(payload.get(field))
        if val is None:
            errors.append(ValidationError(field, 'must be a number'))
            return
        if val < min_v or val > max_v:
            errors.append(ValidationError(field, f'must be between {min_v} and {max_v}'))
            return
        data[field] = float(val)

    def read_choice(field: str, allowed: set[str], canonical: str | None = None) -> None:
        raw = _as_text(payload.get(field)).lower()
        if raw not in allowed:
            errors.append(ValidationError(field, f'must be one of: {", ".join(sorted(allowed))}'))
            return
        data[field] = canonical if canonical else raw

    def read_yes_no(field: str) -> None:
        val = _as_yes_no(payload.get(field))
        if val is None:
            errors.append(ValidationError(field, 'must be Yes or No'))
            return
        data[field] = val

    read_int('age', 1, 120)
    gender_raw = _as_text(payload.get('gender')).lower()
    if gender_raw not in GENDER_VALUES:
        errors.append(ValidationError('gender', 'must be Male, Female, or Other'))
    else:
        data['gender'] = gender_raw.title()

    read_yes_no('hypertension')
    read_yes_no('heart_disease')
    read_yes_no('ever_married')

    work_raw = _as_text(payload.get('work_type')).lower()
    if work_raw not in WORK_TYPE_VALUES:
        errors.append(ValidationError('work_type', 'invalid work type'))
    else:
        data['work_type'] = work_raw

    residence_raw = _as_text(payload.get('Residence_type')).lower()
    if residence_raw not in RESIDENCE_VALUES:
        errors.append(ValidationError('Residence_type', 'must be Urban or Rural'))
    else:
        data['Residence_type'] = residence_raw.title()

    smoking = _canonical_smoking(payload.get('smoking_status'))
    if smoking is None:
        errors.append(ValidationError('smoking_status', 'must be Never, Formerly, or Smokes'))
    else:
        data['smoking_status'] = smoking

    read_float('avg_glucose_level', 20.0, 600.0)
    read_float('bmi', 10.0, 80.0)
    read_int('systolic_bp', 60, 260)
    read_int('diastolic_bp', 30, 180)
    read_yes_no('alcoholic')
    read_yes_no('family_history')
    read_int('sleep_hours', 0, 24)
    read_int('exercise_mins', 0, 600)
    read_yes_no('excess_salt')

    if errors:
        return None, errors
    return data, []


def _sigmoid(x: float) -> float:
    if x >= 0:
        z = math.exp(-x)
        return 1.0 / (1.0 + z)
    z = math.exp(x)
    return z / (1.0 + z)


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _build_features(data: dict[str, Any]) -> dict[str, float]:
    return {
        'age': data['age'] / 100.0,
        'hypertension': 1.0 if data['hypertension'] else 0.0,
        'heart_disease': 1.0 if data['heart_disease'] else 0.0,
        'family_history': 1.0 if data['family_history'] else 0.0,
        'alcoholic': 1.0 if data['alcoholic'] else 0.0,
        'excess_salt': 1.0 if data['excess_salt'] else 0.0,
        'systolic_bp': (data['systolic_bp'] - 110.0) / 70.0,
        'diastolic_bp': (data['diastolic_bp'] - 75.0) / 45.0,
        'bmi': (data['bmi'] - 22.0) / 20.0,
        'glucose': (data['avg_glucose_level'] - 95.0) / 120.0,
        'sleep_short': 1.0 if data['sleep_hours'] < 6 else 0.0,
        'sleep_long': 1.0 if data['sleep_hours'] > 9 else 0.0,
        'exercise_low': 1.0 if data['exercise_mins'] < 30 else 0.0,
        'exercise_high': 1.0 if data['exercise_mins'] >= 90 else 0.0,
        'smoking_formerly': 1.0 if data['smoking_status'] == 'Formerly' else 0.0,
        'smoking_smokes': 1.0 if data['smoking_status'] == 'Smokes' else 0.0,
        'urban': 1.0 if data['Residence_type'] == 'Urban' else 0.0,
    }


FEATURE_WEIGHTS = {
    'age': 1.35,
    'hypertension': 1.25,
    'heart_disease': 1.45,
    'family_history': 0.85,
    'alcoholic': 0.40,
    'excess_salt': 0.55,
    'systolic_bp': 0.90,
    'diastolic_bp': 0.55,
    'bmi': 0.45,
    'glucose': 1.10,
    'sleep_short': 0.55,
    'sleep_long': 0.20,
    'exercise_low': 0.50,
    'exercise_high': -0.35,
    'smoking_formerly': 0.35,
    'smoking_smokes': 0.95,
    'urban': 0.08,
}
BIAS = -2.45

FACTOR_LABELS = {
    'age': 'Age',
    'hypertension': 'Hypertension',
    'heart_disease': 'Heart disease history',
    'family_history': 'Family history of stroke',
    'alcoholic': 'Alcohol use',
    'excess_salt': 'Excess salt intake',
    'systolic_bp': 'Systolic blood pressure',
    'diastolic_bp': 'Diastolic blood pressure',
    'bmi': 'Body Mass Index',
    'glucose': 'Average glucose level',
    'sleep_short': 'Short sleep duration',
    'sleep_long': 'Long sleep duration',
    'exercise_low': 'Low daily exercise',
    'exercise_high': 'High daily exercise',
    'smoking_formerly': 'Former smoking',
    'smoking_smokes': 'Current smoking',
    'urban': 'Urban residence',
}


def _risk_label(probability: float) -> str:
    if probability >= 0.75:
        return 'Very High Risk'
    if probability >= 0.50:
        return 'High Risk'
    if probability >= 0.25:
        return 'Moderate Risk'
    return 'Low Risk'


def _interpretation(probability: float) -> str:
    if probability >= 0.75:
        return 'High concentration of risk signals detected. Clinical follow-up is strongly recommended.'
    if probability >= 0.50:
        return 'Several risk factors are elevated. Structured risk reduction should begin soon.'
    if probability >= 0.25:
        return 'A moderate risk profile is present. Lifestyle optimization can materially improve outcomes.'
    return 'Risk profile is currently lower, but continuous prevention remains important.'


def _top_factors(features: dict[str, float]) -> list[dict[str, Any]]:
    scored: list[tuple[str, float]] = []
    for name, value in features.items():
        weight = FEATURE_WEIGHTS.get(name, 0.0)
        contribution = weight * value
        if abs(contribution) >= 0.04:
            scored.append((name, contribution))

    scored.sort(key=lambda item: abs(item[1]), reverse=True)
    top = scored[:5]

    factors: list[dict[str, Any]] = []
    for name, contribution in top:
        effect = 'increase' if contribution >= 0 else 'decrease'
        factors.append(
            {
                'feature': name,
                'label': FACTOR_LABELS.get(name, name),
                'effect': effect,
                'impact_score': round(abs(contribution), 4),
                'contribution': round(contribution, 4),
            }
        )
    return factors


def _build_recommendations(probability: float, factors: list[dict[str, Any]]) -> list[str]:
    recs: list[str] = []
    factor_names = {f['feature'] for f in factors}

    if 'systolic_bp' in factor_names or 'diastolic_bp' in factor_names or 'hypertension' in factor_names:
        recs.append('Track blood pressure daily and discuss target range with your clinician.')
    if 'smoking_smokes' in factor_names:
        recs.append('Start a smoking cessation plan; quitting can reduce stroke risk quickly.')
    if 'glucose' in factor_names:
        recs.append('Monitor glucose and prioritize low-glycemic meals with regular follow-up.')
    if 'exercise_low' in factor_names:
        recs.append('Increase activity toward at least 150 minutes/week of moderate exercise.')
    if 'excess_salt' in factor_names:
        recs.append('Reduce sodium intake and avoid highly processed foods.')

    if probability >= 0.50:
        recs.append('Book a clinical review to evaluate preventive medications and labs.')
    if probability < 0.25:
        recs.append('Maintain current habits and continue routine preventive screenings.')

    if not recs:
        recs.append('Keep a consistent prevention routine: exercise, sleep quality, and balanced diet.')

    return recs[:5]


def _predict(data: dict[str, Any]) -> dict[str, Any]:
    features = _build_features(data)
    logit = BIAS + sum(FEATURE_WEIGHTS[name] * value for name, value in features.items())
    probability = _clamp(_sigmoid(logit), 0.01, 0.99)

    factors = _top_factors(features)
    label = _risk_label(probability)
    summary = (
        f'CardioRisk AI estimated {probability * 100:.1f}% stroke risk with strongest '
        f'contributors from {", ".join(f["label"] for f in factors[:3]) or "overall profile"}.'
    )

    return {
        'stroke_prediction': round(probability, 4),
        'stroke_probability': round(probability * 100.0, 2),
        'no_stroke_probability': round((1 - probability) * 100.0, 2),
        'risk_label': label,
        'interpretation': _interpretation(probability),
        'ai_summary': summary,
        'top_factors': factors,
        'recommendations': _build_recommendations(probability, factors),
    }


@app.before_request
def _before_request() -> None:
    g.request_id = uuid.uuid4().hex[:12]
    g.start_time = time.perf_counter()


@app.after_request
def _after_request(response):
    request_id = getattr(g, 'request_id', uuid.uuid4().hex[:12])
    response.headers['X-Request-ID'] = request_id

    duration_ms = None
    if hasattr(g, 'start_time'):
        duration_ms = round((time.perf_counter() - g.start_time) * 1000, 2)

    log_payload = {
        'request_id': request_id,
        'method': request.method,
        'path': request.path,
        'status': response.status_code,
        'duration_ms': duration_ms,
    }
    logger.info(json.dumps(log_payload))
    return response


@app.teardown_appcontext
def _teardown_appcontext(_error) -> None:
    _close_db()


def _error_response(errors: list[ValidationError], status_code: int = 400):
    return (
        jsonify(
            {
                'error': 'validation_error',
                'api_version': API_VERSION,
                'request_id': getattr(g, 'request_id', ''),
                'errors': [{'field': e.field, 'message': e.message} for e in errors],
            }
        ),
        status_code,
    )


@app.get('/')
def root():
    storage_info = {
        'backend': DB_BACKEND,
        'db_name': DB_NAME if DB_BACKEND == 'mysql' else DB_PATH,
    }
    return jsonify(
        {
            'service': 'heart-stroke-api',
            'status': 'ok',
            'api_version': API_VERSION,
            'model': MODEL_META,
            'storage_backend': storage_info,
            'endpoints': ['/predict', '/v1/predict', '/v1/predictions', '/healthz', '/v1/model-card'],
        }
    )


@app.get('/healthz')
@app.get('/v1/healthz')
def healthz():
    return jsonify(
        {
            'status': 'ok',
            'api_version': API_VERSION,
            'model_version': MODEL_META['version'],
        }
    )


@app.get('/v1/model-card')
def model_card():
    return jsonify(
        {
            'api_version': API_VERSION,
            'model': MODEL_META,
            'feature_count': len(FEATURE_WEIGHTS),
            'notes': 'Interpretable logistic scoring model optimized for educational risk triage.',
            'disclaimer': DISCLAIMER,
        }
    )


def _predict_handler():
    payload = request.get_json(silent=True)
    data, errors = _validate_payload(payload)
    if errors:
        return _error_response(errors, 400)

    result = _predict(data)
    request_id = getattr(g, 'request_id', '')
    try:
        _store_prediction(request_id, data, result)
    except Exception as exc:
        logger.error(
            json.dumps(
                {
                    'event': 'prediction_store_failed',
                    'request_id': request_id,
                    'error': str(exc),
                }
            )
        )
    result.update(
        {
            'api_version': API_VERSION,
            'model_name': MODEL_META['name'],
            'model_version': MODEL_META['version'],
            'request_id': request_id,
            'disclaimer': DISCLAIMER,
            'input_echo': data,
        }
    )
    return jsonify(result)


@app.post('/predict')
def predict_legacy():
    return _predict_handler()


@app.post('/v1/predict')
def predict_v1():
    return _predict_handler()


@app.get('/v1/predictions')
def list_predictions():
    limit_raw = request.args.get('limit', '20')
    try:
        limit = int(limit_raw)
    except ValueError:
        return _error_response([ValidationError('limit', 'must be an integer')], 400)

    if limit < 1 or limit > 100:
        return _error_response([ValidationError('limit', 'must be between 1 and 100')], 400)

    conn = _get_db()
    if DB_BACKEND == 'mysql':
        with conn.cursor() as cur:
            cur.execute(
                '''
                SELECT id, request_id, created_at, risk_label, stroke_probability, input_json, result_json
                FROM predictions
                ORDER BY id DESC
                LIMIT %s
                ''',
                (limit,),
            )
            rows = cur.fetchall()
    else:
        rows = conn.execute(
            '''
            SELECT id, request_id, created_at, risk_label, stroke_probability, input_json, result_json
            FROM predictions
            ORDER BY id DESC
            LIMIT ?
            ''',
            (limit,),
        ).fetchall()

    records: list[dict[str, Any]] = []
    for row in rows:
        records.append(
            {
                'id': row['id'],
                'request_id': row['request_id'],
                'created_at': row['created_at'],
                'risk_label': row['risk_label'],
                'stroke_probability': row['stroke_probability'],
                'input': json.loads(row['input_json']),
                'result': json.loads(row['result_json']),
            }
        )

    return jsonify(
        {
            'api_version': API_VERSION,
            'storage_backend': DB_BACKEND,
            'db_target': f'{DB_HOST}:{DB_PORT}/{DB_NAME}' if DB_BACKEND == 'mysql' else DB_PATH,
            'count': len(records),
            'records': records,
        }
    )


_init_db()


if __name__ == '__main__':
    port = int(os.getenv('PORT', '8000'))
    app.run(host='0.0.0.0', port=port)
