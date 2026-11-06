from fastapi import APIRouter

from app.api.routes import (
    auth,
    courses,
    evaluations,
    events,
    flashcard_decks,
    flashcards,
    health,
    notes,
    notifications,
    profile,
    tasks,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(profile.router, prefix="/profile", tags=["profile"])
api_router.include_router(courses.router, prefix="/courses", tags=["courses"])
api_router.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
api_router.include_router(notes.router, prefix="/notes", tags=["notes"])
api_router.include_router(flashcards.router, prefix="/flashcards", tags=["flashcards"])
api_router.include_router(
    flashcard_decks.router, prefix="/flashcard-decks", tags=["flashcard decks"]
)
api_router.include_router(
    evaluations.router, prefix="/evaluations", tags=["evaluations"]
)
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(
    notifications.router, prefix="/notifications", tags=["notifications"]
)
