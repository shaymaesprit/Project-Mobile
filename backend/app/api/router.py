from fastapi import APIRouter

from app.api.routes import (
    ai,
    auth,
    calendar,
    courses,
    devices,
    evaluations,
    events,
    flashcard_decks,
    flashcards,
    health,
    ml,
    notes,
    notifications,
    places,
    profile,
    schedule,
    study_sessions,
    tasks,
    timetable,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(
    devices.router, prefix="/users/me/devices", tags=["notification devices"]
)
api_router.include_router(profile.router, prefix="/profile", tags=["profile"])
api_router.include_router(courses.router, prefix="/courses", tags=["courses"])
api_router.include_router(schedule.router, prefix="/schedule", tags=["schedule"])
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
    study_sessions.router, prefix="/study-sessions", tags=["study sessions"]
)
api_router.include_router(ml.router, prefix="/ml", tags=["machine learning"])
api_router.include_router(ai.router, prefix="/ai", tags=["ai assistant"])
api_router.include_router(
    notifications.router, prefix="/notifications", tags=["notifications"]
)
<<<<<<< HEAD
api_router.include_router(timetable.router, prefix="/timetable", tags=["timetable"])
=======
api_router.include_router(calendar.router, prefix="/calendar", tags=["calendar"])
api_router.include_router(places.router, prefix="/places", tags=["places"])
>>>>>>> b7a7118cfc4af515b1ed0388a9eb6423ab592aa2
