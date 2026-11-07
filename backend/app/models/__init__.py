from app.models.course import Course
from app.models.extended import (
    AIInsight,
    AIRecommendation,
    ChunkEmbedding,
    Document,
    DocumentChunk,
    Evaluation,
    Flashcard,
    FlashcardDeck,
    FlashcardReview,
    Gamification,
    LearningProfile,
    Notification,
    NotificationDevice,
    StudyEvent,
    StudySession,
)
from app.models.note import Note
from app.models.task import StudyTask
from app.models.user import User

__all__ = [
    "AIInsight",
    "AIRecommendation",
    "ChunkEmbedding",
    "Course",
    "Document",
    "DocumentChunk",
    "Evaluation",
    "Flashcard",
    "FlashcardDeck",
    "FlashcardReview",
    "Gamification",
    "LearningProfile",
    "Note",
    "Notification",
    "NotificationDevice",
    "StudyEvent",
    "StudySession",
    "StudyTask",
    "User",
]
