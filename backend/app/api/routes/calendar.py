from datetime import datetime

from fastapi import APIRouter, Depends, Query

from app.api.deps import get_current_uid
from app.api.dependencies import get_calendar_service
from app.core.exceptions import InvalidResourceStateError
from app.schemas.calendar import CalendarItem
from app.services.calendar_service import CalendarService

router = APIRouter()


@router.get("", response_model=list[CalendarItem])
def read_calendar(
    start: datetime = Query(alias="from"),
    end: datetime = Query(alias="to"),
    include_courses: bool = True,
    include_tasks: bool = True,
    uid: str = Depends(get_current_uid),
    service: CalendarService = Depends(get_calendar_service),
) -> list[CalendarItem]:
    """Événements, occurrences de cours et échéances de tâches sur [from, to)."""
    if start.utcoffset() is None or end.utcoffset() is None:
        raise InvalidResourceStateError("`from` and `to` must include a timezone.")
    return service.items(
        uid,
        start,
        end,
        include_courses=include_courses,
        include_tasks=include_tasks,
    )
