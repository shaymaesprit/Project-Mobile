from fastapi import Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.database.session import get_db
from app.models.extended import Evaluation, FlashcardDeck, StudyEvent
from app.models.user import User
from app.repositories.course_repository import CourseRepository
from app.repositories.health_repository import HealthRepository
from app.repositories.note_repository import NoteRepository
from app.repositories.task_repository import TaskRepository
from app.repositories.user_repository import UserRepository
from app.services.course_service import CourseService
from app.services.health_service import HealthService
from app.services.note_service import NoteService
from app.services.task_service import TaskService
from app.services.user_service import UserService
from app.repositories.profile_repository import ProfileRepository
from app.repositories.notification_repository import NotificationRepository
from app.repositories.flashcard_repository import FlashcardRepository
from app.services.profile_service import ProfileService
from app.services.evaluation_service import EvaluationService
from app.services.event_service import EventService
from app.services.flashcard_service import FlashcardService
from app.services.notification_service import NotificationService
from app.services.owned_resource_service import OwnedResourceService


def get_health_service(db: Session = Depends(get_db)) -> HealthService:
    return HealthService(HealthRepository(db))


def get_course_service(db: Session = Depends(get_db)) -> CourseService:
    return CourseService(CourseRepository(db))


def get_task_service(db: Session = Depends(get_db)) -> TaskService:
    return TaskService(TaskRepository(db))


def get_note_service(db: Session = Depends(get_db)) -> NoteService:
    return NoteService(NoteRepository(db))


def get_user_service(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> UserService:
    db.info["firebase_uid"] = user.firebase_uid
    return UserService(UserRepository(db))


def get_profile_service(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProfileService:
    db.info["firebase_uid"] = user.firebase_uid
    return ProfileService(ProfileRepository(db))


def _owned_resource_service(
    db: Session, model: type, label: str, owner_uid: str
) -> OwnedResourceService:
    from app.repositories.owned_resource_repository import OwnedResourceRepository
    from app.services.owned_resource_service import OwnedResourceService

    db.info["firebase_uid"] = owner_uid
    return OwnedResourceService(OwnedResourceRepository(db, model), label)


def get_flashcard_deck_service(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> OwnedResourceService:
    return _owned_resource_service(
        db, FlashcardDeck, "Flashcard deck", user.firebase_uid
    )


def get_flashcard_service(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FlashcardService:
    db.info["firebase_uid"] = user.firebase_uid
    return FlashcardService(FlashcardRepository(db))


def get_evaluation_service(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> EvaluationService:
    from app.repositories.owned_resource_repository import OwnedResourceRepository

    db.info["firebase_uid"] = user.firebase_uid
    return EvaluationService(OwnedResourceRepository(db, Evaluation))


def get_event_service(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> EventService:
    from app.repositories.owned_resource_repository import OwnedResourceRepository

    db.info["firebase_uid"] = user.firebase_uid
    return EventService(OwnedResourceRepository(db, StudyEvent))


def get_notification_service(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> NotificationService:
    db.info["firebase_uid"] = user.firebase_uid
    return NotificationService(NotificationRepository(db))
