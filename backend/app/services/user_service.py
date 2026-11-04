from app.models.user import User
from app.repositories.user_repository import UserRepository


class UserService:
    def __init__(self, repository: UserRepository) -> None:
        self._repository = repository

    def get_or_create(
        self,
        firebase_uid: str,
        initial_profile: dict[str, str] | None = None,
    ) -> User:
        user = self._repository.get_by_uid(firebase_uid)
        if user is not None:
            return user
        return self._repository.create(firebase_uid, initial_profile)

    def update(self, user: User, changes: dict) -> User:
        return self._repository.update(user, changes)

    def delete(self, user: User) -> None:
        self._repository.delete(user)
