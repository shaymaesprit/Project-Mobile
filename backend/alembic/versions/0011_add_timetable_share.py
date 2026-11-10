"""Add timetable_shares table for schedule sharing via QR code."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0011_add_timetable_share"
down_revision: str | None = "0010_extend_course_schedule_fields"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "timetable_shares",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("token", sa.String(64), nullable=False),
        sa.Column("qr_url", sa.String(500), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token"),
    )
    op.create_index("ix_timetable_shares_token", "timetable_shares", ["token"], unique=True)
    op.create_index("ix_timetable_shares_owner_active", "timetable_shares", ["owner_uid", "is_active"])
    op.create_index("ix_timetable_shares_owner_uid", "timetable_shares", ["owner_uid"])


def downgrade() -> None:
    op.drop_index("ix_timetable_shares_owner_uid", table_name="timetable_shares")
    op.drop_index("ix_timetable_shares_owner_active", table_name="timetable_shares")
    op.drop_index("ix_timetable_shares_token", table_name="timetable_shares")
    op.drop_table("timetable_shares")
