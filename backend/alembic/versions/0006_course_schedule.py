"""Add weekly schedule fields to courses."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0006_course_schedule"
down_revision: str | None = "0005_student_profile_fields"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("courses", sa.Column("weekday", sa.Integer(), nullable=True))
    op.add_column("courses", sa.Column("start_time", sa.Time(), nullable=True))
    op.add_column("courses", sa.Column("end_time", sa.Time(), nullable=True))
    op.create_check_constraint(
        "ck_courses_schedule",
        "courses",
        "(weekday IS NULL AND start_time IS NULL AND end_time IS NULL) OR "
        "(weekday BETWEEN 0 AND 6 AND start_time IS NOT NULL "
        "AND end_time IS NOT NULL AND start_time < end_time)",
    )
    op.create_index(
        "ix_courses_owner_schedule",
        "courses",
        ["owner_uid", "weekday", "start_time"],
    )


def downgrade() -> None:
    op.drop_index("ix_courses_owner_schedule", table_name="courses")
    op.drop_constraint("ck_courses_schedule", "courses", type_="check")
    op.drop_column("courses", "end_time")
    op.drop_column("courses", "start_time")
    op.drop_column("courses", "weekday")
