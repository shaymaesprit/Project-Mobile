from app.models.extended import LearningProfile
from app.repositories.profile_repository import ProfileRepository


class ProfileService:
    def __init__(self, repository: ProfileRepository) -> None:
        self._repository = repository

    def get_or_create(self, owner_uid: str) -> LearningProfile:
        profile = self._repository.get_for_owner(owner_uid)
        return profile if profile is not None else self._repository.create(owner_uid)

    def update(self, owner_uid: str, changes: dict) -> LearningProfile:
        profile = self.get_or_create(owner_uid)
        return self._repository.update(profile, changes)
