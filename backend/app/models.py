import json
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, Float, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class PredictionRecord(Base):
    __tablename__ = "predictions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    request_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False), nullable=False, server_default=func.now(), index=True
    )
    risk_probability: Mapped[float] = mapped_column(Float, nullable=False)
    risk_label: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    input_payload: Mapped[str] = mapped_column(Text, nullable=False)
    output_payload: Mapped[str] = mapped_column(Text, nullable=False)

    @staticmethod
    def _safe_load_json(raw: str) -> Any:
        try:
            return json.loads(raw)
        except (TypeError, json.JSONDecodeError):
            return {}

    def to_history_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "request_id": self.request_id,
            "timestamp": self.created_at.isoformat() if self.created_at else None,
            "risk_probability": self.risk_probability,
            "risk_label": self.risk_label,
            "input_payload": self._safe_load_json(self.input_payload),
            "output_payload": self._safe_load_json(self.output_payload),
        }
