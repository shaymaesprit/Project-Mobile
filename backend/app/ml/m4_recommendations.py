"""M4 - Personalized recommendations.

Always starts from transparent rules; M3 output is only used when a model was
actually produced. Cold-start students receive generic, clearly labelled
defaults built from their declared preferences only.
"""

from datetime import timedelta

from app.ml.common import clip
from app.ml.schemas import (
    AttentionSubject,
    BehaviorResult,
    Goals,
    LearningProfileResult,
    PerformanceResult,
    RecommendationsResult,
    SuggestedSession,
)
from app.ml.types import StudentSnapshot

DEFAULT_START_HOUR = 18
DEFAULT_SESSION_MINUTES = 45


def _attention_subjects(
    snapshot: StudentSnapshot, profile: LearningProfileResult
) -> list[AttentionSubject]:
    declared = {name.strip().lower() for name in snapshot.declared_difficult_subjects}
    now = snapshot.now.replace(tzinfo=None)
    subjects: list[AttentionSubject] = []
    for course in snapshot.courses:
        parts: list[tuple[float, float]] = []
        reasons: list[str] = []
        grades = [g.percent for g in snapshot.grades if g.course_id == course.id]
        if grades:
            average = sum(grades) / len(grades)
            parts.append((0.4, clip(1 - average / 100, 0, 1)))
            if average < 60:
                reasons.append(f"Moyenne de {average:.0f} %.")
        tasks = [t for t in snapshot.tasks if t.course_id == course.id]
        pending = [t for t in tasks if not t.is_completed]
        overdue = [
            t for t in pending
            if t.deadline is not None and t.deadline.replace(tzinfo=None) < now
        ]
        if tasks:
            parts.append((0.3, len(overdue) / len(tasks)))
            if overdue:
                reasons.append(f"{len(overdue)} tâche(s) en retard.")
        is_declared = course.title.strip().lower() in declared
        parts.append((0.2, 1.0 if is_declared else 0.0))
        if is_declared:
            reasons.append("Signalée comme difficile.")
        last = max(
            (s.started_local.replace(tzinfo=None) for s in snapshot.sessions
             if s.course_id == course.id),
            default=None,
        )
        if snapshot.sessions and any(s.course_id for s in snapshot.sessions):
            days = 14 if last is None else min((now - last).days, 14)
            parts.append((0.1, days / 14))
            if last is None or days >= 7:
                reasons.append("Peu ou pas révisée récemment.")
        if not reasons:
            continue
        weight = sum(w for w, _ in parts)
        score = sum(w * v for w, v in parts) / weight if weight else 0.0
        subjects.append(
            AttentionSubject(
                course_id=course.id, subject=course.title, score=round(score, 3),
                reasons=reasons,
            )
        )
    return sorted(subjects, key=lambda s: s.score, reverse=True)[:5]


def _conflicts(snapshot: StudentSnapshot, weekday: int, hour: int) -> bool:
    return any(
        c.weekday == weekday and c.start_hour is not None and c.end_hour is not None
        and c.start_hour <= hour < c.end_hour
        for c in snapshot.courses
    )


def build_recommendations(
    snapshot: StudentSnapshot,
    profile: LearningProfileResult,
    behavior: BehaviorResult,
    performance: PerformanceResult,
) -> RecommendationsResult:
    cold_start = (
        profile.data_sufficiency == "none"
        or (behavior.status != "ok" and not snapshot.grades and not snapshot.tasks)
    )
    notes: list[str] = []
    if cold_start:
        notes.append(
            "Pas encore assez de données : ces suggestions sont génériques. "
            "Elles s’affineront avec tes sessions, tâches et notes."
        )

    hours: list[int] = []
    if profile.preferred_periods:
        hours = [p.best_hour for p in profile.preferred_periods if p.best_hour is not None]
    if not hours:
        hours = [DEFAULT_START_HOUR]
    duration = profile.typical_session_minutes or DEFAULT_SESSION_MINUTES
    duration = int(clip(duration, 20, 90))

    attention = [] if cold_start else _attention_subjects(snapshot, profile)

    sessions: list[SuggestedSession] = []
    day = 0
    slot = 0
    while len(sessions) < 3 and day < 7:
        date = snapshot.now + timedelta(days=day)
        weekday = date.weekday()
        hour = hours[slot % len(hours)]
        if not _conflicts(snapshot, weekday, hour):
            subject = attention[len(sessions) % len(attention)] if attention else None
            sessions.append(
                SuggestedSession(
                    day_offset=day,
                    weekday=weekday,
                    start_hour=hour,
                    duration_minutes=duration,
                    subject=subject.subject if subject else None,
                    reason=(
                        f"Priorité : {subject.reasons[0]}" if subject
                        else "Créneau adapté à tes habitudes déclarées ou observées."
                    ),
                )
            )
            slot += 1
        day += 1

    objectives: list[str] = []
    if attention:
        objectives.append(f"Remonter le niveau en « {attention[0].subject} ».")
    if behavior.status == "ok" and behavior.study_days_per_week is not None:
        if behavior.study_days_per_week < 3:
            objectives.append("Atteindre 3 jours d’étude par semaine.")
    if performance.status == "ok" and performance.risk_indicators:
        objectives.append(performance.risk_indicators[0].message)
    if not objectives:
        objectives.append("Étudier régulièrement et enregistrer tes sessions.")

    goal = max(snapshot.daily_goal_minutes, 15)
    if behavior.status == "ok" and behavior.productivity_score is not None \
            and behavior.productivity_score < 40:
        goal = max(int(goal * 0.8), 15)
        notes.append("Objectif quotidien réduit de 20 % pour reprendre progressivement.")
    due_soon = sum(
        1 for t in snapshot.tasks
        if not t.is_completed and t.deadline is not None
        and 0 <= (t.deadline.replace(tzinfo=None) - snapshot.now.replace(tzinfo=None)).days < 7
    )
    weekly_sessions = int(clip(round(goal * 5 / duration), 1, 14))

    return RecommendationsResult(
        mode="rules+ml" if performance.model and performance.model.kind != "rules" else "rules",
        cold_start=cold_start,
        suggested_sessions=sessions,
        suitable_hours=sorted(set(hours)),
        subjects_needing_attention=attention,
        learning_objectives=objectives,
        goals=Goals(
            daily_minutes=goal,
            weekly_minutes=goal * 5,
            weekly_sessions=weekly_sessions,
            weekly_tasks_due=due_soon,
        ),
        notes=notes,
    )
