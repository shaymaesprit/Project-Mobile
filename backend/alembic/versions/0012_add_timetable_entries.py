"""Add timetable_entries table for per-user scheduled course sessions."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0012_add_timetable_entries"
down_revision: str | None = "0011_add_timetable_share"
branch_labels: Sequence[str] | None = None
depends_on: Sequence[str] | None = None


def upgrade() -> None:
    # Create the SeanceType enum
    seancetype = sa.Enum("COURS", "TD", "TP", name="seancetype")
    seancetype.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "timetable_entries",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("course_id", sa.UUID(), nullable=False),
        sa.Column("jour", sa.Integer(), nullable=False),
        sa.Column("heure_debut", sa.Time(), nullable=False),
        sa.Column("heure_fin", sa.Time(), nullable=False),
        sa.Column("salle", sa.String(100), nullable=True),
        sa.Column(
            "type_seance",
            sa.Enum("COURS", "TD", "TP", name="seancetype"),
            nullable=False,
            server_default="COURS",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint("heure_debut < heure_fin", name="ck_timetable_entries_time_order"),
        sa.CheckConstraint("jour BETWEEN 0 AND 6", name="ck_timetable_entries_jour"),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["course_id"], ["courses.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_timetable_entries_owner_uid", "timetable_entries", ["owner_uid"]
    )
    op.create_index(
        "ix_timetable_entries_owner_jour",
        "timetable_entries",
        ["owner_uid", "jour"],
    )
    op.create_index(
        "ix_timetable_entries_owner_cours",
        "timetable_entries",
        ["owner_uid", "course_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_timetable_entries_owner_cours", table_name="timetable_entries")
    op.drop_index("ix_timetable_entries_owner_jour", table_name="timetable_entries")
    op.drop_index("ix_timetable_entries_owner_uid", table_name="timetable_entries")
    op.drop_table("timetable_entries")
    sa.Enum(name="seancetype").drop(op.get_bind(), checkfirst=True)
