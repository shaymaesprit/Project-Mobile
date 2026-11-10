import enum
from datetime import datetime
from datetime import time as time_type
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum as SAEnum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    Time,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class CourseType(str, enum.Enum):
    COURS = "COURS"
    TD = "TD"
    TP = "TP"


class Course(Base):
    __tablename__ = "courses"
    __table_args__ = (
        CheckConstraint(
            "(weekday IS NULL AND start_time IS NULL AND end_time IS NULL) OR "
            "(weekday BETWEEN 0 AND 6 AND start_time IS NOT NULL "
            "AND end_time IS NOT NULL AND start_time < end_time)",
            name="ck_courses_schedule",
        ),
        CheckConstraint(
            "difficulte_percue IS NULL OR (difficulte_percue BETWEEN 1 AND 5)",
            name="ck_courses_difficulte_percue",
        ),
        Index("ix_courses_owner_title", "owner_uid", "title"),
        Index(
            "ix_courses_owner_schedule",
            "owner_uid",
            "weekday",
            "start_time",
        ),
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
    weekday: Mapped[int | None] = mapped_column()
    start_time: Mapped[time_type | None] = mapped_column(Time())
    end_time: Mapped[time_type | None] = mapped_column(Time())
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Extended schedule fields
    type_cours: Mapped[CourseType | None] = mapped_column(
        SAEnum(CourseType, name="course_type"), nullable=True
    )
    semestre: Mapped[str | None] = mapped_column(String(20), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    coefficient: Mapped[float | None] = mapped_column(Float, nullable=True)
    difficulte_percue: Mapped[int | None] = mapped_column(Integer, nullable=True)

    owner: Mapped["User"] = relationship(back_populates="courses")
