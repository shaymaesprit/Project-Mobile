-- StudyMate PostgreSQL schema bootstrap/reference (PostgreSQL 16+).
-- Run against an empty database, or review and convert into an Alembic
-- migration before applying to an existing environment.
--
-- The embedding dimension is currently 1536. It must match the selected
-- embedding model before this schema is applied.
--
-- Runtime requests must set transaction-local app.firebase_uid to the UID
-- from a verified Firebase ID token. RLS intentionally fails closed if unset.

BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS users (
    firebase_uid varchar(128) PRIMARY KEY,
    email varchar(320),
    display_name varchar(160),
    photo_url text,
    locale varchar(20),
    timezone varchar(64),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS courses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    title varchar(160) NOT NULL,
    code varchar(40),
    professor varchar(160),
    room varchar(100),
    color varchar(16),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_courses_owner_id UNIQUE (owner_uid, id)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_courses_owner_id'
          AND conrelid = 'courses'::regclass
    ) THEN
        ALTER TABLE courses
            ADD CONSTRAINT uq_courses_owner_id UNIQUE (owner_uid, id);
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS tasks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    course_id uuid,
    title varchar(200) NOT NULL,
    description text,
    priority varchar(10) NOT NULL DEFAULT 'medium'
        CHECK (priority IN ('low', 'medium', 'high')),
    deadline timestamptz,
    is_completed boolean NOT NULL DEFAULT false,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_tasks_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT fk_tasks_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id)
);

CREATE TABLE IF NOT EXISTS notes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    course_id uuid,
    title varchar(200) NOT NULL,
    content text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_notes_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT fk_notes_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_notes_owner_id'
          AND conrelid = 'notes'::regclass
    ) THEN
        ALTER TABLE notes
            ADD CONSTRAINT uq_notes_owner_id UNIQUE (owner_uid, id);
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS learning_profiles (
    owner_uid varchar(128) PRIMARY KEY
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    preferred_learning_style varchar(32)
        CHECK (preferred_learning_style IN
            ('visual', 'auditory', 'reading', 'kinesthetic', 'mixed')),
    daily_study_goal_minutes integer NOT NULL DEFAULT 60
        CHECK (daily_study_goal_minutes BETWEEN 0 AND 1440),
    preferences jsonb NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(preferences) = 'object'),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS flashcard_decks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    course_id uuid,
    title varchar(200) NOT NULL,
    description text,
    source varchar(24) NOT NULL DEFAULT 'manual'
        CHECK (source IN ('manual', 'ai_generated')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_flashcard_decks_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT fk_flashcard_decks_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id)
);

CREATE TABLE IF NOT EXISTS flashcards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    deck_id uuid,
    course_id uuid,
    question text NOT NULL,
    answer text NOT NULL,
    due_at timestamptz,
    interval_days integer NOT NULL DEFAULT 0 CHECK (interval_days >= 0),
    ease_factor numeric(4, 2) NOT NULL DEFAULT 2.50
        CHECK (ease_factor >= 1.30),
    repetitions integer NOT NULL DEFAULT 0 CHECK (repetitions >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_flashcards_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT fk_flashcards_deck_owner FOREIGN KEY (owner_uid, deck_id)
        REFERENCES flashcard_decks(owner_uid, id) ON DELETE CASCADE,
    CONSTRAINT fk_flashcards_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id)
);

CREATE TABLE IF NOT EXISTS flashcard_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    flashcard_id uuid NOT NULL,
    is_correct boolean NOT NULL,
    reviewed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_flashcard_reviews_card_owner
        FOREIGN KEY (owner_uid, flashcard_id)
        REFERENCES flashcards(owner_uid, id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS evaluations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    course_id uuid,
    title varchar(200) NOT NULL,
    evaluation_type varchar(32) NOT NULL DEFAULT 'other'
        CHECK (evaluation_type IN
            ('exam', 'quiz', 'assignment', 'presentation', 'other')),
    scheduled_at timestamptz,
    score numeric(8, 2),
    max_score numeric(8, 2),
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (score IS NULL OR score >= 0),
    CHECK (max_score IS NULL OR max_score > 0),
    CHECK (score IS NULL OR max_score IS NULL OR score <= max_score),
    CONSTRAINT uq_evaluations_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT fk_evaluations_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id)
);

CREATE TABLE IF NOT EXISTS events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    course_id uuid,
    title varchar(200) NOT NULL,
    description text,
    event_type varchar(32) NOT NULL DEFAULT 'other'
        CHECK (event_type IN
            ('class', 'study', 'exam', 'deadline', 'personal', 'other')),
    starts_at timestamptz NOT NULL,
    ends_at timestamptz,
    location varchar(200),
    latitude double precision,
    longitude double precision,
    status varchar(16) NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned', 'done', 'cancelled')),
    reminder_offsets jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at IS NULL OR ends_at >= starts_at),
    CONSTRAINT uq_events_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT fk_events_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id)
);

CREATE TABLE IF NOT EXISTS notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    notification_type varchar(32) NOT NULL,
    title varchar(200) NOT NULL,
    body text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(payload) = 'object'),
    scheduled_at timestamptz,
    sent_at timestamptz,
    read_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_notifications_owner_id UNIQUE (owner_uid, id)
);

CREATE TABLE IF NOT EXISTS study_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    course_id uuid,
    started_at timestamptz NOT NULL DEFAULT now(),
    ended_at timestamptz,
    duration_seconds integer CHECK (duration_seconds >= 0),
    focus_rating smallint CHECK (focus_rating BETWEEN 1 AND 5),
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (ended_at IS NULL OR ended_at >= started_at),
    CONSTRAINT uq_study_sessions_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT fk_study_sessions_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id)
);

CREATE TABLE IF NOT EXISTS gamification (
    owner_uid varchar(128) PRIMARY KEY
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    points bigint NOT NULL DEFAULT 0 CHECK (points >= 0),
    level integer NOT NULL DEFAULT 1 CHECK (level >= 1),
    current_streak_days integer NOT NULL DEFAULT 0
        CHECK (current_streak_days >= 0),
    longest_streak_days integer NOT NULL DEFAULT 0
        CHECK (longest_streak_days >= current_streak_days),
    last_study_date date,
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_insights (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    insight_type varchar(40) NOT NULL,
    title varchar(200) NOT NULL,
    body text NOT NULL,
    status varchar(16) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'dismissed', 'expired')),
    evidence jsonb NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(evidence) = 'object'),
    generated_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz,
    CONSTRAINT uq_ai_insights_owner_id UNIQUE (owner_uid, id)
);

CREATE TABLE IF NOT EXISTS ai_recommendations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    title varchar(200) NOT NULL,
    description text NOT NULL,
    category varchar(32) NOT NULL,
    priority varchar(16) NOT NULL DEFAULT 'medium'
        CHECK (priority IN ('low', 'medium', 'high')),
    reason text,
    suggested_action text,
    source varchar(16) NOT NULL DEFAULT 'ai'
        CHECK (source IN ('ai', 'rules')),
    status varchar(16) NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'modified', 'rejected')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_ai_recommendations_owner_id UNIQUE (owner_uid, id)
);

CREATE INDEX IF NOT EXISTS ix_ai_recommendations_owner_created
    ON ai_recommendations (owner_uid, created_at);

CREATE TABLE IF NOT EXISTS notification_devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    fcm_token text NOT NULL UNIQUE,
    platform varchar(16) NOT NULL
        CHECK (platform IN ('android', 'ios', 'web')),
    device_name varchar(160),
    last_seen_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_notification_devices_owner_id UNIQUE (owner_uid, id)
);

CREATE TABLE IF NOT EXISTS documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    course_id uuid,
    note_id uuid,
    title varchar(240) NOT NULL,
    storage_path text,
    mime_type varchar(127),
    file_size_bytes bigint CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
    sha256 char(64),
    processing_status varchar(16) NOT NULL DEFAULT 'pending'
        CHECK (processing_status IN
            ('pending', 'processing', 'ready', 'failed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_documents_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT uq_documents_owner_storage_path UNIQUE (owner_uid, storage_path),
    CONSTRAINT fk_documents_course_owner FOREIGN KEY (owner_uid, course_id)
        REFERENCES courses(owner_uid, id) ON DELETE SET NULL (course_id),
    CONSTRAINT fk_documents_note_owner FOREIGN KEY (owner_uid, note_id)
        REFERENCES notes(owner_uid, id) ON DELETE SET NULL (note_id)
);

CREATE TABLE IF NOT EXISTS document_chunks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    document_id uuid NOT NULL,
    chunk_index integer NOT NULL CHECK (chunk_index >= 0),
    content text NOT NULL CHECK (length(content) > 0),
    page_number integer CHECK (page_number IS NULL OR page_number > 0),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb
        CHECK (jsonb_typeof(metadata) = 'object'),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_document_chunks_owner_id UNIQUE (owner_uid, id),
    CONSTRAINT uq_document_chunks_position UNIQUE
        (owner_uid, document_id, chunk_index),
    CONSTRAINT fk_document_chunks_document_owner
        FOREIGN KEY (owner_uid, document_id)
        REFERENCES documents(owner_uid, id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS chunk_embeddings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    chunk_id uuid NOT NULL,
    embedding_model varchar(120) NOT NULL,
    embedding vector(1536) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_chunk_embeddings_model
        UNIQUE (owner_uid, chunk_id, embedding_model),
    CONSTRAINT fk_chunk_embeddings_chunk_owner
        FOREIGN KEY (owner_uid, chunk_id)
        REFERENCES document_chunks(owner_uid, id) ON DELETE CASCADE
);

-- Existing installations already have these tables from Alembic 0001.
-- Add tenant-aware candidate keys and FKs without dropping their existing
-- primary keys or simple course FKs.
DO $$
DECLARE
    table_name text;
    constraint_name text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'courses', 'tasks', 'notes'
    ] LOOP
        constraint_name := 'uq_' || table_name || '_owner_id';
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = constraint_name
              AND conrelid = to_regclass(table_name)
        ) THEN
            EXECUTE format(
                'ALTER TABLE %I ADD CONSTRAINT %I UNIQUE (owner_uid, id)',
                table_name, constraint_name
            );
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_tasks_course_owner'
          AND conrelid = 'tasks'::regclass
    ) THEN
        ALTER TABLE tasks
            ADD CONSTRAINT fk_tasks_course_owner
            FOREIGN KEY (owner_uid, course_id)
            REFERENCES courses(owner_uid, id)
            ON DELETE SET NULL (course_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_notes_course_owner'
          AND conrelid = 'notes'::regclass
    ) THEN
        ALTER TABLE notes
            ADD CONSTRAINT fk_notes_course_owner
            FOREIGN KEY (owner_uid, course_id)
            REFERENCES courses(owner_uid, id)
            ON DELETE SET NULL (course_id);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS ix_courses_owner_title
    ON courses (owner_uid, title);
CREATE INDEX IF NOT EXISTS ix_tasks_owner_status_deadline
    ON tasks (owner_uid, is_completed, deadline);
CREATE INDEX IF NOT EXISTS ix_notes_owner_updated
    ON notes (owner_uid, updated_at DESC);
CREATE INDEX IF NOT EXISTS ix_tasks_owner_course
    ON tasks (owner_uid, course_id);
CREATE INDEX IF NOT EXISTS ix_notes_owner_course
    ON notes (owner_uid, course_id);
CREATE INDEX IF NOT EXISTS ix_flashcards_owner_due
    ON flashcards (owner_uid, due_at);
CREATE INDEX IF NOT EXISTS ix_flashcards_owner_course
    ON flashcards (owner_uid, course_id);
CREATE INDEX IF NOT EXISTS ix_flashcard_decks_owner_created
    ON flashcard_decks (owner_uid, created_at);
CREATE INDEX IF NOT EXISTS ix_flashcards_owner_deck
    ON flashcards (owner_uid, deck_id);
CREATE INDEX IF NOT EXISTS ix_flashcard_reviews_owner_reviewed
    ON flashcard_reviews (owner_uid, reviewed_at);
CREATE INDEX IF NOT EXISTS ix_flashcard_reviews_owner_card
    ON flashcard_reviews (owner_uid, flashcard_id);
CREATE INDEX IF NOT EXISTS ix_evaluations_owner_scheduled
    ON evaluations (owner_uid, scheduled_at);
CREATE INDEX IF NOT EXISTS ix_evaluations_owner_course
    ON evaluations (owner_uid, course_id);
CREATE INDEX IF NOT EXISTS ix_events_owner_starts
    ON events (owner_uid, starts_at);
CREATE INDEX IF NOT EXISTS ix_events_owner_course
    ON events (owner_uid, course_id);
CREATE INDEX IF NOT EXISTS ix_notifications_owner_unread
    ON notifications (owner_uid, created_at DESC)
    WHERE read_at IS NULL;
CREATE INDEX IF NOT EXISTS ix_study_sessions_owner_started
    ON study_sessions (owner_uid, started_at DESC);
CREATE INDEX IF NOT EXISTS ix_ai_insights_owner_active
    ON ai_insights (owner_uid, generated_at DESC)
    WHERE status = 'active';
CREATE INDEX IF NOT EXISTS ix_documents_owner_course
    ON documents (owner_uid, course_id);
CREATE INDEX IF NOT EXISTS ix_documents_owner_note
    ON documents (owner_uid, note_id);
CREATE INDEX IF NOT EXISTS ix_document_chunks_owner_document
    ON document_chunks (owner_uid, document_id, chunk_index);
CREATE INDEX IF NOT EXISTS ix_chunk_embeddings_hnsw_cosine
    ON chunk_embeddings USING hnsw (embedding vector_cosine_ops);

CREATE TABLE IF NOT EXISTS event_reminders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_uid varchar(128) NOT NULL
        REFERENCES users(firebase_uid) ON DELETE CASCADE,
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    offset_minutes integer NOT NULL CHECK (offset_minutes >= 0),
    remind_at timestamptz NOT NULL,
    sent_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_event_reminders_offset UNIQUE (event_id, offset_minutes)
);
CREATE INDEX IF NOT EXISTS ix_event_reminders_due
    ON event_reminders (remind_at) WHERE sent_at IS NULL;

-- RLS is defense in depth; the API must still verify Firebase tokens and
-- scope queries. Set the verified UID transaction-locally on every request.
DO $$
DECLARE
    table_name text;
    owner_column text;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'users', 'learning_profiles', 'courses', 'tasks', 'notes',
        'flashcards', 'flashcard_decks', 'flashcard_reviews',
        'evaluations', 'events', 'notifications',
        'study_sessions', 'gamification', 'ai_insights', 'ai_recommendations',
        'notification_devices', 'documents', 'document_chunks',
        'chunk_embeddings', 'event_reminders'
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
            'DROP POLICY IF EXISTS %I ON %I',
            'tenant_isolation', table_name
        );
        EXECUTE format(
            'CREATE POLICY %I ON %I USING (%I = '
            'NULLIF(current_setting(''app.firebase_uid'', true), '''')) '
            'WITH CHECK (%I = '
            'NULLIF(current_setting(''app.firebase_uid'', true), ''''))',
            'tenant_isolation', table_name, owner_column, owner_column
        );
    END LOOP;
END
$$;

-- The reminder scheduler runs without a user: it may only READ the due queue.
DROP POLICY IF EXISTS scheduler_read_due ON event_reminders;
CREATE POLICY scheduler_read_due ON event_reminders FOR SELECT
    USING (current_setting('app.scheduler', true) = 'on');

COMMIT;
