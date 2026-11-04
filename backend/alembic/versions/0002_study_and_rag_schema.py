"""Add StudyMate learning, notification, and RAG tables.

Revision ID: 0002_study_and_rag_schema
Revises: 0001_initial
"""
from typing import Sequence

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects import postgresql

revision: str = "0002_study_and_rag_schema"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

JSONB = postgresql.JSONB(astext_type=sa.Text())
UUID = postgresql.UUID(as_uuid=True)


def _create_tenant_policies() -> None:
    op.execute(
        """
        DO $$
        DECLARE
            table_name text;
            owner_column text;
        BEGIN
            FOREACH table_name IN ARRAY ARRAY[
                'users', 'learning_profiles', 'courses', 'tasks', 'notes',
                'flashcards', 'evaluations', 'events', 'notifications',
                'study_sessions', 'gamification', 'ai_insights',
                'notification_devices', 'documents', 'document_chunks',
                'chunk_embeddings'
            ] LOOP
                owner_column := CASE
                    WHEN table_name = 'users' THEN 'firebase_uid'
                    ELSE 'owner_uid'
                END;

                EXECUTE format(
                    'ALTER TABLE %I ENABLE ROW LEVEL SECURITY',
                    table_name
                );
                EXECUTE format(
                    'ALTER TABLE %I FORCE ROW LEVEL SECURITY',
                    table_name
                );
                EXECUTE format(
                    'CREATE POLICY tenant_isolation ON %I '
                    'USING (%I = NULLIF(current_setting('
                    '''app.firebase_uid'', true), '''')) '
                    'WITH CHECK (%I = NULLIF(current_setting('
                    '''app.firebase_uid'', true), ''''))',
                    table_name, owner_column, owner_column
                );
            END LOOP;
        END
        $$
        """
    )


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_unique_constraint(
        "uq_courses_owner_id", "courses", ["owner_uid", "id"]
    )
    op.create_unique_constraint("uq_tasks_owner_id", "tasks", ["owner_uid", "id"])
    op.create_unique_constraint("uq_notes_owner_id", "notes", ["owner_uid", "id"])

    op.drop_constraint("tasks_course_id_fkey", "tasks", type_="foreignkey")
    op.create_foreign_key(
        "fk_tasks_course_owner",
        "tasks",
        "courses",
        ["owner_uid", "course_id"],
        ["owner_uid", "id"],
        ondelete="SET NULL (course_id)",
    )
    op.drop_constraint("notes_course_id_fkey", "notes", type_="foreignkey")
    op.create_foreign_key(
        "fk_notes_course_owner",
        "notes",
        "courses",
        ["owner_uid", "course_id"],
        ["owner_uid", "id"],
        ondelete="SET NULL (course_id)",
    )

    op.create_table(
        "learning_profiles",
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("preferred_learning_style", sa.String(32), nullable=True),
        sa.Column(
            "daily_study_goal_minutes",
            sa.Integer(),
            server_default=sa.text("60"),
            nullable=False,
        ),
        sa.Column(
            "preferences",
            JSONB,
            server_default=sa.text("'{}'::jsonb"),
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
            "preferred_learning_style IS NULL OR preferred_learning_style IN "
            "('visual', 'auditory', 'reading', 'kinesthetic', 'mixed')",
            name="ck_learning_profiles_style",
        ),
        sa.CheckConstraint(
            "daily_study_goal_minutes BETWEEN 0 AND 1440",
            name="ck_learning_profiles_goal",
        ),
        sa.CheckConstraint(
            "jsonb_typeof(preferences) = 'object'",
            name="ck_learning_profiles_preferences_object",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("owner_uid"),
    )
    op.create_table(
        "flashcards",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("course_id", UUID, nullable=True),
        sa.Column("question", sa.Text(), nullable=False),
        sa.Column("answer", sa.Text(), nullable=False),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("interval_days", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column(
            "ease_factor",
            sa.Numeric(4, 2),
            server_default=sa.text("2.50"),
            nullable=False,
        ),
        sa.Column("repetitions", sa.Integer(), server_default=sa.text("0"), nullable=False),
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
        sa.CheckConstraint("interval_days >= 0", name="ck_flashcards_interval"),
        sa.CheckConstraint("ease_factor >= 1.30", name="ck_flashcards_ease"),
        sa.CheckConstraint("repetitions >= 0", name="ck_flashcards_repetitions"),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "course_id"],
            ["courses.owner_uid", "courses.id"],
            name="fk_flashcards_course_owner",
            ondelete="SET NULL (course_id)",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_flashcards_owner_id"),
    )
    op.create_table(
        "evaluations",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("course_id", UUID, nullable=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("evaluation_type", sa.String(32), server_default=sa.text("'other'"), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("score", sa.Numeric(8, 2), nullable=True),
        sa.Column("max_score", sa.Numeric(8, 2), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "evaluation_type IN ('exam', 'quiz', 'assignment', 'presentation', 'other')",
            name="ck_evaluations_type",
        ),
        sa.CheckConstraint("score IS NULL OR score >= 0", name="ck_evaluations_score"),
        sa.CheckConstraint("max_score IS NULL OR max_score > 0", name="ck_evaluations_max_score"),
        sa.CheckConstraint(
            "score IS NULL OR max_score IS NULL OR score <= max_score",
            name="ck_evaluations_score_within_max",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "course_id"],
            ["courses.owner_uid", "courses.id"],
            name="fk_evaluations_course_owner",
            ondelete="SET NULL (course_id)",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_evaluations_owner_id"),
    )
    op.create_table(
        "events",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("course_id", UUID, nullable=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("event_type", sa.String(32), server_default=sa.text("'other'"), nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("location", sa.String(200), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "event_type IN ('class', 'study', 'exam', 'deadline', 'personal', 'other')",
            name="ck_events_type",
        ),
        sa.CheckConstraint(
            "ends_at IS NULL OR ends_at >= starts_at", name="ck_events_time_range"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "course_id"],
            ["courses.owner_uid", "courses.id"],
            name="fk_events_course_owner",
            ondelete="SET NULL (course_id)",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_events_owner_id"),
    )
    op.create_table(
        "notifications",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("notification_type", sa.String(32), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("payload", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_notifications_owner_id"),
    )
    op.create_table(
        "study_sessions",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("course_id", UUID, nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("focus_rating", sa.SmallInteger(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "duration_seconds IS NULL OR duration_seconds >= 0",
            name="ck_study_sessions_duration",
        ),
        sa.CheckConstraint(
            "focus_rating IS NULL OR focus_rating BETWEEN 1 AND 5",
            name="ck_study_sessions_focus",
        ),
        sa.CheckConstraint(
            "ended_at IS NULL OR ended_at >= started_at",
            name="ck_study_sessions_time_range",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "course_id"],
            ["courses.owner_uid", "courses.id"],
            name="fk_study_sessions_course_owner",
            ondelete="SET NULL (course_id)",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_study_sessions_owner_id"),
    )
    op.create_table(
        "gamification",
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("points", sa.BigInteger(), server_default=sa.text("0"), nullable=False),
        sa.Column("level", sa.Integer(), server_default=sa.text("1"), nullable=False),
        sa.Column("current_streak_days", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("longest_streak_days", sa.Integer(), server_default=sa.text("0"), nullable=False),
        sa.Column("last_study_date", sa.Date(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("points >= 0", name="ck_gamification_points"),
        sa.CheckConstraint("level >= 1", name="ck_gamification_level"),
        sa.CheckConstraint(
            "current_streak_days >= 0", name="ck_gamification_current_streak"
        ),
        sa.CheckConstraint(
            "longest_streak_days >= current_streak_days",
            name="ck_gamification_longest_streak",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("owner_uid"),
    )
    op.create_table(
        "ai_insights",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("insight_type", sa.String(40), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", sa.String(16), server_default=sa.text("'active'"), nullable=False),
        sa.Column("evidence", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint(
            "status IN ('active', 'dismissed', 'expired')",
            name="ck_ai_insights_status",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_ai_insights_owner_id"),
    )
    op.create_table(
        "notification_devices",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("fcm_token", sa.Text(), nullable=False),
        sa.Column("platform", sa.String(16), nullable=False),
        sa.Column("device_name", sa.String(160), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "platform IN ('android', 'ios', 'web')",
            name="ck_notification_devices_platform",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("fcm_token", name="uq_notification_devices_fcm_token"),
        sa.UniqueConstraint(
            "owner_uid", "id", name="uq_notification_devices_owner_id"
        ),
    )
    op.create_table(
        "documents",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("course_id", UUID, nullable=True),
        sa.Column("note_id", UUID, nullable=True),
        sa.Column("title", sa.String(240), nullable=False),
        sa.Column("storage_path", sa.Text(), nullable=True),
        sa.Column("mime_type", sa.String(127), nullable=True),
        sa.Column("file_size_bytes", sa.BigInteger(), nullable=True),
        sa.Column("sha256", sa.String(64), nullable=True),
        sa.Column("processing_status", sa.String(16), server_default=sa.text("'pending'"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "file_size_bytes IS NULL OR file_size_bytes >= 0",
            name="ck_documents_file_size",
        ),
        sa.CheckConstraint(
            "processing_status IN ('pending', 'processing', 'ready', 'failed')",
            name="ck_documents_processing_status",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "course_id"],
            ["courses.owner_uid", "courses.id"],
            name="fk_documents_course_owner",
            ondelete="SET NULL (course_id)",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "note_id"],
            ["notes.owner_uid", "notes.id"],
            name="fk_documents_note_owner",
            ondelete="SET NULL (note_id)",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_documents_owner_id"),
        sa.UniqueConstraint(
            "owner_uid", "storage_path", name="uq_documents_owner_storage_path"
        ),
    )
    op.create_table(
        "document_chunks",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("document_id", UUID, nullable=False),
        sa.Column("chunk_index", sa.Integer(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("page_number", sa.Integer(), nullable=True),
        sa.Column("metadata", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("chunk_index >= 0", name="ck_document_chunks_index"),
        sa.CheckConstraint("length(content) > 0", name="ck_document_chunks_content"),
        sa.CheckConstraint(
            "page_number IS NULL OR page_number > 0",
            name="ck_document_chunks_page",
        ),
        sa.CheckConstraint(
            "jsonb_typeof(metadata) = 'object'",
            name="ck_document_chunks_metadata_object",
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "document_id"],
            ["documents.owner_uid", "documents.id"],
            name="fk_document_chunks_document_owner",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("owner_uid", "id", name="uq_document_chunks_owner_id"),
        sa.UniqueConstraint(
            "owner_uid", "document_id", "chunk_index",
            name="uq_document_chunks_position",
        ),
    )
    op.create_table(
        "chunk_embeddings",
        sa.Column("id", UUID, server_default=sa.text("gen_random_uuid()"), nullable=False),
        sa.Column("owner_uid", sa.String(128), nullable=False),
        sa.Column("chunk_id", UUID, nullable=False),
        sa.Column("embedding_model", sa.String(120), nullable=False),
        sa.Column("embedding", Vector(1536), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["owner_uid", "chunk_id"],
            ["document_chunks.owner_uid", "document_chunks.id"],
            name="fk_chunk_embeddings_chunk_owner",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "owner_uid", "chunk_id", "embedding_model",
            name="uq_chunk_embeddings_model",
        ),
    )

    op.create_index("ix_tasks_owner_course", "tasks", ["owner_uid", "course_id"])
    op.create_index("ix_notes_owner_course", "notes", ["owner_uid", "course_id"])
    op.create_index("ix_flashcards_owner_due", "flashcards", ["owner_uid", "due_at"])
    op.create_index(
        "ix_evaluations_owner_scheduled", "evaluations", ["owner_uid", "scheduled_at"]
    )
    op.create_index("ix_events_owner_starts", "events", ["owner_uid", "starts_at"])
    op.create_index(
        "ix_notifications_owner_unread",
        "notifications",
        ["owner_uid", sa.text("created_at DESC")],
        postgresql_where=sa.text("read_at IS NULL"),
    )
    op.create_index(
        "ix_study_sessions_owner_started",
        "study_sessions",
        ["owner_uid", "started_at"],
    )
    op.create_index(
        "ix_ai_insights_owner_active",
        "ai_insights",
        ["owner_uid", sa.text("generated_at DESC")],
        postgresql_where=sa.text("status = 'active'"),
    )
    op.create_index(
        "ix_documents_owner_course", "documents", ["owner_uid", "course_id"]
    )
    op.create_index(
        "ix_documents_owner_note", "documents", ["owner_uid", "note_id"]
    )
    op.create_index(
        "ix_document_chunks_owner_document",
        "document_chunks",
        ["owner_uid", "document_id", "chunk_index"],
    )
    op.create_index(
        "ix_chunk_embeddings_hnsw_cosine",
        "chunk_embeddings",
        ["embedding"],
        postgresql_using="hnsw",
        postgresql_ops={"embedding": "vector_cosine_ops"},
    )

    _create_tenant_policies()


def downgrade() -> None:
    for table_name in (
        "users",
        "learning_profiles",
        "courses",
        "tasks",
        "notes",
        "flashcards",
        "evaluations",
        "events",
        "notifications",
        "study_sessions",
        "gamification",
        "ai_insights",
        "notification_devices",
        "documents",
        "document_chunks",
        "chunk_embeddings",
    ):
        op.execute(
            sa.text(
                f"DROP POLICY IF EXISTS tenant_isolation ON {table_name}"
            )
        )
        op.execute(sa.text(f"ALTER TABLE {table_name} NO FORCE ROW LEVEL SECURITY"))
        op.execute(sa.text(f"ALTER TABLE {table_name} DISABLE ROW LEVEL SECURITY"))

    op.drop_index("ix_chunk_embeddings_hnsw_cosine", table_name="chunk_embeddings")
    op.drop_index("ix_document_chunks_owner_document", table_name="document_chunks")
    op.drop_index("ix_documents_owner_note", table_name="documents")
    op.drop_index("ix_documents_owner_course", table_name="documents")
    op.drop_index("ix_ai_insights_owner_active", table_name="ai_insights")
    op.drop_index("ix_study_sessions_owner_started", table_name="study_sessions")
    op.drop_index("ix_notifications_owner_unread", table_name="notifications")
    op.drop_index("ix_events_owner_starts", table_name="events")
    op.drop_index("ix_evaluations_owner_scheduled", table_name="evaluations")
    op.drop_index("ix_flashcards_owner_due", table_name="flashcards")
    op.drop_index("ix_notes_owner_course", table_name="notes")
    op.drop_index("ix_tasks_owner_course", table_name="tasks")

    for table_name in (
        "chunk_embeddings",
        "document_chunks",
        "documents",
        "notification_devices",
        "ai_insights",
        "gamification",
        "study_sessions",
        "notifications",
        "events",
        "evaluations",
        "flashcards",
        "learning_profiles",
    ):
        op.drop_table(table_name)

    op.drop_constraint("fk_notes_course_owner", "notes", type_="foreignkey")
    op.create_foreign_key(
        "notes_course_id_fkey",
        "notes",
        "courses",
        ["course_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.drop_constraint("fk_tasks_course_owner", "tasks", type_="foreignkey")
    op.create_foreign_key(
        "tasks_course_id_fkey",
        "tasks",
        "courses",
        ["course_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.drop_constraint("uq_notes_owner_id", "notes", type_="unique")
    op.drop_constraint("uq_tasks_owner_id", "tasks", type_="unique")
    op.drop_constraint("uq_courses_owner_id", "courses", type_="unique")
