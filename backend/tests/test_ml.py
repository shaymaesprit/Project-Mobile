from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.ml import registry
from app.ml.m1_learning_profile import analyze_learning_profile
from app.ml.m2_behavior import analyze_behavior
from app.ml.m3_performance import BASELINE, predict_performance
from app.ml.m4_recommendations import build_recommendations
from app.ml.types import (
    CourseRecord,
    GradeRecord,
    SessionRecord,
    StudentSnapshot,
    TaskRecord,
)

NOW = datetime(2025, 3, 12, 10, 0, tzinfo=timezone.utc)  # a Wednesday


def _sessions(count: int, hour: int = 20, minutes: float = 50, focus: int | None = 4):
    return [
        SessionRecord(
            started_local=(NOW - timedelta(days=i)).replace(hour=hour),
            duration_minutes=minutes,
            focus_rating=focus,
        )
        for i in range(1, count + 1)
    ]


def _grades(values: list[float], course_id=None):
    return [
        GradeRecord(percent=v, course_id=course_id, scheduled_at=NOW - timedelta(days=30 - i * 5))
        for i, v in enumerate(values)
    ]


def test_cold_start_returns_no_invented_data():
    snapshot = StudentSnapshot(now=NOW)
    profile = analyze_learning_profile(snapshot)
    behavior = analyze_behavior(snapshot)
    performance = predict_performance(snapshot)
    assert profile.status == "insufficient_data"
    assert profile.preferred_periods == []
    assert behavior.status == "insufficient_data"
    assert behavior.productivity_score is None
    assert performance.status == "insufficient_data"
    assert performance.predicted_score_percent is None

    recommendations = build_recommendations(snapshot, profile, behavior, performance)
    assert recommendations.cold_start is True
    assert recommendations.subjects_needing_attention == []
    assert recommendations.notes


def test_declared_hours_used_until_enough_sessions():
    snapshot = StudentSnapshot(now=NOW, declared_preferred_hours=[8, 9, 20])
    profile = analyze_learning_profile(snapshot)
    assert profile.period_source == "declared"
    assert profile.preferred_periods[0].period == "morning"

    snapshot.sessions = _sessions(8, hour=21)
    profile = analyze_learning_profile(snapshot)
    assert profile.period_source == "observed"
    assert profile.preferred_periods[0].period == "evening"
    assert profile.typical_session_minutes == 50


def test_difficulty_indicators_use_grades_and_declarations():
    course = CourseRecord(id=uuid4(), title="Maths")
    snapshot = StudentSnapshot(
        now=NOW,
        courses=[course],
        grades=_grades([40, 45], course.id),
        declared_difficult_subjects=["maths"],
    )
    indicators = analyze_learning_profile(snapshot).difficulty_indicators
    assert indicators[0].subject == "Maths"
    assert indicators[0].level == "high"


def test_behavior_score_and_classification():
    snapshot = StudentSnapshot(
        now=NOW,
        sessions=_sessions(24, focus=5),
        tasks=[TaskRecord(is_completed=True) for _ in range(5)],
        daily_goal_minutes=45,
    )
    result = analyze_behavior(snapshot)
    assert result.status == "ok"
    assert 0 <= result.productivity_score <= 100
    assert result.classification == "consistent"
    assert result.sessions_count == 24

    sparse = analyze_behavior(StudentSnapshot(now=NOW, sessions=_sessions(2)))
    assert sparse.status == "insufficient_data"


def test_behavior_ignores_missing_components():
    snapshot = StudentSnapshot(now=NOW, sessions=_sessions(10, focus=None))
    result = analyze_behavior(snapshot)
    assert result.status == "ok"
    assert result.average_focus is None
    assert result.missing_data


def test_performance_needs_two_grades():
    snapshot = StudentSnapshot(now=NOW, grades=_grades([70]))
    assert predict_performance(snapshot).status == "insufficient_data"


def test_performance_baseline_is_bounded_and_explained():
    snapshot = StudentSnapshot(now=NOW, grades=_grades([95, 98, 99]), attendance_rate=1.0,
                               sessions=_sessions(20, minutes=120))
    result = predict_performance(snapshot)
    assert result.status == "ok"
    assert 0 <= result.range_low <= result.predicted_score_percent <= result.range_high <= 100
    assert result.model.kind == "rules"
    assert result.confidence == "low"
    assert result.explanation
    assert result.assumptions  # unknown factors are disclosed


def test_performance_reflects_study_effort():
    base = dict(now=NOW, grades=_grades([60, 62, 61]))
    low = predict_performance(StudentSnapshot(**base, attendance_rate=0.6))
    high = predict_performance(StudentSnapshot(**base, attendance_rate=1.0))
    assert high.predicted_score_percent > low.predicted_score_percent
    assert any(r.code == "low_attendance" for r in low.risk_indicators)


def test_trained_artifact_is_used_and_versioned(tmp_path):
    artifact = {**BASELINE, "kind": "ridge", "trained_on": "synthetic",
                "metrics": {"mae": 3.0}}
    path = registry.save_artifact("m3_performance", artifact, root=tmp_path)
    assert path.name == "v0001.json"
    assert registry.save_artifact("m3_performance", artifact, root=tmp_path).name == "v0002.json"
    loaded = registry.load_latest("m3_performance", root=tmp_path)
    assert loaded["version"] == "m3_performance-v0002"

    snapshot = StudentSnapshot(now=NOW, grades=_grades([60, 65, 70, 72, 75]))
    result = predict_performance(snapshot, model=loaded)
    assert result.model.kind == "ridge"
    assert result.model.mae == 3.0
    assert result.confidence == "medium"


def test_registry_rejects_corrupt_artifact(tmp_path):
    directory = tmp_path / "m3_performance"
    directory.mkdir()
    (directory / "v0001.json").write_text("{not json", encoding="utf-8")
    assert registry.load_latest("m3_performance", root=tmp_path) is None


def test_recommendations_avoid_class_times_and_rank_subjects():
    hard = CourseRecord(id=uuid4(), title="Physique")
    easy = CourseRecord(id=uuid4(), title="Sport")
    # Wednesday (weekday 2) class occupies 20h
    busy = CourseRecord(id=uuid4(), title="TD", weekday=2, start_hour=19, end_hour=21)
    snapshot = StudentSnapshot(
        now=NOW,
        courses=[hard, easy, busy],
        sessions=_sessions(10, hour=20),
        grades=_grades([35, 40], hard.id) + _grades([90, 92], easy.id),
        tasks=[TaskRecord(is_completed=False, course_id=hard.id,
                          deadline=NOW - timedelta(days=2)) for _ in range(3)],
    )
    profile = analyze_learning_profile(snapshot)
    behavior = analyze_behavior(snapshot)
    performance = predict_performance(snapshot)
    result = build_recommendations(snapshot, profile, behavior, performance)

    assert result.cold_start is False
    assert result.subjects_needing_attention[0].subject == "Physique"
    assert all(
        not (s.weekday == 2 and 19 <= s.start_hour < 21) for s in result.suggested_sessions
    )
    assert 1 <= len(result.suggested_sessions) <= 3


@pytest.fixture
def seeded(client, db_session):
    from app.models.extended import Evaluation, StudySession
    from app.models.user import User

    for uid in ("firebase-user-a", "firebase-user-b"):
        db_session.add(User(firebase_uid=uid))
    db_session.flush()
    now = datetime.now(timezone.utc)
    for i in range(6):
        db_session.add(StudySession(owner_uid="firebase-user-a",
                                    started_at=now - timedelta(days=i + 1),
                                    duration_seconds=3000, focus_rating=4))
    db_session.add(StudySession(owner_uid="firebase-user-b", started_at=now,
                                duration_seconds=7200))
    for score in (12, 14):
        db_session.add(Evaluation(owner_uid="firebase-user-a", title="e", score=score,
                                  max_score=20))
    db_session.commit()
    return client


def test_ml_endpoints_use_only_current_user_data(seeded):
    behavior = seeded.get("/api/v1/ml/behavior").json()
    assert behavior["sessions_count"] == 6
    performance = seeded.get("/api/v1/ml/performance").json()
    assert performance["status"] == "ok"
    assert seeded.get("/api/v1/ml/learning-profile").status_code == 200
    assert seeded.get("/api/v1/ml/recommendations").status_code == 200


def test_study_session_endpoints(client):
    response = client.post(
        "/api/v1/study-sessions",
        json={"started_at": "2025-03-01T10:00:00+00:00",
              "ended_at": "2025-03-01T10:45:00+00:00", "focus_rating": 4},
    )
    assert response.status_code == 201
    assert response.json()["duration_seconds"] == 2700
    assert client.post("/api/v1/study-sessions",
                       json={"started_at": "2025-03-01T10:00:00"}).status_code == 422
    assert client.post("/api/v1/study-sessions",
                       json={"started_at": "2025-03-01T10:00:00+00:00",
                             "duration_seconds": 60, "focus_rating": 9}).status_code == 422
    assert len(client.get("/api/v1/study-sessions").json()) == 1
    assert client.delete(f"/api/v1/study-sessions/{response.json()['id']}").status_code == 204
