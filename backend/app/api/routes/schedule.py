from datetime import date

from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.database.session import get_db
from app.models.course import Course
from app.models.user import User
from app.schemas.common import CourseRead
from app.schemas.planning import WeekAgendaResponse
from app.schemas.schedule import FreeSlot, ScheduleStatsResponse
from app.api.dependencies import get_planning_service
from app.services.planning_service import PlanningService
from app.services.schedule_service import ScheduleService
from sqlalchemy.orm import Session

router = APIRouter()


def get_schedule_service(db: Session = Depends(get_db)) -> ScheduleService:
    return ScheduleService(db)


@router.get("/day", response_model=list[CourseRead])
def get_day_view(
    target_date: date,
    service: ScheduleService = Depends(get_schedule_service),
    user: User = Depends(get_current_user),
) -> list[Course]:
    return service.get_day_view(user.firebase_uid, target_date)


@router.get("/week", response_model=list[CourseRead])
def get_week_view(
    week_start: date,
    service: ScheduleService = Depends(get_schedule_service),
    user: User = Depends(get_current_user),
) -> list[Course]:
    return service.get_week_view(user.firebase_uid, week_start)


@router.get("/conflicts", response_model=list[list[CourseRead]])
def get_conflicts(
    service: ScheduleService = Depends(get_schedule_service),
    user: User = Depends(get_current_user),
) -> list[list[Course]]:
    return [list(pair) for pair in service.get_conflicts(user.firebase_uid)]


@router.get("/free-slots", response_model=list[FreeSlot])
def get_free_slots(
    days: int = 7,
    service: ScheduleService = Depends(get_schedule_service),
    user: User = Depends(get_current_user),
) -> list[FreeSlot]:
    return service.get_free_slots(user.firebase_uid, days=days)


@router.get("/stats", response_model=ScheduleStatsResponse)
def get_stats(
    service: ScheduleService = Depends(get_schedule_service),
    user: User = Depends(get_current_user),
) -> ScheduleStatsResponse:
    return service.get_stats(user.firebase_uid)


@router.get("/week-agenda", response_model=WeekAgendaResponse)
def get_week_agenda(
    week_start: date | None = None,
    user: User = Depends(get_current_user),
    planner: PlanningService = Depends(get_planning_service),
) -> dict:
    """Semaine réelle : cours (annulés les jours fériés), événements,
    conflits, créneaux libres et heures par cours."""
    return planner.week_agenda(user.firebase_uid, week_start or date.today())
