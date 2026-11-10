"""Enrichissement des notes via Wikipédia."""

from fastapi import APIRouter, Depends, Query

from app.api.deps import get_current_uid
from app.api.dependencies import get_knowledge_service
from app.schemas.planning import WikipediaResult
from app.services.knowledge_service import KnowledgeService

router = APIRouter()


@router.get("/wikipedia", response_model=list[WikipediaResult])
def search_wikipedia(
    q: str = Query(min_length=2, max_length=120),
    lang: str = Query(default="fr", pattern="^(fr|en|ar)$"),
    _uid: str = Depends(get_current_uid),
    service: KnowledgeService = Depends(get_knowledge_service),
) -> list[dict]:
    return service.wikipedia(q, lang=lang)
