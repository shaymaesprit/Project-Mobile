from uuid import UUID

from fastapi import APIRouter, Depends

from app.api.deps import get_current_uid
from app.api.dependencies import get_ai_service
from app.schemas.ai import (
    AIInsightResponse,
    AIRecommendationResponse,
    AIRecommendationUpdate,
    ChatRequest,
    ChatResponse,
    ConsentRead,
    ConsentUpdate,
)
from app.services.ai_service import AIService

router = APIRouter()


@router.get("/consent", response_model=ConsentRead)
def read_consent(
    uid: str = Depends(get_current_uid), service: AIService = Depends(get_ai_service)
) -> dict:
    return service.get_consent(uid)


@router.put("/consent", response_model=ConsentRead)
def update_consent(
    payload: ConsentUpdate,
    uid: str = Depends(get_current_uid),
    service: AIService = Depends(get_ai_service),
) -> dict:
    return service.set_consent(uid, payload.granted)


@router.get("/insights", response_model=list[AIInsightResponse])
def list_insights(
    uid: str = Depends(get_current_uid), service: AIService = Depends(get_ai_service)
):
    return service.list_insights(uid)


@router.post("/profile/analyze", response_model=AIInsightResponse)
def analyze_profile(
    uid: str = Depends(get_current_uid), service: AIService = Depends(get_ai_service)
):
    return service.analyze_profile(uid)


@router.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    uid: str = Depends(get_current_uid),
    service: AIService = Depends(get_ai_service),
) -> ChatResponse:
    return ChatResponse(reply=service.chat(uid, payload.message))


@router.post("/recommendations", response_model=list[AIRecommendationResponse])
def generate_recommendations(
    uid: str = Depends(get_current_uid), service: AIService = Depends(get_ai_service)
):
    return service.generate_recommendations(uid)


@router.get("/recommendations", response_model=list[AIRecommendationResponse])
def list_recommendations(
    uid: str = Depends(get_current_uid), service: AIService = Depends(get_ai_service)
):
    return service.list_recommendations(uid)


@router.patch("/recommendations/{recommendation_id}", response_model=AIRecommendationResponse)
def update_recommendation(
    recommendation_id: UUID,
    payload: AIRecommendationUpdate,
    uid: str = Depends(get_current_uid),
    service: AIService = Depends(get_ai_service),
):
    return service.update_recommendation(
        uid, recommendation_id, payload.model_dump(exclude_unset=True)
    )
