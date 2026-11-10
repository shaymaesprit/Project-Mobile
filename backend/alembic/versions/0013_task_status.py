"""Task status column kept consistent with is_completed.

Some local databases already have ``tasks.status`` (pending / in_progress /
completed) with a CHECK tying ``status = 'completed'`` to ``is_completed``,
while the ORM model ignored it — so ticking a task violated the constraint.
This migration makes every database converge on the same schema (idempotent).
"""

from typing import Sequence

from alembic import op

revision: str = "0013_task_status"
down_revision: str | None = "0012_add_timetable_entries"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE tasks ADD COLUMN IF NOT EXISTS status varchar(16) "
        "NOT NULL DEFAULT 'pending'"
    )
    # Remet d'aplomb les lignes existantes avant de (re)poser les contraintes.
    op.execute(
        "UPDATE tasks SET status = CASE WHEN is_completed THEN 'completed' "
        "WHEN status = 'completed' THEN 'pending' ELSE status END"
    )
    op.execute(
        """
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_tasks_status') THEN
            ALTER TABLE tasks ADD CONSTRAINT ck_tasks_status
              CHECK (status IN ('pending', 'in_progress', 'completed'));
          END IF;
          IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_tasks_status_completed') THEN
            ALTER TABLE tasks ADD CONSTRAINT ck_tasks_status_completed
              CHECK ((status = 'completed') = is_completed);
          END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tasks DROP CONSTRAINT IF EXISTS ck_tasks_status_completed")
    op.execute("ALTER TABLE tasks DROP CONSTRAINT IF EXISTS ck_tasks_status")
    op.execute("ALTER TABLE tasks DROP COLUMN IF EXISTS status")
