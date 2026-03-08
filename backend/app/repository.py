from __future__ import annotations

import json
from datetime import datetime

from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from .models import PredictionRecord
from .schemas import PredictionInput


def save_prediction(
    session: Session,
    *,
    request_id: str,
    payload: PredictionInput,
    output: dict,
) -> PredictionRecord:
    record = PredictionRecord(
        request_id=request_id,
        risk_probability=float(output["risk_probability"]),
        risk_label=str(output["risk_label"]),
        input_payload=json.dumps(payload.model_dump(), ensure_ascii=False),
        output_payload=json.dumps(output, ensure_ascii=False),
    )
    session.add(record)
    session.flush()
    return record


def latest_prediction_summary(session: Session) -> dict | None:
    stmt = select(PredictionRecord).order_by(desc(PredictionRecord.id)).limit(1)
    record = session.execute(stmt).scalars().first()
    if record is None:
        return None

    return {
        "id": record.id,
        "timestamp": record.created_at.isoformat() if isinstance(record.created_at, datetime) else None,
        "risk_probability": record.risk_probability,
        "risk_label": record.risk_label,
    }


def list_predictions(session: Session, limit: int) -> list[dict]:
    stmt = select(PredictionRecord).order_by(desc(PredictionRecord.id)).limit(limit)
    rows = session.execute(stmt).scalars().all()
    return [row.to_history_dict() for row in rows]
