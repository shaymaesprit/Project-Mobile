from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ApiSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserRead(ApiSchema):
    firebase_uid: str
    email: str | None
    display_name: str | None
    created_at: datetime


class CourseRead(ApiSchema):
    id: UUID
    title: str
    code: str | None
    professor: str | None
    room: str | None
    color: str | None = None
    created_at: datetime
    updated_at: datetime


class TaskRead(ApiSchema):
    id: UUID
    course_id: UUID | None
    title: str
    description: str | None
    priority: str
    deadline: datetime | None
    is_completed: bool
    completed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class NoteRead(ApiSchema):
    id: UUID
    course_id: UUID | None
    title: str
    content: str
    created_at: datetime
    updated_at: datetime
