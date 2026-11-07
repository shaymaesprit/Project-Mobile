"""M1 - Personalized learning profile (rule-based, cold-start safe)."""

from statistics import median

from app.ml.common import (
    MIN_SESSIONS_FOR_INFERENCE,
    average_grade,
    completion_rate,
    minutes_by,
    period_of,
)
from app.ml.schemas import (
    DifficultyIndicator,
    LearningProfileResult,
    PeriodShare,
)
from app.ml.types import StudentSnapshot

MODEL_VERSION = "m1-rules-1"
LOW_GRADE_PERCENT = 60.0
VERY_LOW_GRADE_PERCENT = 50.0


def _sufficiency(snapshot: StudentSnapshot) -> str:
    evidence = len(snapshot.sessions) + len(snapshot.tasks) + len(snapshot.grades)
    if evidence == 0:
        return "none"
    if len(snapshot.sessions) >= MIN_SESSIONS_FOR_INFERENCE and snapshot.grades:
        return "sufficient"
    return "low"


def _preferred_periods(snapshot: StudentSnapshot):
    if len(snapshot.sessions) >= MIN_SESSIONS_FOR_INFERENCE:
        by_hour = minutes_by(snapshot.sessions, lambda s: s.started_local.hour)
        by_period: dict[str, float] = {}
        best_hour: dict[str, tuple[int, float]] = {}
        for hour, (_, weighted) in by_hour.items():
            period = period_of(hour)
            by_period[period] = by_period.get(period, 0.0) + weighted
            if weighted > best_hour.get(period, (hour, -1.0))[1]:
                best_hour[period] = (hour, weighted)
        total = sum(by_period.values()) or 1.0
        ranked = sorted(by_period.items(), key=lambda item: item[1], reverse=True)
        return "observed", [
            PeriodShare(
                period=name, share=round(value / total, 3), best_hour=best_hour[name][0]
            )
            for name, value in ranked
        ]
    if snapshot.declared_preferred_hours:
        counts: dict[str, list[int]] = {}
        for hour in snapshot.declared_preferred_hours:
            counts.setdefault(period_of(hour), []).append(hour)
        total = len(snapshot.declared_preferred_hours)
        ranked = sorted(counts.items(), key=lambda item: len(item[1]), reverse=True)
        return "declared", [
            PeriodShare(period=name, share=round(len(hours) / total, 3), best_hour=min(hours))
            for name, hours in ranked
        ]
    return "none", []


def _difficulty_indicators(snapshot: StudentSnapshot) -> list[DifficultyIndicator]:
    declared = {name.strip().lower() for name in snapshot.declared_difficult_subjects}
    indicators: list[DifficultyIndicator] = []
    for course in snapshot.courses:
        reasons: list[str] = []
        score = 0
        grades = [g.percent for g in snapshot.grades if g.course_id == course.id]
        average = sum(grades) / len(grades) if grades else None
        if average is not None and average < VERY_LOW_GRADE_PERCENT:
            reasons.append(f"Moyenne très basse ({average:.0f} %).")
            score += 2
        elif average is not None and average < LOW_GRADE_PERCENT:
            reasons.append(f"Moyenne en dessous de {LOW_GRADE_PERCENT:.0f} % ({average:.0f} %).")
            score += 1
        tasks = [t for t in snapshot.tasks if t.course_id == course.id]
        overdue = [
            t for t in tasks
            if not t.is_completed and t.deadline is not None
            and t.deadline.replace(tzinfo=None) < snapshot.now.replace(tzinfo=None)
        ]
        if len(overdue) >= 2:
            reasons.append(f"{len(overdue)} tâches en retard.")
            score += 1
        if course.title.strip().lower() in declared:
            reasons.append("Matière signalée comme difficile par l’étudiant.")
            score += 1
        if reasons:
            level = "high" if score >= 3 else "medium" if score == 2 else "low"
            indicators.append(
                DifficultyIndicator(
                    course_id=course.id,
                    subject=course.title,
                    level=level,
                    average_grade_percent=None if average is None else round(average, 1),
                    reasons=reasons,
                )
            )
    known = {c.title.strip().lower() for c in snapshot.courses}
    for name in snapshot.declared_difficult_subjects:
        if name.strip().lower() not in known:
            indicators.append(
                DifficultyIndicator(
                    subject=name.strip(),
                    level="low",
                    reasons=["Matière signalée comme difficile par l’étudiant."],
                )
            )
    order = {"high": 0, "medium": 1, "low": 2}
    return sorted(indicators, key=lambda i: order[i.level])


def analyze_learning_profile(snapshot: StudentSnapshot) -> LearningProfileResult:
    sufficiency = _sufficiency(snapshot)
    source, periods = _preferred_periods(snapshot)
    durations = [s.duration_minutes for s in snapshot.sessions if s.duration_minutes > 0]
    if len(durations) >= MIN_SESSIONS_FOR_INFERENCE:
        typical = int(round(median(durations)))
    else:
        typical = snapshot.declared_session_minutes
    average = average_grade(snapshot.grades)
    rate = completion_rate(snapshot.tasks)
    indicators = _difficulty_indicators(snapshot)

    missing: list[str] = []
    if len(snapshot.sessions) < MIN_SESSIONS_FOR_INFERENCE:
        missing.append(
            f"Au moins {MIN_SESSIONS_FOR_INFERENCE} sessions d’étude sont nécessaires "
            "pour déduire tes horaires préférés."
        )
    if not snapshot.grades:
        missing.append("Aucune note enregistrée : les indicateurs de difficulté sont limités.")
    if len(snapshot.tasks) < 3:
        missing.append("Au moins 3 tâches sont nécessaires pour calculer un taux de réalisation.")

    recommendations: list[str] = []
    if periods:
        label = {"morning": "le matin", "afternoon": "l’après-midi",
                 "evening": "en soirée", "night": "la nuit"}[periods[0].period]
        origin = "tes sessions passées" if source == "observed" else "tes préférences déclarées"
        recommendations.append(f"Planifie tes révisions importantes {label} (d’après {origin}).")
    if indicators and indicators[0].level in {"medium", "high"}:
        recommendations.append(
            f"Consacre davantage de temps à « {indicators[0].subject} » cette semaine."
        )
    if typical and typical > 90:
        recommendations.append("Découpe tes sessions longues en blocs de 25 à 50 minutes avec pauses.")
    if rate is not None and rate < 0.5:
        recommendations.append("Réduis le nombre de tâches ouvertes et termine les plus anciennes d’abord.")
    if not recommendations:
        recommendations.append(
            "Enregistre tes sessions, tâches et notes pour obtenir un profil personnalisé."
        )

    return LearningProfileResult(
        model_version=MODEL_VERSION,
        status="insufficient_data" if sufficiency == "none" else "ok",
        data_sufficiency=sufficiency,
        period_source=source,
        preferred_periods=periods,
        preferred_learning_style=snapshot.preferred_learning_style,
        study_level=snapshot.study_level,
        typical_session_minutes=typical,
        average_grade_percent=None if average is None else round(average, 1),
        task_completion_rate=None if rate is None else round(rate, 3),
        difficulty_indicators=indicators,
        recommendations=recommendations,
        missing_data=missing,
    )
