"""Event status, coordinates, reminder offsets and the reminder queue."""

from typing import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0010_event_reminders"
down_revision: str | None = "0009_ai_recommendations"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column(
            "status",
            sa.String(length=16),
            server_default=sa.text("'planned'"),
            nullable=False,
        ),
    )
    op.add_column("events", sa.Column("latitude", sa.Float(), nullable=True))
    op.add_column("events", sa.Column("longitude", sa.Float(), nullable=True))
    op.add_column(
        "events",
        sa.Column(
            "reminder_offsets",
            postgresql.JSONB(),
            server_default=sa.text("'[]'::jsonb"),
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "ck_events_status", "events", "status IN ('planned', 'done', 'cancelled')"
    )

    op.create_table(
        "event_reminders",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("owner_uid", sa.String(length=128), nullable=False),
        sa.Column("event_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("offset_minutes", sa.Integer(), nullable=False),
        sa.Column("remind_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint("offset_minutes >= 0", name="ck_event_reminders_offset"),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "event_id", "offset_minutes", name="uq_event_reminders_offset"
        ),
    )
    op.create_index(
        "ix_event_reminders_due",
        "event_reminders",
        ["remind_at"],
        postgresql_where=sa.text("sent_at IS NULL"),
    )

    op.execute("ALTER TABLE event_reminders ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE event_reminders FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY tenant_isolation ON event_reminders
        USING (owner_uid = NULLIF(current_setting('app.firebase_uid', true), ''))
        WITH CHECK (owner_uid = NULLIF(current_setting('app.firebase_uid', true), ''))
        """
    )
    # Le planificateur de rappels tourne sans utilisateur : il doit pouvoir
    # LIRE la file des rappels échus (et uniquement elle, en lecture seule).
    # Chaque envoi se fait ensuite dans une session limitée à son propriétaire.
    op.execute(
        """
        CREATE POLICY scheduler_read_due ON event_reminders
        FOR SELECT
        USING (current_setting('app.scheduler', true) = 'on')
        """
    )


def downgrade() -> None:
    op.execute("DROP POLICY scheduler_read_due ON event_reminders")
    op.execute("DROP POLICY tenant_isolation ON event_reminders")
    op.execute("ALTER TABLE event_reminders DISABLE ROW LEVEL SECURITY")
    op.drop_index("ix_event_reminders_due", table_name="event_reminders")
    op.drop_table("event_reminders")
    op.drop_constraint("ck_events_status", "events", type_="check")
    op.drop_column("events", "reminder_offsets")
    op.drop_column("events", "longitude")
    op.drop_column("events", "latitude")
    op.drop_column("events", "status")
