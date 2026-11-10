"""PDF de cours : envoi, stockage, extraction du texte, lecture et suppression.

Les fichiers sont rangés sur le disque du serveur sous un nom généré
(``<dossier propriétaire>/<uuid>.pdf``) : le nom choisi par l'étudiant n'est
jamais utilisé comme chemin. Le texte est découpé en morceaux par page dans
``document_chunks`` pour servir à l'IA (génération de flashcards).
"""

from __future__ import annotations

import hashlib
import io
import logging
import re
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

from pypdf import PdfReader
from pypdf.errors import PdfReadError
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.core.exceptions import (
    DuplicateResourceError,
    InvalidReferenceError,
    InvalidResourceStateError,
    PayloadTooLargeError,
    ResourceNotFoundError,
)
from app.models.course import Course
from app.models.extended import Document, DocumentChunk

logger = logging.getLogger(__name__)

PDF_MIME = "application/pdf"
CHUNK_CHARS = 1_500
MAX_CHUNKS = 2_000
MAX_PAGES_PARSED = 500


def _owner_dir(owner_uid: str) -> str:
    # Dossier stable et sans caractère spécial, quel que soit l'identifiant.
    return hashlib.sha256(owner_uid.encode()).hexdigest()[:32]


def _clean_title(title: str | None, filename: str | None) -> str:
    raw = (title or "").strip() or Path(filename or "").stem.strip() or "Document PDF"
    raw = re.sub(r"[_]+", " ", raw)
    return re.sub(r"\s+", " ", raw)[:240]


def _split(text: str) -> list[str]:
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    if not text:
        return []
    pieces: list[str] = []
    while len(text) > CHUNK_CHARS:
        cut = text.rfind("\n", 0, CHUNK_CHARS)
        if cut < CHUNK_CHARS // 2:
            cut = text.rfind(" ", 0, CHUNK_CHARS)
        if cut < CHUNK_CHARS // 2:
            cut = CHUNK_CHARS
        pieces.append(text[:cut].strip())
        text = text[cut:].strip()
    if text:
        pieces.append(text)
    return [p for p in pieces if p]


class DocumentService:
    def __init__(self, db: Session, storage_dir: Path, max_bytes: int) -> None:
        self._db = db
        self._dir = storage_dir
        self._max_bytes = max_bytes

    @property
    def max_bytes(self) -> int:
        return self._max_bytes

    # ── lecture ────────────────────────────────────────────────────────────

    def list_for_course(self, course_id: UUID, owner_uid: str) -> list[Document]:
        self._require_course(course_id, owner_uid)
        return list(
            self._db.scalars(
                select(Document)
                .where(Document.owner_uid == owner_uid, Document.course_id == course_id)
                .order_by(Document.created_at.desc(), Document.title)
            )
        )

    def get(self, document_id: UUID, owner_uid: str) -> Document:
        document = self._db.scalar(
            select(Document).where(
                Document.id == document_id, Document.owner_uid == owner_uid
            )
        )
        if document is None:
            raise ResourceNotFoundError("Document not found.")
        return document

    def file_path(self, document_id: UUID, owner_uid: str) -> tuple[Document, Path]:
        document = self.get(document_id, owner_uid)
        path = self._resolve(document.storage_path)
        if path is None or not path.is_file():
            raise ResourceNotFoundError("Le fichier PDF est introuvable sur le serveur.")
        return document, path

    def text_for(self, document_id: UUID, owner_uid: str, limit: int) -> str:
        document = self.get(document_id, owner_uid)
        parts: list[str] = [document.title]
        size = len(document.title)
        for content in self._db.scalars(
            select(DocumentChunk.content)
            .where(
                DocumentChunk.owner_uid == owner_uid,
                DocumentChunk.document_id == document_id,
            )
            .order_by(DocumentChunk.chunk_index)
        ):
            parts.append(content)
            size += len(content)
            if size >= limit:
                break
        text = "\n\n".join(parts)[:limit]
        if len(text.strip()) <= len(document.title):
            raise InvalidResourceStateError(
                "Ce PDF ne contient pas de texte lisible (document scanné ?)."
            )
        return text

    # ── écriture ───────────────────────────────────────────────────────────

    def upload(
        self,
        owner_uid: str,
        course_id: UUID,
        *,
        data: bytes,
        filename: str | None,
        title: str | None = None,
    ) -> Document:
        self._require_course(course_id, owner_uid)
        if len(data) > self._max_bytes:
            raise PayloadTooLargeError(
                f"Le PDF dépasse {self._max_bytes // (1024 * 1024)} Mo."
            )
        if not data.lstrip()[:5].startswith(b"%PDF-"):
            raise InvalidResourceStateError("Le fichier n'est pas un PDF valide.")

        digest = hashlib.sha256(data).hexdigest()
        duplicate = self._db.scalar(
            select(Document.title).where(
                Document.owner_uid == owner_uid,
                Document.course_id == course_id,
                Document.sha256 == digest,
            )
        )
        if duplicate is not None:
            raise DuplicateResourceError(f"Ce PDF est déjà dans ce cours (« {duplicate} »).")

        pages = self._extract_pages(data)

        document_id = uuid4()
        relative = f"{_owner_dir(owner_uid)}/{document_id}.pdf"
        target = self._dir / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

        try:
            document = Document(
                id=document_id,
                owner_uid=owner_uid,
                course_id=course_id,
                title=_clean_title(title, filename),
                storage_path=relative,
                mime_type=PDF_MIME,
                file_size_bytes=len(data),
                sha256=digest,
                page_count=len(pages),
                processing_status="processing",
            )
            self._db.add(document)
            self._db.flush()

            index = 0
            for page_number, text in enumerate(pages, start=1):
                for piece in _split(text):
                    if index >= MAX_CHUNKS:
                        break
                    self._db.add(
                        DocumentChunk(
                            owner_uid=owner_uid,
                            document_id=document_id,
                            chunk_index=index,
                            content=piece,
                            page_number=page_number,
                            metadata_={"chars": len(piece)},
                        )
                    )
                    index += 1
            document.processing_status = "ready"
            self._db.commit()
        except Exception:
            self._db.rollback()
            target.unlink(missing_ok=True)
            raise
        self._db.refresh(document)
        return document

    def rename(self, document_id: UUID, owner_uid: str, title: str) -> Document:
        document = self.get(document_id, owner_uid)
        document.title = _clean_title(title, None)
        document.updated_at = datetime.now(timezone.utc)
        self._db.commit()
        self._db.refresh(document)
        return document

    def delete(self, document_id: UUID, owner_uid: str) -> None:
        document = self.get(document_id, owner_uid)
        path = self._resolve(document.storage_path)
        self._db.execute(
            delete(DocumentChunk).where(
                DocumentChunk.owner_uid == owner_uid,
                DocumentChunk.document_id == document_id,
            )
        )
        self._db.delete(document)
        self._db.commit()
        if path is not None:
            path.unlink(missing_ok=True)

    # ── statistiques ───────────────────────────────────────────────────────

    def chunk_counts(self, owner_uid: str, ids: list[UUID]) -> dict[UUID, int]:
        if not ids:
            return {}
        rows = self._db.execute(
            select(DocumentChunk.document_id, func.count())
            .where(
                DocumentChunk.owner_uid == owner_uid,
                DocumentChunk.document_id.in_(ids),
            )
            .group_by(DocumentChunk.document_id)
        )
        return {doc_id: count for doc_id, count in rows}

    # ── interne ────────────────────────────────────────────────────────────

    def _require_course(self, course_id: UUID, owner_uid: str) -> None:
        exists = self._db.scalar(
            select(Course.id).where(Course.id == course_id, Course.owner_uid == owner_uid)
        )
        if exists is None:
            raise InvalidReferenceError("Course not found.")

    def _resolve(self, storage_path: str | None) -> Path | None:
        if not storage_path:
            return None
        root = self._dir.resolve()
        path = (root / storage_path).resolve()
        # Garde-fou : jamais en dehors du dossier de stockage.
        if root not in path.parents:
            return None
        return path

    @staticmethod
    def _extract_pages(data: bytes) -> list[str]:
        try:
            reader = PdfReader(io.BytesIO(data))
            if reader.is_encrypted and not reader.decrypt(""):
                raise InvalidResourceStateError(
                    "Ce PDF est protégé par un mot de passe : retire la protection puis réessaie."
                )
            pages: list[str] = []
            for number, page in enumerate(reader.pages):
                if number >= MAX_PAGES_PARSED:
                    pages.append("")
                    continue
                try:
                    pages.append(page.extract_text() or "")
                except Exception:  # page illisible : on garde le reste du document
                    logger.info("PDF page %s unreadable", number + 1)
                    pages.append("")
            return pages
        except InvalidResourceStateError:
            raise
        except (PdfReadError, ValueError, KeyError, TypeError) as exc:
            raise InvalidResourceStateError("Le fichier PDF est illisible ou corrompu.") from exc
