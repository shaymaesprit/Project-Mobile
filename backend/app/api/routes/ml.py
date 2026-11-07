from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_uid
from app.database.session import get_db
from app.ml.m1_learning_profile import analyze_learning_profile
from app.ml.m2_behavior import analyze_behavior
from app.ml.m3_performance import predict_performance
from app.ml.m4_recommendations import build_recommendations
from app.ml.schemas import (
    BehaviorResult,
    LearningProfileResult,
    PerformanceResult,
    RecommendationsResult,
)
from app.ml.snapshot import build_snapshot

router = APIRouter()


def _snapshot(db: Session, uid: str):
    db.info["firebase_uid"] = uid
    return build_snapshot(db, uid)


@router.get("/learning-profile", response_model=LearningProfileResult)
def learning_profile(
    uid: str = Depends(get_current_uid), db: Session = Depends(get_db)
) -> LearningProfileResult:
    return analyze_learning_profile(_snapshot(db, uid))


@router.get("/behavior", response_model=BehaviorResult)
def behavior(
    uid: str = Depends(get_current_uid), db: Session = Depends(get_db)
) -> BehaviorResult:
    return analyze_behavior(_snapshot(db, uid))


@router.get("/performance", response_model=PerformanceResult)
def performance(
    uid: str = Depends(get_current_uid), db: Session = Depends(get_db)
) -> PerformanceResult:
    return predict_performance(_snapshot(db, uid))


@router.get("/recommendations", response_model=RecommendationsResult)
def recommendations(
    uid: str = Depends(get_current_uid), db: Session = Depends(get_db)
) -> RecommendationsResult:
    snapshot = _snapshot(db, uid)
    return build_recommendations(
        snapshot,
        analyze_learning_profile(snapshot),
        analyze_behavior(snapshot),
        predict_performance(snapshot),
    )
