"""create predictions table

Revision ID: 0001_create_predictions
Revises: 
Create Date: 2026-02-19

"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0001_create_predictions"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "predictions",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("request_id", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("risk_probability", sa.Float(), nullable=False),
        sa.Column("risk_label", sa.String(length=20), nullable=False),
        sa.Column("input_payload", sa.Text(), nullable=False),
        sa.Column("output_payload", sa.Text(), nullable=False),
    )
    op.create_index("ix_predictions_request_id", "predictions", ["request_id"])
    op.create_index("ix_predictions_created_at", "predictions", ["created_at"])
    op.create_index("ix_predictions_risk_label", "predictions", ["risk_label"])


def downgrade() -> None:
    op.drop_index("ix_predictions_risk_label", table_name="predictions")
    op.drop_index("ix_predictions_created_at", table_name="predictions")
    op.drop_index("ix_predictions_request_id", table_name="predictions")
    op.drop_table("predictions")
