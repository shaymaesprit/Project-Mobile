"""Extend course with schedule fields: type_cours, semestre, description, coefficient, difficulte_percue."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0010_extend_course_schedule_fields"
down_revision: str | None = "0009_ai_recommendations"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    # Create the course_type enum
    course_type_enum = sa.Enum("COURS", "TD", "TP", name="course_type")
    course_type_enum.create(op.get_bind(), checkfirst=True)

    op.add_column("courses", sa.Column("type_cours", sa.Enum("COURS", "TD", "TP", name="course_type"), nullable=True))
    op.add_column("courses", sa.Column("semestre", sa.String(20), nullable=True))
    op.add_column("courses", sa.Column("description", sa.Text, nullable=True))
    op.add_column("courses", sa.Column("coefficient", sa.Float, nullable=True))
    op.add_column("courses", sa.Column("difficulte_percue", sa.Integer, nullable=True))

    op.create_check_constraint(
        "ck_courses_difficulte_percue",
        "courses",
        "difficulte_percue IS NULL OR (difficulte_percue BETWEEN 1 AND 5)",
    )


def downgrade() -> None:
    op.drop_constraint("ck_courses_difficulte_percue", "courses", type_="check")
    op.drop_column("courses", "difficulte_percue")
    op.drop_column("courses", "coefficient")
    op.drop_column("courses", "description")
    op.drop_column("courses", "semestre")
    op.drop_column("courses", "type_cours")

    sa.Enum(name="course_type").drop(op.get_bind(), checkfirst=True)
