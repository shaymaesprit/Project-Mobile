"""Add student academic fields to learning profiles."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005_student_profile_fields"
down_revision: str | None = "0004_sha256_fixed_width"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "learning_profiles",
        sa.Column("study_level", sa.String(length=80), nullable=True),
    )
    op.add_column(
        "learning_profiles",
        sa.Column("specialty", sa.String(length=160), nullable=True),
    )
    op.add_column(
        "learning_profiles",
        sa.Column(
            "academic_goals",
            sa.JSON().with_variant(postgresql.JSONB(), "postgresql"),
            server_default=sa.text("'[]'"),
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "ck_learning_profiles_academic_goals_array",
        "learning_profiles",
        "jsonb_typeof(academic_goals) = 'array'",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_learning_profiles_academic_goals_array",
        "learning_profiles",
        type_="check",
    )
    op.drop_column("learning_profiles", "academic_goals")
    op.drop_column("learning_profiles", "specialty")
    op.drop_column("learning_profiles", "study_level")
