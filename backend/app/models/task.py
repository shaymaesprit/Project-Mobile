from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class StudyTask(Base):
    __tablename__ = "tasks"
    __table_args__ = (
        CheckConstraint(
            "priority IN ('low', 'medium', 'high')", name="ck_tasks_priority"
        ),
        CheckConstraint(
            "status IN ('pending', 'in_progress', 'completed')", name="ck_tasks_status"
        ),
        CheckConstraint(
            "(status = 'completed') = is_completed", name="ck_tasks_status_completed"
        ),
        Index("ix_tasks_owner_completed_deadline", "owner_uid", "is_completed", "deadline"),
        Index("ix_tasks_owner_course", "owner_uid", "course_id"),
        UniqueConstraint("owner_uid", "id", name="uq_tasks_owner_id"),
        ForeignKeyConstraint(
            ["owner_uid", "course_id"],
            ["courses.owner_uid", "courses.id"],
            name="fk_tasks_course_owner",
            ondelete="SET NULL (course_id)",
        ).ddl_if(dialect="postgresql"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), index=True
    )
    course_id: Mapped[UUID | None] = mapped_column(index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(Text)
    priority: Mapped[str] = mapped_column(String(10), default="medium")
    deadline: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_completed: Mapped[bool] = mapped_column(default=False)
    # Toujours cohérent avec is_completed (contrainte ck_tasks_status_completed).
    status: Mapped[str] = mapped_column(
        String(16), default="pending", server_default="pending"
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    owner: Mapped["User"] = relationship(back_populates="tasks")
