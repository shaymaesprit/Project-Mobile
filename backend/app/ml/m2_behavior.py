"""M2 - Study behavior analysis (rule-based scoring and classification)."""

from datetime import timedelta

from app.ml.common import clip, completion_rate, minutes_by
from app.ml.schemas import BehaviorResult, DayProductivity, HourProductivity
from app.ml.types import SessionRecord, StudentSnapshot

MODEL_VERSION = "m2-rules-1"
WINDOW_DAYS = 28
MIN_SESSIONS = 3


def _focus_trend(sessions: list[SessionRecord]) -> str:
    rated = sorted(
        (s for s in sessions if s.focus_rating is not None), key=lambda s: s.started_local
    )
    if len(rated) < 6:
        return "unknown"
    half = len(rated) // 2
    first = sum(s.focus_rating for s in rated[:half]) / half
    second = sum(s.focus_rating for s in rated[half:]) / (len(rated) - half)
    if second - first >= 0.5:
        return "improving"
    if first - second >= 0.5:
        return "declining"
    return "stable"


def analyze_behavior(snapshot: StudentSnapshot) -> BehaviorResult:
    start = snapshot.now.replace(tzinfo=None) - timedelta(days=WINDOW_DAYS)
    sessions = [
        s for s in snapshot.sessions if s.started_local.replace(tzinfo=None) >= start
    ]
    if len(sessions) < MIN_SESSIONS:
        return BehaviorResult(
            model_version=MODEL_VERSION,
            status="insufficient_data",
            window_days=WINDOW_DAYS,
            sessions_count=len(sessions),
            task_completion_rate=_rounded(completion_rate(snapshot.tasks)),
            missing_data=[
                f"Au moins {MIN_SESSIONS} sessions d’étude sur {WINDOW_DAYS} jours "
                "sont nécessaires pour analyser ton comportement."
            ],
            suggestions=["Lance une session de concentration pour commencer l’analyse."],
        )

    active_days = {s.started_local.date() for s in sessions}
    per_week = len(active_days) / (WINDOW_DAYS / 7)
    total_minutes = sum(s.duration_minutes for s in sessions)
    average_minutes = total_minutes / len(sessions)
    rate = completion_rate(snapshot.tasks)
    rated = [s.focus_rating for s in sessions if s.focus_rating is not None]
    average_focus = sum(rated) / len(rated) if rated else None

    by_day = minutes_by(sessions, lambda s: s.started_local.weekday())
    by_hour = minutes_by(sessions, lambda s: s.started_local.hour)
    max_day = max((w for _, w in by_day.values()), default=1.0) or 1.0
    max_hour = max((w for _, w in by_hour.values()), default=1.0) or 1.0

    # Weighted blend of the components that are actually available.
    daily_goal = max(snapshot.daily_goal_minutes, 1)
    components = {
        "consistency": (0.35, clip(per_week / 5, 0, 1)),
        "volume": (0.25, clip(total_minutes / WINDOW_DAYS / daily_goal, 0, 1)),
    }
    if rate is not None:
        components["completion"] = (0.25, rate)
    if average_focus is not None:
        components["focus"] = (0.15, average_focus / 5)
    weight_sum = sum(weight for weight, _ in components.values())
    score = 100 * sum(weight * value for weight, value in components.values()) / weight_sum

    if score >= 75:
        classification = "consistent"
    elif per_week >= 3:
        classification = "steady"
    elif average_minutes >= 90:
        classification = "intensive_irregular"
    else:
        classification = "low_activity"

    suggestions: list[str] = []
    if per_week < 3:
        suggestions.append("Vise au moins 3 jours d’étude par semaine, même pour 20 minutes.")
    if classification == "intensive_irregular":
        suggestions.append("Répartis tes longues sessions sur plusieurs jours pour mieux mémoriser.")
    if rate is not None and rate < 0.6:
        suggestions.append("Termine tes tâches en cours avant d’en ajouter de nouvelles.")
    if average_focus is not None and average_focus < 3:
        suggestions.append("Ta concentration est faible : essaie des sessions plus courtes avec pauses.")
    if by_hour:
        best_hour = max(by_hour, key=lambda h: by_hour[h][1])
        suggestions.append(f"Ton créneau le plus productif commence vers {best_hour:02d}h.")
    if not suggestions:
        suggestions.append("Continue ainsi, ta régularité est bonne.")

    missing = []
    if rate is None:
        missing.append("Moins de 3 tâches : taux de réalisation non pris en compte.")
    if average_focus is None:
        missing.append("Aucune note de concentration : le focus n’est pas pris en compte.")

    return BehaviorResult(
        model_version=MODEL_VERSION,
        status="ok",
        window_days=WINDOW_DAYS,
        sessions_count=len(sessions),
        study_days_per_week=round(per_week, 2),
        average_session_minutes=round(average_minutes, 1),
        total_study_hours=round(total_minutes / 60, 2),
        task_completion_rate=_rounded(rate),
        average_focus=_rounded(average_focus, 2),
        focus_trend=_focus_trend(sessions),
        productivity_by_weekday=[
            DayProductivity(weekday=d, minutes=round(m, 1), productivity=round(w / max_day, 3))
            for d, (m, w) in sorted(by_day.items())
        ],
        productivity_by_hour=[
            HourProductivity(hour=h, minutes=round(m, 1), productivity=round(w / max_hour, 3))
            for h, (m, w) in sorted(by_hour.items())
        ],
        productivity_score=round(score, 1),
        classification=classification,
        suggestions=suggestions,
        missing_data=missing,
    )


def _rounded(value: float | None, digits: int = 3) -> float | None:
    return None if value is None else round(value, digits)
