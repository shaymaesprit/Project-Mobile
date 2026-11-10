"""AI-powered flashcard generator.

Generates question/answer pairs from a note or free text using:
  1. The configured LLM (OpenAI-compatible or Gemini) — requires AI consent.
  2. A lightweight rule-based fallback (keyword extraction) when the LLM is
     unavailable or the user has not given consent.

The rule-based engine never calls any external service.

Prompt design principles:
  * Only the note content is sent — no user PII.
  * The LLM is asked for strict JSON only, with one corrective retry.
  * Cards are validated with Pydantic before being saved.
"""

from __future__ import annotations

import json
import logging
import re
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field, ValidationError
from sqlalchemy.orm import Session

from app.core.exceptions import (
    AIConsentRequiredError,
    ResourceNotFoundError,
)
from app.models.extended import Flashcard, FlashcardDeck, LearningProfile
from app.repositories.flashcard_repository import FlashcardRepository
from app.services.ai_service import LLMError, LLMProvider

logger = logging.getLogger("studymate.flashcard_generator")

MAX_NOTE_CHARS = 6_000   # keep prompts cheap
MAX_AI_CARDS   = 15      # safety cap per generation

# ─── Pydantic card draft ─────────────────────────────────────────────────────

class _CardDraft(BaseModel):
    question: str = Field(min_length=3, max_length=500)
    answer:   str = Field(min_length=1, max_length=1000)


class _CardBatch(BaseModel):
    cards: list[_CardDraft] = Field(min_length=1, max_length=MAX_AI_CARDS)


# ─── Prompts ─────────────────────────────────────────────────────────────────

_SYSTEM = (
    "Tu es un assistant pédagogique spécialisé dans la création de flashcards. "
    "Tu génères des cartes question/réponse claires, concises et pédagogiquement "
    "pertinentes à partir du contenu d'une note d'étudiant. "
    "Réponds UNIQUEMENT avec un objet JSON valide — aucun texte hors du JSON."
)

_USER_TMPL = (
    "Crée entre {min_cards} et {max_cards} flashcards question/réponse à partir "
    "du contenu suivant. Chaque question doit porter sur un concept, une définition "
    "ou un fait important. Les réponses doivent être brèves (1-3 phrases max).\n\n"
    "Contenu :\n---\n{content}\n---\n\n"
    'Réponds UNIQUEMENT avec: {{"cards":[{{"question":"...","answer":"..."}},...]}}'
)


# ─── Rule-based fallback ──────────────────────────────────────────────────────

_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")
_DEF_PATTERN  = re.compile(
    r"^(.{10,100}?)\s+(?:est|sont|désigne|désignent|se définit|signifie|correspond à)\s+(.{10,})",
    re.IGNORECASE,
)
_COLON_PATTERN = re.compile(r"^(.{5,80})\s*:\s*(.{10,})")


def _rule_based_cards(text: str, max_cards: int = 5) -> list[dict[str, str]]:
    """Extract simple Q/A pairs from text without any external service."""
    sentences = [s.strip() for s in _SENTENCE_END.split(text) if len(s.strip()) > 20]
    cards: list[dict[str, str]] = []

    for sentence in sentences:
        if len(cards) >= max_cards:
            break
        m = _DEF_PATTERN.match(sentence) or _COLON_PATTERN.match(sentence)
        if m:
            question = f"Qu'est-ce que {m.group(1).strip()} ?"
            answer   = m.group(2).strip().rstrip(".")
            cards.append({"question": question, "answer": answer})

    # Fill remaining slots with generic "What does this sentence say?" cards
    for sentence in sentences:
        if len(cards) >= max_cards:
            break
        if not any(c["answer"] in sentence for c in cards):
            # Only use longer sentences as generic cards
            if len(sentence) > 60:
                cards.append({
                    "question": f"Que signifie ou décrit l'énoncé suivant ? « {sentence[:120]}… »"
                                if len(sentence) > 120 else f"Expliquez : « {sentence} »",
                    "answer": sentence,
                })

    return cards[:max_cards]


# ─── Main service ─────────────────────────────────────────────────────────────

class FlashcardGeneratorService:
    """Generates flashcards for a deck from a note or raw text."""

    def __init__(
        self,
        db: Session,
        flashcard_repo: FlashcardRepository,
        provider: LLMProvider | None,
    ) -> None:
        self._db      = db
        self._repo    = flashcard_repo
        self._provider = provider

    def generate(
        self,
        deck_id: UUID,
        owner_uid: str,
        *,
        note_id:   UUID | None = None,
        document_id: UUID | None = None,
        raw_text:  str  | None = None,
        min_cards: int = 3,
        max_cards: int = 10,
        require_consent: bool = True,
    ) -> tuple[list[Flashcard], str]:
        """Generate cards and persist them to the deck.

        Either ``note_id`` (looks up the user's note) or ``raw_text`` must be
        provided.  Returns the newly created :class:`Flashcard` rows and the
        source that produced them (``"ai"`` or ``"rules"``).

        Raises :class:`AIConsentRequiredError` when the LLM is configured but
        the user has not granted AI consent (and ``require_consent`` is set).
        """
        # 1 — resolve the deck
        deck = self._db.get(FlashcardDeck, deck_id)
        if deck is None or deck.owner_uid != owner_uid:
            raise ResourceNotFoundError("Flashcard deck not found.")

        # 2 — resolve the content
        content = self._resolve_content(note_id, raw_text, owner_uid, document_id)

        # 3 — check AI consent when the LLM will be used
        ai_available = self._provider is not None
        if ai_available and require_consent and not self._has_consent(owner_uid):
            raise AIConsentRequiredError(
                "AI consent is required before generating flashcards with AI."
            )

        # 4 — generate drafts
        source = "rules"
        drafts: list[dict[str, str]] = []

        if ai_available:
            try:
                drafts = self._ai_generate(content, min_cards, max_cards)
                source = "ai"
            except LLMError as exc:
                logger.warning("LLM generation failed (%s) — falling back to rules.", exc)

        if not drafts:
            drafts = _rule_based_cards(content, max_cards)

        if not drafts:
            # Even rules produced nothing — provide a generic placeholder card
            drafts = [{
                "question": "Résumez le contenu principal de cette note.",
                "answer":   content[:500],
            }]

        # 5 — persist
        cards: list[Flashcard] = []
        for draft in drafts[:max_cards]:
            card = self._repo.create(owner_uid, {
                "deck_id":   deck_id,
                "course_id": deck.course_id,
                "question":  draft["question"],
                "answer":    draft["answer"],
            })
            cards.append(card)

        # 6 — mark deck as ai_generated if the LLM was used
        if source == "ai" and deck.source != "ai_generated":
            deck.source = "ai_generated"
            self._db.commit()

        return cards, source

    # ── private ──────────────────────────────────────────────────────────────

    def _has_consent(self, owner_uid: str) -> bool:
        # Même stockage que AIService.get_consent : preferences["ai_consent"].
        profile = self._db.get(LearningProfile, owner_uid)
        consent = ((profile.preferences if profile else None) or {}).get("ai_consent")
        return isinstance(consent, dict) and consent.get("granted") is True

    def _resolve_content(
        self,
        note_id: UUID | None,
        raw_text: str | None,
        owner_uid: str,
        document_id: UUID | None = None,
    ) -> str:
        if document_id is not None:
            # PDF de cours : texte extrait à l'envoi (document_chunks).
            from app.core.config import get_settings
            from app.services.document_service import DocumentService

            settings = get_settings()
            documents = DocumentService(
                self._db, settings.documents_dir, settings.document_max_mb * 1024 * 1024
            )
            return documents.text_for(document_id, owner_uid, MAX_NOTE_CHARS)
        if note_id is not None:
            from app.models.note import Note
            note = self._db.get(Note, note_id)
            if note is None or note.owner_uid != owner_uid:
                raise ResourceNotFoundError("Note not found.")
            text = f"{note.title}\n\n{note.content}"
        elif raw_text:
            text = raw_text
        else:
            raise ValueError("Either note_id or raw_text must be provided.")

        return text[:MAX_NOTE_CHARS]

    def _ai_generate(
        self,
        content: str,
        min_cards: int,
        max_cards: int,
    ) -> list[dict[str, str]]:
        prompt = _USER_TMPL.format(
            min_cards=min_cards,
            max_cards=max_cards,
            content=content,
        )
        messages = [
            {"role": "system", "content": _SYSTEM},
            {"role": "user",   "content": prompt},
        ]

        last_error: Exception | None = None
        raw = ""
        for attempt in range(2):
            try:
                raw = self._provider.complete(messages, json_mode=True)  # type: ignore[union-attr]
                data = json.loads(raw)
                batch = _CardBatch.model_validate(data)
                return [c.model_dump() for c in batch.cards]
            except (json.JSONDecodeError, ValidationError, LLMError) as exc:
                last_error = exc
                if attempt == 0:
                    messages += [
                        {"role": "assistant", "content": raw[:2000]},
                        {"role": "user",
                         "content": "Le JSON est invalide. Renvoie uniquement un JSON "
                                    'conforme au schéma {"cards":[{"question":"...","answer":"..."},...]}'},
                    ]

        raise LLMError(str(last_error))
