"""Add AI recommendations with user feedback status."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009_ai_recommendations"
down_revision: str | None = "0008_flashcard_decks_reviews"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

UUID = postgresql.UUID(as_uuid=True)


def upgrade() -> None:
    op.create_table(
        "ai_recommendations",
        sa.Column(
            "id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False
        ),
        sa.Column("owner_uid", sa.String(length=128), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("category", sa.String(length=32), nullable=False),
        sa.Column(
            "priority",
            sa.String(length=16),
            server_default=sa.text("'medium'"),
            nullable=False,
        ),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("suggested_action", sa.Text(), nullable=True),
        sa.Column(
            "source",
            sa.String(length=16),
            server_default=sa.text("'ai'"),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(length=16),
            server_default=sa.text("'pending'"),
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
            "status IN ('pending', 'accepted', 'modified', 'rejected')",
            name="ck_ai_recommendations_status",
        ),
        sa.CheckConstraint(
            "priority IN ('low', 'medium', 'high')",
            name="ck_ai_recommendations_priority",
        ),
        sa.CheckConstraint(
            "source IN ('ai', 'rules')", name="ck_ai_recommendations_source"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_ai_recommendations_owner_id"),
    )
    op.create_index(
        "ix_ai_recommendations_owner_created",
        "ai_recommendations",
        ["owner_uid", "created_at"],
    )
    op.execute("ALTER TABLE ai_recommendations ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE ai_recommendations FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY tenant_isolation ON ai_recommendations
        USING (owner_uid = NULLIF(current_setting('app.firebase_uid', true), ''))
        WITH CHECK (owner_uid = NULLIF(current_setting('app.firebase_uid', true), ''))
        """
    )


def downgrade() -> None:
    op.execute("DROP POLICY tenant_isolation ON ai_recommendations")
    op.execute("ALTER TABLE ai_recommendations DISABLE ROW LEVEL SECURITY")
    op.drop_index(
        "ix_ai_recommendations_owner_created", table_name="ai_recommendations"
    )
    op.drop_table("ai_recommendations")
