"""PDF de cours : envoi, liste, téléchargement, renommage, suppression."""

from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Response, UploadFile, status
from fastapi.responses import FileResponse

from app.api.dependencies import get_document_service
from app.api.deps import get_current_uid
from app.core.exceptions import InvalidResourceStateError
from app.models.extended import Document
from app.schemas.document import DocumentResponse, DocumentUpdate
from app.services.document_service import PDF_MIME, DocumentService

course_documents_router = APIRouter()
router = APIRouter()


def _with_counts(
    service: DocumentService, uid: str, documents: list[Document]
) -> list[DocumentResponse]:
    counts = service.chunk_counts(uid, [d.id for d in documents])
    return [
        DocumentResponse.model_validate(d).model_copy(update={"text_chunks": counts.get(d.id, 0)})
        for d in documents
    ]


@course_documents_router.get("/{course_id}/documents", response_model=list[DocumentResponse])
def list_course_documents(
    course_id: UUID,
    uid: str = Depends(get_current_uid),
    service: DocumentService = Depends(get_document_service),
) -> list[DocumentResponse]:
    return _with_counts(service, uid, service.list_for_course(course_id, uid))


@course_documents_router.post(
    "/{course_id}/documents",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
def upload_course_document(
    course_id: UUID,
    file: UploadFile = File(..., description="Fichier PDF du cours"),
    title: str | None = Form(default=None, max_length=240),
    uid: str = Depends(get_current_uid),
    service: DocumentService = Depends(get_document_service),
) -> DocumentResponse:
    if file.content_type not in (PDF_MIME, "application/octet-stream", None):
        raise InvalidResourceStateError("Seuls les fichiers PDF sont acceptés.")
    # On lit au plus max+1 octets : un fichier trop gros est refusé sans tout charger.
    data = file.file.read(service.max_bytes + 1)
    document = service.upload(uid, course_id, data=data, filename=file.filename, title=title)
    return _with_counts(service, uid, [document])[0]


@router.get("/{document_id}", response_model=DocumentResponse)
def read_document(
    document_id: UUID,
    uid: str = Depends(get_current_uid),
    service: DocumentService = Depends(get_document_service),
) -> DocumentResponse:
    return _with_counts(service, uid, [service.get(document_id, uid)])[0]


@router.get(
    "/{document_id}/file",
    response_class=FileResponse,
    responses={200: {"content": {PDF_MIME: {}}}},
)
def download_document(
    document_id: UUID,
    uid: str = Depends(get_current_uid),
    service: DocumentService = Depends(get_document_service),
) -> FileResponse:
    document, path = service.file_path(document_id, uid)
    return FileResponse(
        path,
        media_type=PDF_MIME,
        filename=f"{document.title}.pdf",
        content_disposition_type="inline",
        headers={"Cache-Control": "private, max-age=3600"},
    )


@router.patch("/{document_id}", response_model=DocumentResponse)
def rename_document(
    document_id: UUID,
    payload: DocumentUpdate,
    uid: str = Depends(get_current_uid),
    service: DocumentService = Depends(get_document_service),
) -> DocumentResponse:
    return _with_counts(service, uid, [service.rename(document_id, uid, payload.title)])[0]


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(
    document_id: UUID,
    uid: str = Depends(get_current_uid),
    service: DocumentService = Depends(get_document_service),
) -> Response:
    service.delete(document_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
