from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class Course(Base):
    __tablename__ = "courses"
    __table_args__ = (
        Index("ix_courses_owner_title", "owner_uid", "title"),
        UniqueConstraint("owner_uid", "id", name="uq_courses_owner_id"),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(160))
    code: Mapped[str | None] = mapped_column(String(40))
    professor: Mapped[str | None] = mapped_column(String(160))
    room: Mapped[str | None] = mapped_column(String(100))
    color: Mapped[str | None] = mapped_column(String(16))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    owner: Mapped["User"] = relationship(back_populates="courses")
