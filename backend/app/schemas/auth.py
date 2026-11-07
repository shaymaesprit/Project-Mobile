from pydantic import BaseModel


class SessionRead(BaseModel):
    """Identity facts taken from the verified Firebase ID token."""

    firebase_uid: str
    email: str | None
    email_verified: bool
    sign_in_provider: str | None
    expires_at: int | None
