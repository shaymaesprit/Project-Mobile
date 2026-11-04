from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.course import Course
from app.models.note import Note


class NoteRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_owner(self, owner_uid: str) -> list[Note]:
        return list(
            self._db.scalars(
                select(Note)
                .where(Note.owner_uid == owner_uid)
                .order_by(Note.updated_at.desc())
            )
        )

    def get_for_owner(self, note_id: UUID, owner_uid: str) -> Note | None:
        return self._db.scalar(
            select(Note).where(
                Note.id == note_id,
                Note.owner_uid == owner_uid,
            )
        )

    def course_exists_for_owner(self, course_id: UUID, owner_uid: str) -> bool:
        return (
            self._db.scalar(
                select(Course.id).where(
                    Course.id == course_id,
                    Course.owner_uid == owner_uid,
                )
            )
            is not None
        )

    def create(self, owner_uid: str, values: dict) -> Note:
        note = Note(owner_uid=owner_uid, **values)
        self._db.add(note)
        self._db.commit()
        self._db.refresh(note)
        return note

    def update(self, note: Note, changes: dict) -> Note:
        for field, value in changes.items():
            setattr(note, field, value)
        self._db.commit()
        self._db.refresh(note)
        return note

    def delete(self, note: Note) -> None:
        self._db.delete(note)
        self._db.commit()
