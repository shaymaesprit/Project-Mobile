from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.extended import LearningProfile


class ProfileRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_for_owner(self, owner_uid: str) -> LearningProfile | None:
        return self._db.get(LearningProfile, owner_uid)

    def create(self, owner_uid: str) -> LearningProfile:
        profile = LearningProfile(owner_uid=owner_uid)
        self._db.add(profile)
        self._db.commit()
        self._db.refresh(profile)
        return profile

    def update(
        self, profile: LearningProfile, changes: dict
    ) -> LearningProfile:
        for field, value in changes.items():
            setattr(profile, field, value)
        profile.updated_at = self._db.scalar(select(func.now()))
        self._db.commit()
        self._db.refresh(profile)
        return profile
