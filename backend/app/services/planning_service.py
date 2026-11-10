"""Agenda hebdomadaire et planificateur intelligent de tâches.

Métier :

* **Occupation réelle** : cours hebdomadaires (sauf les jours fériés, où ils
  sont annulés) + événements non annulés (les échéances ne bloquent pas).
* **Créneaux libres** : fenêtres d'au moins 30 min entre 08:00 et 20:00
  (heure locale de l'étudiant), déduites de l'occupation.
* **Score de priorité (0–100)** pour chaque tâche non terminée :
    - urgence de l'échéance (50 pts max) — en retard = 50, décroît sur 14 j ;
    - priorité déclarée (25 pts max) ;
    - importance du cours : coefficient (15 pts) et difficulté perçue (10 pts).
* **Planification gloutonne** : les tâches, triées par score, sont découpées
  en sessions de 25 à 90 min et placées dans les créneaux libres *avant*
  leur échéance. Le résultat dit, pour chaque tâche, si elle est planifiée,
  partiellement planifiée, impossible à caser ou déjà en retard.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta, timezone
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.course import Course
from app.models.extended import StudyEvent
from app.models.task import StudyTask
from app.services.event_conflicts import (
    NON_BLOCKING_TYPES,
    as_utc,
    effective_end,
    user_timezone,
)
from app.services.holiday_service import Holiday, HolidayService

DAY_START = time(8, 0)
DAY_END = time(20, 0)
MIN_SLOT_MINUTES = 30
MIN_SESSION_MINUTES = 25
MAX_SESSION_MINUTES = 90
BREAK_MINUTES = 10

PRIORITY_POINTS = {"high": 25.0, "medium": 15.0, "low": 6.0}
PRIORITY_MINUTES = {"high": 120, "medium": 75, "low": 40}


@dataclass
class Block:
    kind: str  # "course" | "event"
    id: UUID
    title: str
    starts_at: datetime  # UTC
    ends_at: datetime  # UTC
    room: str | None = None


@dataclass
class Window:
    starts_at: datetime  # UTC
    ends_at: datetime  # UTC

    @property
    def minutes(self) -> int:
        return int((self.ends_at - self.starts_at).total_seconds() // 60)


@dataclass
class TaskPlan:
    task: StudyTask
    score: float
    reasons: list[str]
    estimated_minutes: int
    sessions: list[Window] = field(default_factory=list)
    status: str = "unplanned"  # planned | partial | unplanned | overdue

    @property
    def planned_minutes(self) -> int:
        return sum(session.minutes for session in self.sessions)


class PlanningService:
    def __init__(self, db: Session, holidays: HolidayService) -> None:
        self._db = db
        self._holidays = holidays

    # ── Occupation ──────────────────────────────────────────────────────────

    def busy_blocks(
        self,
        owner_uid: str,
        first_day: date,
        last_day: date,
        tz: ZoneInfo,
        holidays: dict[date, Holiday],
    ) -> tuple[list[Block], list[Block]]:
        """Renvoie (blocs actifs, cours annulés pour cause de jour férié)."""
        start = datetime.combine(first_day, time.min, tzinfo=tz).astimezone(timezone.utc)
        end = datetime.combine(last_day + timedelta(days=1), time.min, tzinfo=tz).astimezone(
            timezone.utc
        )
        blocks: list[Block] = []
        cancelled: list[Block] = []

        courses = self._db.scalars(
            select(Course).where(
                Course.owner_uid == owner_uid,
                Course.weekday.is_not(None),
                Course.start_time.is_not(None),
                Course.end_time.is_not(None),
            )
        )
        for course in courses:
            day = first_day
            while day <= last_day:
                if day.weekday() == course.weekday:
                    begins = datetime.combine(day, course.start_time.replace(tzinfo=None), tzinfo=tz)
                    ends = datetime.combine(day, course.end_time.replace(tzinfo=None), tzinfo=tz)
                    block = Block(
                        "course",
                        course.id,
                        course.title,
                        begins.astimezone(timezone.utc),
                        ends.astimezone(timezone.utc),
                        course.room,
                    )
                    (cancelled if day in holidays else blocks).append(block)
                day += timedelta(days=1)

        events = self._db.scalars(
            select(StudyEvent).where(
                StudyEvent.owner_uid == owner_uid,
                StudyEvent.status != "cancelled",
                StudyEvent.event_type.notin_(NON_BLOCKING_TYPES),
                StudyEvent.starts_at < end,
                StudyEvent.starts_at >= start - timedelta(days=1),
            )
        )
        for event in events:
            event_start = as_utc(event.starts_at)
            event_end = as_utc(
                effective_end(event_start, as_utc(event.ends_at) if event.ends_at else None)
            )
            if event_end > start and event_start < end:
                blocks.append(
                    Block("event", event.id, event.title, event_start, event_end, event.location)
                )

        blocks.sort(key=lambda block: block.starts_at)
        cancelled.sort(key=lambda block: block.starts_at)
        return blocks, cancelled

    @staticmethod
    def free_windows(
        day: date,
        blocks: list[Block],
        tz: ZoneInfo,
        not_before: datetime | None = None,
    ) -> list[Window]:
        day_start = datetime.combine(day, DAY_START, tzinfo=tz).astimezone(timezone.utc)
        day_end = datetime.combine(day, DAY_END, tzinfo=tz).astimezone(timezone.utc)
        cursor = max(day_start, not_before) if not_before else day_start
        windows: list[Window] = []
        for block in sorted(blocks, key=lambda b: b.starts_at):
            if block.ends_at <= cursor or block.starts_at >= day_end:
                continue
            if block.starts_at > cursor:
                windows.append(Window(cursor, min(block.starts_at, day_end)))
            cursor = max(cursor, block.ends_at)
        if cursor < day_end:
            windows.append(Window(cursor, day_end))
        return [w for w in windows if w.minutes >= MIN_SLOT_MINUTES]

    @staticmethod
    def conflicts(blocks: list[Block]) -> list[tuple[Block, Block]]:
        pairs: list[tuple[Block, Block]] = []
        ordered = sorted(blocks, key=lambda b: b.starts_at)
        for index, first in enumerate(ordered):
            for second in ordered[index + 1:]:
                if second.starts_at >= first.ends_at:
                    break
                pairs.append((first, second))
        return pairs

    # ── Agenda hebdomadaire ─────────────────────────────────────────────────

    def week_agenda(self, owner_uid: str, week_start: date) -> dict:
        week_start = week_start - timedelta(days=week_start.weekday())  # lundi
        week_end = week_start + timedelta(days=6)
        tz = user_timezone(self._db, owner_uid)
        holidays = self._holidays.between(week_start, week_end)
        blocks, cancelled = self.busy_blocks(owner_uid, week_start, week_end, tz, holidays)

        days = []
        course_minutes: dict[UUID, tuple[str, int]] = {}
        for offset in range(7):
            day = week_start + timedelta(days=offset)
            day_blocks = [b for b in blocks if b.starts_at.astimezone(tz).date() == day]
            day_cancelled = [b for b in cancelled if b.starts_at.astimezone(tz).date() == day]
            for block in day_blocks:
                if block.kind == "course":
                    title, minutes = course_minutes.get(block.id, (block.title, 0))
                    course_minutes[block.id] = (
                        title,
                        minutes + int((block.ends_at - block.starts_at).total_seconds() // 60),
                    )
            holiday = holidays.get(day)
            days.append({
                "date": day,
                "holiday": holiday.as_dict() if holiday else None,
                "items": [_block_dict(b, tz) for b in day_blocks],
                "cancelled": [_block_dict(b, tz) for b in day_cancelled],
                "free_slots": [
                    _window_dict(w, tz) for w in self.free_windows(day, day_blocks, tz)
                ],
                "conflicts": [
                    [_block_dict(a, tz), _block_dict(b, tz)]
                    for a, b in self.conflicts(day_blocks)
                ],
            })

        total = sum(minutes for _, minutes in course_minutes.values())
        return {
            "week_start": week_start,
            "timezone": str(tz),
            "days": days,
            "stats": {
                "course_hours": round(total / 60, 2),
                "free_hours": round(
                    sum(slot["minutes"] for d in days for slot in d["free_slots"]) / 60, 2
                ),
                "by_course": [
                    {"course_id": cid, "title": title, "hours": round(minutes / 60, 2)}
                    for cid, (title, minutes) in sorted(
                        course_minutes.items(), key=lambda item: -item[1][1]
                    )
                ],
            },
        }

    # ── Planificateur de tâches ─────────────────────────────────────────────

    @staticmethod
    def score(task: StudyTask, course: Course | None, now: datetime) -> tuple[float, list[str]]:
        reasons: list[str] = []
        points = 0.0

        if task.deadline is not None:
            hours_left = (as_utc(task.deadline) - now).total_seconds() / 3600
            if hours_left <= 0:
                urgency = 50.0
                reasons.append("Échéance dépassée")
            else:
                # 50 pts à l'échéance, ~0 à 14 jours.
                urgency = max(0.0, 50.0 * (1 - hours_left / (14 * 24)))
                if hours_left < 48:
                    reasons.append("Échéance dans moins de 48 h")
                elif hours_left < 7 * 24:
                    reasons.append("Échéance cette semaine")
            points += urgency
        else:
            points += 5.0
            reasons.append("Pas d’échéance")

        points += PRIORITY_POINTS.get(task.priority, 15.0)
        if task.priority == "high":
            reasons.append("Priorité haute")

        if course is not None:
            coefficient = course.coefficient or 1.0
            points += min(15.0, 3.0 * coefficient)
            if coefficient >= 3:
                reasons.append(f"Cours à fort coefficient ({coefficient:g})")
            difficulty = course.difficulte_percue
            if difficulty:
                points += 2.0 * difficulty
                if difficulty >= 4:
                    reasons.append("Matière jugée difficile")

        return round(min(points, 100.0), 1), reasons

    @staticmethod
    def estimate_minutes(task: StudyTask, course: Course | None) -> int:
        minutes = PRIORITY_MINUTES.get(task.priority, 75)
        if course is not None and course.difficulte_percue and course.difficulte_percue >= 4:
            minutes = int(minutes * 1.25)
        return minutes

    def plan(self, owner_uid: str, days: int = 7, now: datetime | None = None) -> dict:
        now = as_utc(now or datetime.now(timezone.utc))
        tz = user_timezone(self._db, owner_uid)
        first_day = now.astimezone(tz).date()
        last_day = first_day + timedelta(days=days - 1)
        holidays = self._holidays.between(first_day, last_day)
        blocks, _ = self.busy_blocks(owner_uid, first_day, last_day, tz, holidays)

        windows: list[Window] = []
        for offset in range(days):
            day = first_day + timedelta(days=offset)
            day_blocks = [b for b in blocks if b.starts_at.astimezone(tz).date() == day]
            windows.extend(self.free_windows(day, day_blocks, tz, not_before=now))

        courses = {
            course.id: course
            for course in self._db.scalars(select(Course).where(Course.owner_uid == owner_uid))
        }
        tasks = list(
            self._db.scalars(
                select(StudyTask).where(
                    StudyTask.owner_uid == owner_uid,
                    StudyTask.is_completed.is_(False),
                )
            )
        )

        plans: list[TaskPlan] = []
        for task in tasks:
            course = courses.get(task.course_id) if task.course_id else None
            score, reasons = self.score(task, course, now)
            plans.append(TaskPlan(task, score, reasons, self.estimate_minutes(task, course)))
        plans.sort(key=lambda p: (-p.score, as_utc(p.task.deadline) if p.task.deadline else datetime.max.replace(tzinfo=timezone.utc)))

        for item in plans:
            deadline = as_utc(item.task.deadline) if item.task.deadline else None
            if deadline is not None and deadline <= now:
                item.status = "overdue"
                # Une tâche en retard passe quand même en tête : on la cale au plus tôt.
                deadline = None
            remaining = item.estimated_minutes
            for window in windows:
                # Remplit ce créneau (sessions + pauses) avant de passer au suivant.
                while remaining >= MIN_SESSION_MINUTES:
                    limit = min(window.ends_at, deadline) if deadline else window.ends_at
                    available = int((limit - window.starts_at).total_seconds() // 60)
                    if available < MIN_SESSION_MINUTES:
                        break
                    length = min(remaining, MAX_SESSION_MINUTES, available)
                    session = Window(
                        window.starts_at, window.starts_at + timedelta(minutes=length)
                    )
                    item.sessions.append(session)
                    remaining -= length
                    window.starts_at = session.ends_at + timedelta(minutes=BREAK_MINUTES)
                if remaining < MIN_SESSION_MINUTES:
                    break
            windows = [w for w in windows if w.minutes >= MIN_SESSION_MINUTES]
            if item.status != "overdue":
                if remaining < MIN_SESSION_MINUTES and item.sessions:
                    item.status = "planned"
                elif item.sessions:
                    item.status = "partial"
                else:
                    item.status = "unplanned"

        return {
            "generated_at": now,
            "timezone": str(tz),
            "days": days,
            "holidays": [h.as_dict() for h in holidays.values()],
            "free_minutes": sum(w.minutes for w in windows),
            "items": [
                {
                    "task_id": item.task.id,
                    "title": item.task.title,
                    "priority": item.task.priority,
                    "deadline": item.task.deadline,
                    "course_id": item.task.course_id,
                    "score": item.score,
                    "reasons": item.reasons,
                    "estimated_minutes": item.estimated_minutes,
                    "planned_minutes": item.planned_minutes,
                    "status": item.status,
                    "sessions": [_window_dict(s, tz) for s in item.sessions],
                }
                for item in plans
            ],
        }


def _block_dict(block: Block, tz: ZoneInfo) -> dict:
    return {
        "kind": block.kind,
        "id": block.id,
        "title": block.title,
        "starts_at": block.starts_at.astimezone(tz),
        "ends_at": block.ends_at.astimezone(tz),
        "room": block.room,
    }


def _window_dict(window: Window, tz: ZoneInfo) -> dict:
    return {
        "starts_at": window.starts_at.astimezone(tz),
        "ends_at": window.ends_at.astimezone(tz),
        "minutes": window.minutes,
    }
