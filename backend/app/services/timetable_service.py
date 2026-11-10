from uuid import UUID

from app.core.exceptions import (
    CourseScheduleConflictError,
    InvalidReferenceError,
    InvalidResourceStateError,
    ResourceNotFoundError,
)
from app.models.timetable import TimetableEntry
from app.repositories.course_repository import CourseRepository
from app.repositories.timetable_repository import TimetableRepository


class TimetableService:
    def __init__(
        self,
        repository: TimetableRepository,
        course_repository: CourseRepository,
    ) -> None:
        self._repo = repository
        self._course_repo = course_repository

    def list_entries(
        self,
        owner_uid: str,
        jour: int | None = None,
        course_id: UUID | None = None,
    ) -> list[TimetableEntry]:
        return self._repo.list_for_owner(owner_uid, jour=jour, course_id=course_id)

    def get_entry(self, entry_id: UUID, owner_uid: str) -> TimetableEntry:
        entry = self._repo.get_for_owner(entry_id, owner_uid)
        if entry is None:
            raise ResourceNotFoundError("Timetable entry not found.")
        return entry

    def create_entry(self, owner_uid: str, values: dict) -> TimetableEntry:
        self._validate_course_ownership(values["course_id"], owner_uid)
        self._check_overlap(
            owner_uid,
            values["jour"],
            values["heure_debut"],
            values["heure_fin"],
        )
        return self._repo.create(owner_uid, values)

    def update_entry(
        self, entry_id: UUID, owner_uid: str, changes: dict
    ) -> TimetableEntry:
        entry = self.get_entry(entry_id, owner_uid)

        if "course_id" in changes:
            self._validate_course_ownership(changes["course_id"], owner_uid)

        jour = changes.get("jour", entry.jour)
        heure_debut = changes.get("heure_debut", entry.heure_debut)
        heure_fin = changes.get("heure_fin", entry.heure_fin)

        if heure_debut >= heure_fin:
            raise InvalidResourceStateError(
                "heure_fin must be after heure_debut."
            )

        self._check_overlap(owner_uid, jour, heure_debut, heure_fin, exclude_id=entry_id)
        return self._repo.update(entry, changes)

    def delete_entry(self, entry_id: UUID, owner_uid: str) -> None:
        entry = self.get_entry(entry_id, owner_uid)
        self._repo.delete(entry)

    # --- helpers ---

    def _validate_course_ownership(
        self, course_id: UUID, owner_uid: str
    ) -> None:
        course = self._course_repo.get_for_owner(course_id, owner_uid)
        if course is None:
            raise InvalidReferenceError(
                "Course not found or does not belong to the current user."
            )

    def _check_overlap(
        self,
        owner_uid: str,
        jour: int,
        heure_debut,
        heure_fin,
        exclude_id: UUID | None = None,
    ) -> None:
        if self._repo.has_overlap(
            owner_uid, jour, heure_debut, heure_fin, exclude_id=exclude_id
        ):
            raise CourseScheduleConflictError(
                "This time slot overlaps with an existing timetable entry."
            )
