from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.timetable import TimetableEntry


class TimetableRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_owner(
        self,
        owner_uid: str,
        jour: int | None = None,
        course_id: UUID | None = None,
    ) -> list[TimetableEntry]:
        stmt = select(TimetableEntry).where(
            TimetableEntry.owner_uid == owner_uid
        )
        if jour is not None:
            stmt = stmt.where(TimetableEntry.jour == jour)
        if course_id is not None:
            stmt = stmt.where(TimetableEntry.course_id == course_id)
        return list(
            self._db.scalars(
                stmt.order_by(TimetableEntry.jour, TimetableEntry.heure_debut)
            )
        )

    def get_for_owner(
        self, entry_id: UUID, owner_uid: str
    ) -> TimetableEntry | None:
        return self._db.scalar(
            select(TimetableEntry).where(
                TimetableEntry.id == entry_id,
                TimetableEntry.owner_uid == owner_uid,
            )
        )

    def has_overlap(
        self,
        owner_uid: str,
        jour: int,
        heure_debut,
        heure_fin,
        exclude_id: UUID | None = None,
    ) -> bool:
        stmt = select(TimetableEntry.id).where(
            TimetableEntry.owner_uid == owner_uid,
            TimetableEntry.jour == jour,
            TimetableEntry.heure_debut < heure_fin,
            TimetableEntry.heure_fin > heure_debut,
        )
        if exclude_id is not None:
            stmt = stmt.where(TimetableEntry.id != exclude_id)
        return self._db.scalar(stmt.limit(1)) is not None

    def create(self, owner_uid: str, values: dict) -> TimetableEntry:
        entry = TimetableEntry(owner_uid=owner_uid, **values)
        self._db.add(entry)
        self._db.commit()
        self._db.refresh(entry)
        return entry

    def update(self, entry: TimetableEntry, changes: dict) -> TimetableEntry:
        for field, value in changes.items():
            setattr(entry, field, value)
        self._db.commit()
        self._db.refresh(entry)
        return entry

    def delete(self, entry: TimetableEntry) -> None:
        self._db.delete(entry)
        self._db.commit()
