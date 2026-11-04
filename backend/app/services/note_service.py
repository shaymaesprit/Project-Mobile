from uuid import UUID

from app.core.exceptions import InvalidReferenceError, ResourceNotFoundError
from app.models.note import Note
from app.repositories.note_repository import NoteRepository


class NoteService:
    def __init__(self, repository: NoteRepository) -> None:
        self._repository = repository

    def list_notes(self, owner_uid: str) -> list[Note]:
        return self._repository.list_for_owner(owner_uid)

    def get_note(self, note_id: UUID, owner_uid: str) -> Note:
        note = self._repository.get_for_owner(note_id, owner_uid)
        if note is None:
            raise ResourceNotFoundError("Note not found.")
        return note

    def create_note(self, owner_uid: str, values: dict) -> Note:
        self._validate_course(values.get("course_id"), owner_uid)
        return self._repository.create(owner_uid, values)

    def update_note(
        self, note_id: UUID, owner_uid: str, changes: dict
    ) -> Note:
        note = self.get_note(note_id, owner_uid)
        if "course_id" in changes:
            self._validate_course(changes["course_id"], owner_uid)
        return self._repository.update(note, changes)

    def delete_note(self, note_id: UUID, owner_uid: str) -> None:
        note = self.get_note(note_id, owner_uid)
        self._repository.delete(note)

    def _validate_course(self, course_id: UUID | None, owner_uid: str) -> None:
        if course_id is not None and not self._repository.course_exists_for_owner(
            course_id, owner_uid
        ):
            raise InvalidReferenceError("Course not found.")
