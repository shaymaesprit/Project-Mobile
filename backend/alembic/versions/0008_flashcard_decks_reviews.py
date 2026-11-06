"""Add flashcard decks and review history."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0008_flashcard_decks_reviews"
down_revision: str | None = "0006_course_schedule"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)


def _enable_tenant_isolation(table_name: str) -> None:
    op.execute(f"ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY")
    op.execute(f"ALTER TABLE {table_name} FORCE ROW LEVEL SECURITY")
    op.execute(
        f"""
        CREATE POLICY tenant_isolation ON {table_name}
        USING (owner_uid = NULLIF(current_setting('app.firebase_uid', true), ''))
        WITH CHECK (owner_uid = NULLIF(current_setting('app.firebase_uid', true), ''))
        """
    )


def upgrade() -> None:
    op.create_table(
        "flashcard_decks",
        sa.Column(
            "id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False
        ),
        sa.Column("owner_uid", sa.String(length=128), nullable=False),
        sa.Column("course_id", UUID, nullable=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "source",
            sa.String(length=24),
            server_default=sa.text("'manual'"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "source IN ('manual', 'ai_generated')",
            name="ck_flashcard_decks_source",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "course_id"],
            ["courses.owner_uid", "courses.id"],
            name="fk_flashcard_decks_course_owner",
            ondelete="SET NULL (course_id)",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_flashcard_decks_owner_id"),
    )
    op.create_index(
        "ix_flashcard_decks_owner_created",
        "flashcard_decks",
        ["owner_uid", "created_at"],
    )

    op.add_column("flashcards", sa.Column("deck_id", UUID, nullable=True))
    op.create_foreign_key(
        "fk_flashcards_deck_owner",
        "flashcards",
        "flashcard_decks",
        ["owner_uid", "deck_id"],
        ["owner_uid", "id"],
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_flashcards_owner_deck",
        "flashcards",
        ["owner_uid", "deck_id"],
    )

    op.create_table(
        "flashcard_reviews",
        sa.Column(
            "id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False
        ),
        sa.Column("owner_uid", sa.String(length=128), nullable=False),
        sa.Column("flashcard_id", UUID, nullable=False),
        sa.Column("is_correct", sa.Boolean(), nullable=False),
        sa.Column(
            "reviewed_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "flashcard_id"],
            ["flashcards.owner_uid", "flashcards.id"],
            name="fk_flashcard_reviews_card_owner",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_flashcard_reviews_owner_reviewed",
        "flashcard_reviews",
        ["owner_uid", "reviewed_at"],
    )
    op.create_index(
        "ix_flashcard_reviews_owner_card",
        "flashcard_reviews",
        ["owner_uid", "flashcard_id"],
    )

    _enable_tenant_isolation("flashcard_decks")
    _enable_tenant_isolation("flashcard_reviews")


def downgrade() -> None:
    op.execute(
        "DROP POLICY tenant_isolation ON flashcard_reviews"
    )
    op.execute("ALTER TABLE flashcard_reviews DISABLE ROW LEVEL SECURITY")
    op.drop_index("ix_flashcard_reviews_owner_card", table_name="flashcard_reviews")
    op.drop_index(
        "ix_flashcard_reviews_owner_reviewed", table_name="flashcard_reviews"
    )
    op.drop_table("flashcard_reviews")
    op.drop_index("ix_flashcards_owner_deck", table_name="flashcards")
    op.drop_constraint("fk_flashcards_deck_owner", "flashcards", type_="foreignkey")
    op.drop_column("flashcards", "deck_id")
    op.execute("DROP POLICY tenant_isolation ON flashcard_decks")
    op.execute("ALTER TABLE flashcard_decks DISABLE ROW LEVEL SECURITY")
    op.drop_index("ix_flashcard_decks_owner_created", table_name="flashcard_decks")
    op.drop_table("flashcard_decks")
