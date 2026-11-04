from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_user
from app.api.dependencies import get_course_service
from app.models.course import Course
from app.models.user import User
from app.schemas.course import CourseCreate, CourseResponse, CourseUpdate
from app.services.course_service import CourseService

router = APIRouter()


@router.get("/schedule", response_model=list[CourseResponse])
def read_weekly_schedule(
    service: CourseService = Depends(get_course_service),
    user: User = Depends(get_current_user),
) -> list[Course]:
    return service.list_schedule(user.firebase_uid)


@router.get("", response_model=list[CourseResponse])
def list_courses(
    service: CourseService = Depends(get_course_service),
    user: User = Depends(get_current_user),
) -> list[Course]:
    return service.list_courses(user.firebase_uid)


@router.get("/{course_id}", response_model=CourseResponse)
def read_course(
    course_id: UUID,
    service: CourseService = Depends(get_course_service),
    user: User = Depends(get_current_user),
) -> Course:
    return service.get_course(course_id, user.firebase_uid)


@router.post("", response_model=CourseResponse, status_code=status.HTTP_201_CREATED)
def create_course(
    payload: CourseCreate,
    service: CourseService = Depends(get_course_service),
    user: User = Depends(get_current_user),
) -> Course:
    return service.create_course(user.firebase_uid, payload.model_dump())


@router.patch("/{course_id}", response_model=CourseResponse)
def update_course(
    course_id: UUID,
    payload: CourseUpdate,
    service: CourseService = Depends(get_course_service),
    user: User = Depends(get_current_user),
) -> Course:
    return service.update_course(
        course_id, user.firebase_uid, payload.model_dump(exclude_unset=True)
    )


@router.put("/{course_id}", response_model=CourseResponse)
def replace_course(
    course_id: UUID,
    payload: CourseUpdate,
    service: CourseService = Depends(get_course_service),
    user: User = Depends(get_current_user),
) -> Course:
    return service.update_course(
        course_id, user.firebase_uid, payload.model_dump(exclude_unset=True)
    )


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_course(
    course_id: UUID,
    service: CourseService = Depends(get_course_service),
    user: User = Depends(get_current_user),
) -> Response:
    service.delete_course(course_id, user.firebase_uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
