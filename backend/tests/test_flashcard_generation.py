import json

from app.main import app
from app.services.ai_service import LLMError, get_llm_provider

CARDS = {
    "cards": [
        {"question": "Qu'est-ce qu'une mitochondrie ?", "answer": "La centrale énergétique de la cellule."},
        {"question": "Que contient le noyau ?", "answer": "L'ADN de la cellule."},
        {"question": "Rôle de la membrane ?", "answer": "Contrôler les échanges."},
    ]
}

NOTE_TEXT = (
    "La mitochondrie est l'organite qui produit l'énergie de la cellule. "
    "Le noyau contient l'ADN. La membrane plasmique contrôle les échanges."
)


class FakeProvider:
    def __init__(self, replies):
        self.replies = list(replies)
        self.calls = 0

    def complete(self, messages, json_mode=False):
        self.calls += 1
        reply = self.replies.pop(0)
        if isinstance(reply, Exception):
            raise reply
        return reply


def _deck(client) -> str:
    response = client.post("/api/v1/flashcard-decks", json={"title": "Biologie"})
    assert response.status_code == 201
    return response.json()["id"]


def _grant(client) -> None:
    assert client.put("/api/v1/ai/consent", json={"granted": True}).status_code == 200


def test_generates_cards_with_ai_from_text(client):
    provider = FakeProvider([json.dumps(CARDS)])
    app.dependency_overrides[get_llm_provider] = lambda: provider
    _grant(client)
    deck_id = _deck(client)

    response = client.post(
        f"/api/v1/flashcard-decks/{deck_id}/generate",
        json={"text": NOTE_TEXT, "max_cards": 5},
    )

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["source"] == "ai"
    assert len(body["cards"]) == 3
    assert all(card["deck_id"] == deck_id for card in body["cards"])
    assert provider.calls == 1
    listed = client.get(f"/api/v1/flashcard-decks/{deck_id}/cards").json()
    assert len(listed) == 3
    assert client.get(f"/api/v1/flashcard-decks/{deck_id}").json()["source"] == "ai_generated"


def test_generates_cards_from_a_note(client):
    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider([json.dumps(CARDS)])
    _grant(client)
    note = client.post("/api/v1/notes", json={"title": "Cellule", "content": NOTE_TEXT})
    assert note.status_code == 201
    deck_id = _deck(client)

    response = client.post(
        f"/api/v1/flashcard-decks/{deck_id}/generate",
        json={"note_id": note.json()["id"]},
    )

    assert response.status_code == 201, response.text
    assert response.json()["source"] == "ai"


def test_ai_generation_requires_consent(client):
    provider = FakeProvider([json.dumps(CARDS)])
    app.dependency_overrides[get_llm_provider] = lambda: provider
    deck_id = _deck(client)

    response = client.post(
        f"/api/v1/flashcard-decks/{deck_id}/generate", json={"text": NOTE_TEXT}
    )

    assert response.status_code == 403
    assert provider.calls == 0


def test_falls_back_to_rules_when_llm_fails(client):
    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider(
        [LLMError("down"), LLMError("down")]
    )
    _grant(client)
    deck_id = _deck(client)

    response = client.post(
        f"/api/v1/flashcard-decks/{deck_id}/generate", json={"text": NOTE_TEXT}
    )

    assert response.status_code == 201, response.text
    assert response.json()["source"] == "rules"
    assert len(response.json()["cards"]) >= 1


def test_generate_requires_exactly_one_source(client):
    deck_id = _deck(client)
    for payload in ({}, {"text": "   "}):
        response = client.post(
            f"/api/v1/flashcard-decks/{deck_id}/generate", json=payload
        )
        assert response.status_code == 422


def test_cannot_generate_into_another_users_deck(client):
    from app.api.deps import get_current_uid

    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider([json.dumps(CARDS)])
    deck_id = _deck(client)
    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    _grant(client)

    response = client.post(
        f"/api/v1/flashcard-decks/{deck_id}/generate", json={"text": NOTE_TEXT}
    )

    assert response.status_code == 404
