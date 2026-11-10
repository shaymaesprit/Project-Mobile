from datetime import date, datetime, time, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.course import Course
from app.schemas.schedule import (
    CourseStats,
    FreeSlot,
    ScheduleStatsResponse,
)


class ScheduleService:
    def __init__(self, db: Session) -> None:
        self._db = db

    # --- Day view ---

    def get_day_view(self, owner_uid: str, target_date: date) -> list[Course]:
        weekday = target_date.weekday()  # 0=Monday … 6=Sunday
        return list(
            self._db.scalars(
                select(Course)
                .where(
                    Course.owner_uid == owner_uid,
                    Course.weekday == weekday,
                )
                .order_by(Course.start_time, Course.title)
            )
        )

    # --- Week view ---

    def get_week_view(self, owner_uid: str, week_start: date) -> list[Course]:
        week_end = week_start + timedelta(days=6)
        start_weekday = week_start.weekday()
        end_weekday = week_end.weekday()
        # Collect weekday integers in the range
        weekdays = [(week_start + timedelta(days=i)).weekday() for i in range(7)]
        return list(
            self._db.scalars(
                select(Course)
                .where(
                    Course.owner_uid == owner_uid,
                    Course.weekday.in_(weekdays),
                )
                .order_by(Course.weekday, Course.start_time, Course.title)
            )
        )

    # --- Conflicts ---

    def get_conflicts(self, owner_uid: str) -> list[tuple[Course, Course]]:
        courses = list(
            self._db.scalars(
                select(Course)
                .where(
                    Course.owner_uid == owner_uid,
                    Course.weekday.is_not(None),
                )
                .order_by(Course.weekday, Course.start_time)
            )
        )
        conflicts: list[tuple[Course, Course]] = []
        for i, a in enumerate(courses):
            for b in courses[i + 1:]:
                if a.weekday != b.weekday:
                    break
                if a.start_time < b.end_time and b.start_time < a.end_time:  # type: ignore[operator]
                    conflicts.append((a, b))
        return conflicts

    # --- Free slots ---

    def get_free_slots(self, owner_uid: str, days: int = 7) -> list[FreeSlot]:
        today = date.today()
        weekdays = [(today + timedelta(days=i)).weekday() for i in range(days)]
        courses = list(
            self._db.scalars(
                select(Course)
                .where(
                    Course.owner_uid == owner_uid,
                    Course.weekday.in_(weekdays),
                )
                .order_by(Course.weekday, Course.start_time)
            )
        )
        # Group by weekday
        by_day: dict[int, list[Course]] = {}
        for c in courses:
            if c.weekday is not None:
                by_day.setdefault(c.weekday, []).append(c)

        slots: list[FreeSlot] = []
        day_start = time(8, 0)
        day_end = time(20, 0)

        for wd in set(weekdays):
            day_courses = sorted(by_day.get(wd, []), key=lambda c: c.start_time or time.min)
            cursor = day_start
            for c in day_courses:
                if c.start_time and c.start_time > cursor:
                    gap = self._minutes_between(cursor, c.start_time)
                    if gap >= 30:
                        slots.append(FreeSlot(
                            weekday=wd,
                            start_time=cursor,
                            end_time=c.start_time,
                            duration_minutes=gap,
                        ))
                if c.end_time and c.end_time > cursor:
                    cursor = c.end_time
            # After last course
            if cursor < day_end:
                gap = self._minutes_between(cursor, day_end)
                if gap >= 30:
                    slots.append(FreeSlot(
                        weekday=wd,
                        start_time=cursor,
                        end_time=day_end,
                        duration_minutes=gap,
                    ))
        return sorted(slots, key=lambda s: (s.weekday, s.start_time))

    # --- Stats ---

    def get_stats(self, owner_uid: str) -> ScheduleStatsResponse:
        courses = list(
            self._db.scalars(
                select(Course)
                .where(
                    Course.owner_uid == owner_uid,
                    Course.weekday.is_not(None),
                )
            )
        )
        total_minutes = sum(
            self._minutes_between(c.start_time, c.end_time)
            for c in courses
            if c.start_time and c.end_time
        )
        total_hours = total_minutes / 60.0

        course_stats: list[CourseStats] = []
        for c in courses:
            if c.start_time and c.end_time:
                mins = self._minutes_between(c.start_time, c.end_time)
                hrs = mins / 60.0
                pct = (hrs / total_hours * 100.0) if total_hours > 0 else 0.0
                course_stats.append(CourseStats(
                    course_id=c.id,
                    title=c.title,
                    hours_per_week=round(hrs, 2),
                    percentage=round(pct, 2),
                ))

        # Ensure percentages sum to 100 (fix rounding on last item)
        if course_stats and total_hours > 0:
            diff = 100.0 - sum(s.percentage for s in course_stats)
            course_stats[-1] = course_stats[-1].model_copy(
                update={"percentage": round(course_stats[-1].percentage + diff, 2)}
            )

        return ScheduleStatsResponse(
            total_hours_per_week=round(total_hours, 2),
            courses=course_stats,
        )

    # --- Helpers ---

    @staticmethod
    def _minutes_between(start: time, end: time) -> int:
        return (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute)
