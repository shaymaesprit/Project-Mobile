"""Add profile display and task completion fields.

Revision ID: 0003_user_profile_fields
Revises: 0002_study_and_rag_schema
"""
from typing import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0003_user_profile_fields"
down_revision: str | None = "0002_study_and_rag_schema"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("photo_url", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("locale", sa.String(20), nullable=True))
    op.add_column("users", sa.Column("timezone", sa.String(64), nullable=True))
    op.add_column("courses", sa.Column("color", sa.String(16), nullable=True))
    op.add_column(
        "tasks", sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("tasks", "completed_at")
    op.drop_column("courses", "color")
    op.drop_column("users", "timezone")
    op.drop_column("users", "locale")
    op.drop_column("users", "photo_url")
