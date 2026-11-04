"""Use fixed-width storage for document SHA-256 digests.

Revision ID: 0004_sha256_fixed_width
Revises: 0003_user_profile_fields
"""
from typing import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0004_sha256_fixed_width"
down_revision: str | None = "0003_user_profile_fields"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "documents",
        "sha256",
        existing_type=sa.String(length=64),
        type_=sa.CHAR(length=64),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "documents",
        "sha256",
        existing_type=sa.CHAR(length=64),
        type_=sa.String(length=64),
        existing_nullable=True,
    )
