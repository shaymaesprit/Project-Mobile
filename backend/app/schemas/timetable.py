from datetime import datetime, time
from uuid import UUID

from pydantic import Field, model_validator

from app.models.timetable import SeanceType
from app.schemas.common import ApiSchema


class TimetableEntryCreate(ApiSchema):
    course_id: UUID
    jour: int = Field(ge=0, le=6)
    heure_debut: time
    heure_fin: time
    salle: str | None = Field(default=None, max_length=100)
    type_seance: SeanceType = SeanceType.COURS

    @model_validator(mode="after")
    def validate_time_order(self) -> "TimetableEntryCreate":
        if self.heure_debut >= self.heure_fin:
            raise ValueError("heure_fin must be after heure_debut.")
        return self


class TimetableEntryUpdate(ApiSchema):
    course_id: UUID | None = None
    jour: int | None = Field(default=None, ge=0, le=6)
    heure_debut: time | None = None
    heure_fin: time | None = None
    salle: str | None = Field(default=None, max_length=100)
    type_seance: SeanceType | None = None

    @model_validator(mode="after")
    def validate_time_order(self) -> "TimetableEntryUpdate":
        if self.heure_debut is not None and self.heure_fin is not None:
            if self.heure_debut >= self.heure_fin:
                raise ValueError("heure_fin must be after heure_debut.")
        return self


class TimetableEntryResponse(ApiSchema):
    id: UUID
    owner_uid: str
    course_id: UUID
    jour: int
    heure_debut: time
    heure_fin: time
    salle: str | None
    type_seance: SeanceType
    created_at: datetime
    updated_at: datetime
