from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_user
from app.api.dependencies import get_task_service
from app.models.task import StudyTask
from app.models.user import User
from app.schemas.task import TaskCreate, TaskResponse, TaskUpdate
from app.services.task_service import TaskService

router = APIRouter()


@router.get("", response_model=list[TaskResponse])
def list_tasks(
    service: TaskService = Depends(get_task_service),
    user: User = Depends(get_current_user),
) -> list[StudyTask]:
    return service.list_tasks(user.firebase_uid)


@router.get("/{task_id}", response_model=TaskResponse)
def read_task(
    task_id: UUID,
    service: TaskService = Depends(get_task_service),
    user: User = Depends(get_current_user),
) -> StudyTask:
    return service.get_task(task_id, user.firebase_uid)


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(
    payload: TaskCreate,
    service: TaskService = Depends(get_task_service),
    user: User = Depends(get_current_user),
) -> StudyTask:
    return service.create_task(user.firebase_uid, payload.model_dump())


@router.patch("/{task_id}", response_model=TaskResponse)
def update_task(
    task_id: UUID,
    payload: TaskUpdate,
    service: TaskService = Depends(get_task_service),
    user: User = Depends(get_current_user),
) -> StudyTask:
    return service.update_task(
        task_id, user.firebase_uid, payload.model_dump(exclude_unset=True)
    )


@router.put("/{task_id}", response_model=TaskResponse)
def replace_task(
    task_id: UUID,
    payload: TaskUpdate,
    service: TaskService = Depends(get_task_service),
    user: User = Depends(get_current_user),
) -> StudyTask:
    return service.update_task(
        task_id, user.firebase_uid, payload.model_dump(exclude_unset=True)
    )


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: UUID,
    service: TaskService = Depends(get_task_service),
    user: User = Depends(get_current_user),
) -> Response:
    service.delete_task(task_id, user.firebase_uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
