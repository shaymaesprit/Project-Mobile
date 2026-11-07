from collections import defaultdict
from statistics import mean

from app.ml.types import GradeRecord, SessionRecord, StudentSnapshot, TaskRecord

MIN_SESSIONS_FOR_INFERENCE = 5

PERIODS: dict[str, range] = {
    "morning": range(5, 12),
    "afternoon": range(12, 17),
    "evening": range(17, 22),
}


def period_of(hour: int) -> str:
    for name, hours in PERIODS.items():
        if hour in hours:
            return name
    return "night"


def clip(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def session_weight(session: SessionRecord) -> float:
    """Focus-weighted study minutes (unrated sessions count as focus 3/5)."""
    return session.duration_minutes * ((session.focus_rating or 3) / 5)


def completion_rate(tasks: list[TaskRecord]) -> float | None:
    """Share of completed tasks, or None when there are too few to judge."""
    if len(tasks) < 3:
        return None
    return sum(task.is_completed for task in tasks) / len(tasks)


def average_grade(grades: list[GradeRecord]) -> float | None:
    """Mean grade in percent, giving recent evaluations a higher weight."""
    if not grades:
        return None
    ordered = sorted(grades, key=lambda g: g.scheduled_at.timestamp() if g.scheduled_at else 0)
    weights = [1 + index / max(len(ordered) - 1, 1) * 0.5 for index in range(len(ordered))]
    return sum(g.percent * w for g, w in zip(ordered, weights)) / sum(weights)


def grade_trend(grades: list[GradeRecord]) -> float | None:
    """Average change in percentage points between consecutive evaluations."""
    if len(grades) < 3:
        return None
    ordered = sorted(grades, key=lambda g: g.scheduled_at.timestamp() if g.scheduled_at else 0)
    return (ordered[-1].percent - ordered[0].percent) / (len(ordered) - 1)


def weekly_study_hours(snapshot: StudentSnapshot, window_days: int = 28) -> float | None:
    recent = [
        s for s in snapshot.sessions
        if (snapshot.now.replace(tzinfo=None) - s.started_local.replace(tzinfo=None)).days
        < window_days
    ]
    if not recent:
        return None
    return sum(s.duration_minutes for s in recent) / 60 / (window_days / 7)


def minutes_by(sessions: list[SessionRecord], key) -> dict[int, list[float]]:
    """Group sessions as {key: [minutes, focus-weighted minutes]}."""
    grouped: dict[int, list[float]] = defaultdict(lambda: [0.0, 0.0])
    for session in sessions:
        bucket = grouped[key(session)]
        bucket[0] += session.duration_minutes
        bucket[1] += session_weight(session)
    return grouped


def safe_mean(values: list[float]) -> float | None:
    return mean(values) if values else None
