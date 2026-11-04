"""Create Firebase-owned users, courses, tasks, and notes.

Revision ID: 0001_initial
Revises:
"""
from typing import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")
    op.create_table(
        "users",
        sa.Column("firebase_uid", sa.String(length=128), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=True),
        sa.Column("display_name", sa.String(length=160), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("firebase_uid"),
    )
    op.create_table(
        "courses",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("owner_uid", sa.String(length=128), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("code", sa.String(length=40), nullable=True),
        sa.Column("professor", sa.String(length=160), nullable=True),
        sa.Column("room", sa.String(length=100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_courses_owner_uid", "courses", ["owner_uid"])
    op.create_index("ix_courses_owner_title", "courses", ["owner_uid", "title"])
    op.create_table(
        "tasks",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("owner_uid", sa.String(length=128), nullable=False),
        sa.Column("course_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("priority", sa.String(length=10), nullable=False),
        sa.Column("deadline", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_completed", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("priority IN ('low', 'medium', 'high')", name="ck_tasks_priority"),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_tasks_course_id", "tasks", ["course_id"])
    op.create_index("ix_tasks_owner_uid", "tasks", ["owner_uid"])
    op.create_index("ix_tasks_owner_completed_deadline", "tasks", ["owner_uid", "is_completed", "deadline"])
    op.create_table(
        "notes",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("owner_uid", sa.String(length=128), nullable=False),
        sa.Column("course_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["course_id"], ["courses.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["owner_uid"], ["users.firebase_uid"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_notes_course_id", "notes", ["course_id"])
    op.create_index("ix_notes_owner_uid", "notes", ["owner_uid"])
    op.create_index("ix_notes_owner_updated", "notes", ["owner_uid", "updated_at"])


def downgrade() -> None:
    op.drop_index("ix_notes_owner_updated", table_name="notes")
    op.drop_index("ix_notes_owner_uid", table_name="notes")
    op.drop_index("ix_notes_course_id", table_name="notes")
    op.drop_table("notes")
    op.drop_index("ix_tasks_owner_completed_deadline", table_name="tasks")
    op.drop_index("ix_tasks_owner_uid", table_name="tasks")
    op.drop_index("ix_tasks_course_id", table_name="tasks")
    op.drop_table("tasks")
    op.drop_index("ix_courses_owner_title", table_name="courses")
    op.drop_index("ix_courses_owner_uid", table_name="courses")
    op.drop_table("courses")
    op.drop_table("users")
