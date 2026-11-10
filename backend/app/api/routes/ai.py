from uuid import UUID

from fastapi import APIRouter, Depends

from app.api.deps import get_current_uid
from app.api.dependencies import get_ai_service, get_event_ai_service, get_task_service
from app.schemas.ai import (
    AIInsightResponse,
    AIRecommendationResponse,
    AIRecommendationUpdate,
    ChatRequest,
    ChatResponse,
    ConsentRead,
    ConsentUpdate,
    EventParseRequest,
)
from app.schemas.event import EventDraft
from app.schemas.planning import TaskBreakdownRequest, TaskBreakdownResponse
from app.services.ai_service import AIService, breakdown_task
from app.services.task_service import TaskService
from app.services.event_ai_service import EventAIService

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


@router.post("/events/parse", response_model=EventDraft)
def parse_event(
    payload: EventParseRequest,
    uid: str = Depends(get_current_uid),
    service: EventAIService = Depends(get_event_ai_service),
) -> EventDraft:
    """Transforme une phrase en brouillon d'événement (non enregistré)."""
    return service.parse(
        uid,
        payload.text,
        timezone_name=payload.timezone,
        utc_offset_minutes=payload.utc_offset_minutes,
    )


@router.post("/tasks/{task_id}/breakdown", response_model=TaskBreakdownResponse)
def breakdown(
    task_id: UUID,
    payload: TaskBreakdownRequest | None = None,
    uid: str = Depends(get_current_uid),
    service: AIService = Depends(get_ai_service),
    tasks: TaskService = Depends(get_task_service),
) -> dict:
    """Découpe une tâche en étapes avec l’IA ; peut créer les sous-tâches."""
    task = tasks.get_task(task_id, uid)
    steps = breakdown_task(service, uid, task.title, task.description)
    created: list = []
    if payload is not None and payload.create_tasks:
        for index, step in enumerate(steps, start=1):
            created.append(
                tasks.create_task(uid, {
                    "title": f"{index}. {step['title']}"[:200],
                    "description": f"Étape de « {task.title} » · ~{step['minutes']} min",
                    "priority": task.priority,
                    "deadline": task.deadline,
                    "course_id": task.course_id,
                }).id
            )
    return {"steps": steps, "created_task_ids": created}
