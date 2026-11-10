"""Timetable entry model – one scheduled session per user/course/slot."""

import enum
from datetime import datetime
from datetime import time as time_type
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Index,
    String,
    Time,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class SeanceType(str, enum.Enum):
    COURS = "COURS"
    TD = "TD"
    TP = "TP"


class TimetableEntry(Base):
    __tablename__ = "timetable_entries"
    __table_args__ = (
        CheckConstraint(
            "heure_debut < heure_fin",
            name="ck_timetable_entries_time_order",
        ),
        CheckConstraint(
            "jour BETWEEN 0 AND 6",
            name="ck_timetable_entries_jour",
        ),
        Index("ix_timetable_entries_owner_jour", "owner_uid", "jour"),
        Index(
            "ix_timetable_entries_owner_cours",
            "owner_uid",
            "course_id",
        ),
    )

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    owner_uid: Mapped[str] = mapped_column(
        ForeignKey("users.firebase_uid", ondelete="CASCADE"), index=True
    )
    course_id: Mapped[UUID] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"), index=True
    )
    jour: Mapped[int] = mapped_column()           # 0 = Monday … 6 = Sunday
    heure_debut: Mapped[time_type] = mapped_column(Time())
    heure_fin: Mapped[time_type] = mapped_column(Time())
    salle: Mapped[str | None] = mapped_column(String(100))
    type_seance: Mapped[SeanceType] = mapped_column(
        SAEnum(SeanceType, name="seancetype"), default=SeanceType.COURS
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # relationships
    owner: Mapped["User"] = relationship(back_populates="timetable_entries")  # type: ignore[name-defined]
    course: Mapped["Course"] = relationship()  # type: ignore[name-defined]
