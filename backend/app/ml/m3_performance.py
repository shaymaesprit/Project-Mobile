"""M3 - Academic performance prediction.

An explainable linear model: ``score = intercept + sum(coef_i * (x_i - mean_i))``.
Without a trained artifact a documented heuristic baseline is used. No score is
produced when fewer than two graded evaluations exist.
"""

from app.ml import registry
from app.ml.common import (
    average_grade,
    clip,
    completion_rate,
    grade_trend,
    weekly_study_hours,
)
from app.ml.schemas import (
    Contribution,
    ModelInfo,
    PerformanceResult,
    RiskIndicator,
)
from app.ml.types import StudentSnapshot

MODEL_NAME = "m3_performance"
MIN_GRADES = 2

FEATURES = [
    "avg_grade",
    "grade_trend",
    "weekly_study_hours",
    "completion_rate",
    "attendance_rate",
    "difficulty",
]

LABELS = {
    "avg_grade": "Moyenne des notes",
    "grade_trend": "Tendance des notes",
    "weekly_study_hours": "Heures d’étude par semaine",
    "completion_rate": "Taux de réalisation des tâches",
    "attendance_rate": "Assiduité",
    "difficulty": "Part de matières difficiles",
}

# Heuristic baseline: the average grade is the anchor, other factors adjust it.
BASELINE = {
    "version": "m3-rules-1",
    "kind": "rules",
    "features": FEATURES,
    "coef": [1.0, 0.5, 0.3, 10.0, 8.0, -5.0],
    "means": [0.0, 0.0, 6.0, 0.7, 0.85, 0.2],
    "intercept": 0.0,
    "metrics": {},
}
DEFAULT_MARGIN = 8.0


def extract_features(snapshot: StudentSnapshot) -> dict[str, float | None]:
    difficulty = None
    declared = {name.strip().lower() for name in snapshot.declared_difficult_subjects}
    if snapshot.courses and declared:
        flagged = sum(c.title.strip().lower() in declared for c in snapshot.courses)
        difficulty = flagged / len(snapshot.courses)
    hours = weekly_study_hours(snapshot)
    return {
        "avg_grade": average_grade(snapshot.grades),
        "grade_trend": grade_trend(snapshot.grades),
        "weekly_study_hours": None if hours is None else clip(hours, 0, 30),
        "completion_rate": completion_rate(snapshot.tasks),
        "attendance_rate": snapshot.attendance_rate,
        "difficulty": difficulty,
    }


def _risks(features: dict[str, float | None], predicted: float) -> list[RiskIndicator]:
    risks: list[RiskIndicator] = []
    average = features["avg_grade"]
    if average is not None and average < 50:
        risks.append(RiskIndicator(code="low_average", level="high",
                                   message=f"Ta moyenne ({average:.0f} %) est sous 50 %."))
    elif average is not None and average < 60:
        risks.append(RiskIndicator(code="low_average", level="medium",
                                   message=f"Ta moyenne ({average:.0f} %) est sous 60 %."))
    trend = features["grade_trend"]
    if trend is not None and trend <= -3:
        risks.append(RiskIndicator(code="declining_grades", level="medium",
                                   message="Tes dernières notes sont en baisse."))
    rate = features["completion_rate"]
    if rate is not None and rate < 0.5:
        risks.append(RiskIndicator(code="low_task_completion", level="medium",
                                   message="Moins de la moitié de tes tâches sont terminées."))
    hours = features["weekly_study_hours"]
    if hours is not None and hours < 3:
        risks.append(RiskIndicator(code="low_study_time", level="medium",
                                   message="Tu étudies moins de 3 h par semaine."))
    attendance = features["attendance_rate"]
    if attendance is not None and attendance < 0.75:
        risks.append(RiskIndicator(code="low_attendance", level="high",
                                   message="Ton assiduité est inférieure à 75 %."))
    if predicted < 50:
        risks.append(RiskIndicator(code="failing_risk", level="high",
                                   message="Le score prédit est sous le seuil de réussite."))
    return risks


def predict_performance(
    snapshot: StudentSnapshot, model: dict | None = None
) -> PerformanceResult:
    if len(snapshot.grades) < MIN_GRADES:
        return PerformanceResult(
            status="insufficient_data",
            missing_data=[
                f"Au moins {MIN_GRADES} évaluations notées sont nécessaires pour "
                "estimer un score. Aucune prédiction n’est inventée."
            ],
        )

    artifact = model or registry.load_latest(MODEL_NAME) or BASELINE
    features = extract_features(snapshot)
    prediction = artifact["intercept"]
    explanation: list[Contribution] = []
    assumptions: list[str] = []

    for name, coef, mean in zip(artifact["features"], artifact["coef"], artifact["means"]):
        value = features.get(name)
        if value is None:
            value_used = mean
            if name != "avg_grade":
                assumptions.append(
                    f"« {LABELS[name]} » est inconnu : valeur de référence utilisée."
                )
        else:
            value_used = value
        contribution = coef * (value_used - mean)
        prediction += contribution
        if value is not None and abs(contribution) >= 0.5 or name == "avg_grade":
            explanation.append(
                Contribution(
                    feature=name,
                    value=None if value is None else round(value, 2),
                    contribution=round(contribution, 2),
                    text=f"{LABELS[name]} : {'+' if contribution >= 0 else ''}"
                    f"{contribution:.1f} point(s).",
                )
            )

    predicted = clip(prediction, 0, 100)
    kind = artifact.get("kind", "ridge")
    mae = (artifact.get("metrics") or {}).get("mae")
    margin = max(mae, 5.0) if mae else DEFAULT_MARGIN
    trained = kind != "rules"
    return PerformanceResult(
        status="ok",
        model=ModelInfo(
            version=artifact["version"],
            kind=kind,
            trained_on=artifact.get("trained_on"),
            mae=mae,
        ),
        predicted_score_percent=round(predicted, 1),
        range_low=round(clip(predicted - margin, 0, 100), 1),
        range_high=round(clip(predicted + margin, 0, 100), 1),
        confidence="medium" if trained and len(snapshot.grades) >= 5 else "low",
        risk_indicators=_risks(features, predicted),
        explanation=explanation,
        assumptions=assumptions,
    )
