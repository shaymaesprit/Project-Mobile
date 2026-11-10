"""Nombre de pages des PDF de cours (table documents)."""

from typing import Sequence

from alembic import op

revision: str = "0014_document_page_count"
down_revision: str | None = "0013_task_status"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("ALTER TABLE documents ADD COLUMN IF NOT EXISTS page_count integer")
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'ck_documents_page_count'
            ) THEN
                ALTER TABLE documents ADD CONSTRAINT ck_documents_page_count
                    CHECK (page_count IS NULL OR page_count >= 0);
            END IF;
        END
        $$
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE documents DROP CONSTRAINT IF EXISTS ck_documents_page_count")
    op.execute("ALTER TABLE documents DROP COLUMN IF EXISTS page_count")
