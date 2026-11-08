from datetime import date, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    BigInteger,
    CHAR,
    CheckConstraint,
    Date,
    DateTime,
    Float,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    JSON,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base

JSON_OBJECT = JSON().with_variant(JSONB(), "postgresql")
JSON_ARRAY = JSON().with_variant(JSONB(), "postgresql")


def _course_owner_fk(table_name: str, column_name: str = "course_id"):
    return ForeignKeyConstraint(
        ["owner_uid", column_name],
        ["courses.owner_uid", "courses.id"],
        name=f"fk_{table_name}_course_owner",
        ondelete=f"SET NULL ({column_name})",
    ).ddl_if(dialect="postgresql")


class LearningProfile(Base):
    __tablename__ = "learning_profiles"

    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), primary_key=True
    )
    preferred_learning_style: Mapped[str | None] = mapped_column(String(32))
    study_level: Mapped[str | None] = mapped_column(String(80))
    specialty: Mapped[str | None] = mapped_column(String(160))
    academic_goals: Mapped[list[str]] = mapped_column(
        JSON_ARRAY, nullable=False, default=list, server_default=text("'[]'")
    )
    daily_study_goal_minutes: Mapped[int] = mapped_column(
        Integer, nullable=False, default=60, server_default=text("60")
    )
    preferences: Mapped[dict] = mapped_column(
        JSON_OBJECT, nullable=False, default=dict, server_default=text("'{}'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    __table_args__ = (
        CheckConstraint(
            "preferred_learning_style IS NULL OR preferred_learning_style IN "
            "('visual', 'auditory', 'reading', 'kinesthetic', 'mixed')",
            name="ck_learning_profiles_style",
        ),
        CheckConstraint(
            "daily_study_goal_minutes BETWEEN 0 AND 1440",
            name="ck_learning_profiles_goal",
        ),
        CheckConstraint(
            "jsonb_typeof(academic_goals) = 'array'",
            name="ck_learning_profiles_academic_goals_array",
        ).ddl_if(dialect="postgresql"),
        CheckConstraint(
            "jsonb_typeof(preferences) = 'object'",
            name="ck_learning_profiles_preferences_object",
        ).ddl_if(dialect="postgresql"),
    )


class FlashcardDeck(Base):
    __tablename__ = "flashcard_decks"
    __table_args__ = (
        UniqueConstraint("owner_uid", "id", name="uq_flashcard_decks_owner_id"),
        _course_owner_fk("flashcard_decks"),
        CheckConstraint(
            "source IN ('manual', 'ai_generated')",
            name="ck_flashcard_decks_source",
        ),
        Index("ix_flashcard_decks_owner_created", "owner_uid", "created_at"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    course_id: Mapped[UUID | None] = mapped_column()
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    source: Mapped[str] = mapped_column(
        String(24), nullable=False, default="manual", server_default=text("'manual'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Flashcard(Base):
    __tablename__ = "flashcards"
    __table_args__ = (
        CheckConstraint("interval_days >= 0", name="ck_flashcards_interval"),
        CheckConstraint("ease_factor >= 1.30", name="ck_flashcards_ease"),
        CheckConstraint("repetitions >= 0", name="ck_flashcards_repetitions"),
        UniqueConstraint("owner_uid", "id", name="uq_flashcards_owner_id"),
        _course_owner_fk("flashcards"),
        ForeignKeyConstraint(
            ["owner_uid", "deck_id"],
            ["flashcard_decks.owner_uid", "flashcard_decks.id"],
            name="fk_flashcards_deck_owner",
            ondelete="CASCADE",
        ),
        Index("ix_flashcards_owner_due", "owner_uid", "due_at"),
        Index("ix_flashcards_owner_deck", "owner_uid", "deck_id"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    deck_id: Mapped[UUID | None] = mapped_column()
    course_id: Mapped[UUID | None] = mapped_column()
    question: Mapped[str] = mapped_column(Text, nullable=False)
    answer: Mapped[str] = mapped_column(Text, nullable=False)
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    interval_days: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0")
    )
    ease_factor: Mapped[Decimal] = mapped_column(
        Numeric(4, 2), nullable=False, default=Decimal("2.50"), server_default=text("2.50")
    )
    repetitions: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class FlashcardReview(Base):
    __tablename__ = "flashcard_reviews"
    __table_args__ = (
        ForeignKeyConstraint(
            ["owner_uid", "flashcard_id"],
            ["flashcards.owner_uid", "flashcards.id"],
            name="fk_flashcard_reviews_card_owner",
            ondelete="CASCADE",
        ),
        Index("ix_flashcard_reviews_owner_reviewed", "owner_uid", "reviewed_at"),
        Index("ix_flashcard_reviews_owner_card", "owner_uid", "flashcard_id"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    flashcard_id: Mapped[UUID] = mapped_column(nullable=False)
    is_correct: Mapped[bool] = mapped_column(nullable=False)
    reviewed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Evaluation(Base):
    __tablename__ = "evaluations"
    __table_args__ = (
        CheckConstraint(
            "evaluation_type IN ('exam', 'quiz', 'assignment', 'presentation', 'other')",
            name="ck_evaluations_type",
        ),
        CheckConstraint("score IS NULL OR score >= 0", name="ck_evaluations_score"),
        CheckConstraint(
            "max_score IS NULL OR max_score > 0", name="ck_evaluations_max_score"
        ),
        CheckConstraint(
            "score IS NULL OR max_score IS NULL OR score <= max_score",
            name="ck_evaluations_score_within_max",
        ),
        UniqueConstraint("owner_uid", "id", name="uq_evaluations_owner_id"),
        _course_owner_fk("evaluations"),
        Index("ix_evaluations_owner_scheduled", "owner_uid", "scheduled_at"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    course_id: Mapped[UUID | None] = mapped_column()
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    evaluation_type: Mapped[str] = mapped_column(
        String(32), nullable=False, default="other", server_default=text("'other'")
    )
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    score: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))
    max_score: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class StudyEvent(Base):
    __tablename__ = "events"
    __table_args__ = (
        CheckConstraint(
            "event_type IN ('class', 'study', 'exam', 'deadline', 'personal', 'other')",
            name="ck_events_type",
        ),
        CheckConstraint(
            "ends_at IS NULL OR ends_at >= starts_at", name="ck_events_time_range"
        ),
        CheckConstraint(
            "status IN ('planned', 'done', 'cancelled')", name="ck_events_status"
        ),
        UniqueConstraint("owner_uid", "id", name="uq_events_owner_id"),
        _course_owner_fk("events"),
        Index("ix_events_owner_starts", "owner_uid", "starts_at"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    course_id: Mapped[UUID | None] = mapped_column()
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    event_type: Mapped[str] = mapped_column(
        String(32), nullable=False, default="other", server_default=text("'other'")
    )
    starts_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    location: Mapped[str | None] = mapped_column(String(200))
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="planned", server_default=text("'planned'")
    )
    # Minutes avant le début auxquelles envoyer un rappel (ex. [1440, 60]).
    reminder_offsets: Mapped[list] = mapped_column(
        JSON_ARRAY, nullable=False, default=list, server_default=text("'[]'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class EventReminder(Base):
    """Un rappel planifié pour un événement (une ligne par décalage)."""

    __tablename__ = "event_reminders"
    __table_args__ = (
        UniqueConstraint("event_id", "offset_minutes", name="uq_event_reminders_offset"),
        CheckConstraint("offset_minutes >= 0", name="ck_event_reminders_offset"),
        Index(
            "ix_event_reminders_due",
            "remind_at",
            postgresql_where=text("sent_at IS NULL"),
            sqlite_where=text("sent_at IS NULL"),
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    event_id: Mapped[UUID] = mapped_column(
        ForeignKey("events.id", ondelete="CASCADE"), nullable=False
    )
    offset_minutes: Mapped[int] = mapped_column(Integer, nullable=False)
    remind_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (
        UniqueConstraint("owner_uid", "id", name="uq_notifications_owner_id"),
        Index(
            "ix_notifications_owner_unread",
            "owner_uid",
            text("created_at DESC"),
            postgresql_where=text("read_at IS NULL"),
            sqlite_where=text("read_at IS NULL"),
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    notification_type: Mapped[str] = mapped_column(String(32), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    payload: Mapped[dict] = mapped_column(
        JSON_OBJECT, nullable=False, default=dict, server_default=text("'{}'")
    )
    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class StudySession(Base):
    __tablename__ = "study_sessions"
    __table_args__ = (
        CheckConstraint(
            "duration_seconds IS NULL OR duration_seconds >= 0",
            name="ck_study_sessions_duration",
        ),
        CheckConstraint(
            "focus_rating IS NULL OR focus_rating BETWEEN 1 AND 5",
            name="ck_study_sessions_focus",
        ),
        CheckConstraint(
            "ended_at IS NULL OR ended_at >= started_at",
            name="ck_study_sessions_time_range",
        ),
        UniqueConstraint("owner_uid", "id", name="uq_study_sessions_owner_id"),
        _course_owner_fk("study_sessions"),
        Index("ix_study_sessions_owner_started", "owner_uid", "started_at"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    course_id: Mapped[UUID | None] = mapped_column()
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_seconds: Mapped[int | None] = mapped_column(Integer)
    focus_rating: Mapped[int | None] = mapped_column(SmallInteger)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Gamification(Base):
    __tablename__ = "gamification"
    __table_args__ = (
        CheckConstraint("points >= 0", name="ck_gamification_points"),
        CheckConstraint("level >= 1", name="ck_gamification_level"),
        CheckConstraint(
            "current_streak_days >= 0", name="ck_gamification_current_streak"
        ),
        CheckConstraint(
            "longest_streak_days >= current_streak_days",
            name="ck_gamification_longest_streak",
        ),
    )

    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), primary_key=True
    )
    points: Mapped[int] = mapped_column(
        BigInteger, nullable=False, default=0, server_default=text("0")
    )
    level: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1, server_default=text("1")
    )
    current_streak_days: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0")
    )
    longest_streak_days: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default=text("0")
    )
    last_study_date: Mapped[date | None] = mapped_column(Date)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class AIInsight(Base):
    __tablename__ = "ai_insights"
    __table_args__ = (
        CheckConstraint(
            "status IN ('active', 'dismissed', 'expired')",
            name="ck_ai_insights_status",
        ),
        UniqueConstraint("owner_uid", "id", name="uq_ai_insights_owner_id"),
        Index(
            "ix_ai_insights_owner_active",
            "owner_uid",
            text("generated_at DESC"),
            postgresql_where=text("status = 'active'"),
            sqlite_where=text("status = 'active'"),
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    insight_type: Mapped[str] = mapped_column(String(40), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="active", server_default=text("'active'")
    )
    evidence: Mapped[dict] = mapped_column(
        JSON_OBJECT, nullable=False, default=dict, server_default=text("'{}'")
    )
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AIRecommendation(Base):
    __tablename__ = "ai_recommendations"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'accepted', 'modified', 'rejected')",
            name="ck_ai_recommendations_status",
        ),
        CheckConstraint(
            "priority IN ('low', 'medium', 'high')",
            name="ck_ai_recommendations_priority",
        ),
        CheckConstraint(
            "source IN ('ai', 'rules')", name="ck_ai_recommendations_source"
        ),
        UniqueConstraint("owner_uid", "id", name="uq_ai_recommendations_owner_id"),
        Index("ix_ai_recommendations_owner_created", "owner_uid", "created_at"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(String(32), nullable=False)
    priority: Mapped[str] = mapped_column(
        String(16), nullable=False, default="medium", server_default=text("'medium'")
    )
    reason: Mapped[str | None] = mapped_column(Text)
    suggested_action: Mapped[str | None] = mapped_column(Text)
    source: Mapped[str] = mapped_column(
        String(16), nullable=False, default="ai", server_default=text("'ai'")
    )
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="pending", server_default=text("'pending'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class NotificationDevice(Base):
    __tablename__ = "notification_devices"
    __table_args__ = (
        UniqueConstraint("owner_uid", "id", name="uq_notification_devices_owner_id"),
        UniqueConstraint("fcm_token", name="uq_notification_devices_fcm_token"),
        CheckConstraint(
            "platform IN ('android', 'ios', 'web')",
            name="ck_notification_devices_platform",
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    fcm_token: Mapped[str] = mapped_column(Text, nullable=False)
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    device_name: Mapped[str | None] = mapped_column(String(160))
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Document(Base):
    __tablename__ = "documents"
    __table_args__ = (
        CheckConstraint(
            "file_size_bytes IS NULL OR file_size_bytes >= 0",
            name="ck_documents_file_size",
        ),
        CheckConstraint(
            "processing_status IN ('pending', 'processing', 'ready', 'failed')",
            name="ck_documents_processing_status",
        ),
        UniqueConstraint("owner_uid", "id", name="uq_documents_owner_id"),
        UniqueConstraint(
            "owner_uid", "storage_path", name="uq_documents_owner_storage_path"
        ),
        _course_owner_fk("documents"),
        ForeignKeyConstraint(
            ["owner_uid", "note_id"],
            ["notes.owner_uid", "notes.id"],
            name="fk_documents_note_owner",
            ondelete="SET NULL (note_id)",
        ).ddl_if(dialect="postgresql"),
        Index("ix_documents_owner_course", "owner_uid", "course_id"),
        Index("ix_documents_owner_note", "owner_uid", "note_id"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    course_id: Mapped[UUID | None] = mapped_column()
    note_id: Mapped[UUID | None] = mapped_column()
    title: Mapped[str] = mapped_column(String(240), nullable=False)
    storage_path: Mapped[str | None] = mapped_column(Text)
    mime_type: Mapped[str | None] = mapped_column(String(127))
    file_size_bytes: Mapped[int | None] = mapped_column(BigInteger)
    sha256: Mapped[str | None] = mapped_column(CHAR(64))
    processing_status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="pending", server_default=text("'pending'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class DocumentChunk(Base):
    __tablename__ = "document_chunks"
    __table_args__ = (
        CheckConstraint("chunk_index >= 0", name="ck_document_chunks_index"),
        CheckConstraint("length(content) > 0", name="ck_document_chunks_content"),
        CheckConstraint(
            "page_number IS NULL OR page_number > 0",
            name="ck_document_chunks_page",
        ),
        CheckConstraint(
            "jsonb_typeof(metadata) = 'object'",
            name="ck_document_chunks_metadata_object",
        ).ddl_if(dialect="postgresql"),
        UniqueConstraint("owner_uid", "id", name="uq_document_chunks_owner_id"),
        UniqueConstraint(
            "owner_uid", "document_id", "chunk_index",
            name="uq_document_chunks_position",
        ),
        ForeignKeyConstraint(
            ["owner_uid", "document_id"],
            ["documents.owner_uid", "documents.id"],
            name="fk_document_chunks_document_owner",
            ondelete="CASCADE",
        ),
        Index(
            "ix_document_chunks_owner_document",
            "owner_uid",
            "document_id",
            "chunk_index",
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    document_id: Mapped[UUID] = mapped_column(nullable=False)
    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    page_number: Mapped[int | None] = mapped_column(Integer)
    metadata_: Mapped[dict] = mapped_column(
        "metadata", JSON_OBJECT, nullable=False, default=dict, server_default=text("'{}'")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class ChunkEmbedding(Base):
    __tablename__ = "chunk_embeddings"
    __table_args__ = (
        UniqueConstraint(
            "owner_uid", "chunk_id", "embedding_model",
            name="uq_chunk_embeddings_model",
        ),
        ForeignKeyConstraint(
            ["owner_uid", "chunk_id"],
            ["document_chunks.owner_uid", "document_chunks.id"],
            name="fk_chunk_embeddings_chunk_owner",
            ondelete="CASCADE",
        ),
        Index(
            "ix_chunk_embeddings_hnsw_cosine",
            "embedding",
            postgresql_using="hnsw",
            postgresql_ops={"embedding": "vector_cosine_ops"},
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), nullable=False
    )
    chunk_id: Mapped[UUID] = mapped_column(nullable=False)
    embedding_model: Mapped[str] = mapped_column(String(120), nullable=False)
    embedding: Mapped[list[float]] = mapped_column(Vector(1536), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
