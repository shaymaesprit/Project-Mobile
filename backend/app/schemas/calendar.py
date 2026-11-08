from datetime import datetime
from typing import Literal
from uuid import UUID

from app.schemas.common import ApiSchema

CalendarKind = Literal["event", "course", "task"]


class CalendarItem(ApiSchema):
    """Une entrée du calendrier unifié (événement, cours ou tâche à échéance)."""

    kind: CalendarKind
    id: UUID
    title: str
    starts_at: datetime
    ends_at: datetime | None = None
    # event_type pour un événement ; "class" pour un cours ; "deadline" pour une tâche.
    category: str
    status: str | None = None
    location: str | None = None
    course_id: UUID | None = None
    color: str | None = None
    completed: bool | None = None
