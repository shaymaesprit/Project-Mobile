import json

import pytest

from app.main import app
from app.services.ai_service import (
    LLMError,
    get_llm_provider,
    parse_recommendations,
    redact,
)

VALID = {
    "recommendations": [
        {
            "title": "Réviser les maths",
            "description": "Fais 3 exercices par jour.",
            "category": "revision",
            "priority": "high",
            "reason": "Moyenne basse",
            "suggested_action": "Planifier 30 minutes",
        }
    ]
}


class FakeProvider:
    def __init__(self, replies):
        self.replies = list(replies)
        self.calls = []

    def complete(self, messages, json_mode=False):
        self.calls.append(messages)
        reply = self.replies.pop(0)
        if isinstance(reply, Exception):
            raise reply
        return reply


def use_provider(provider):
    app.dependency_overrides[get_llm_provider] = lambda: provider


def grant(client):
    response = client.put("/api/v1/ai/consent", json={"granted": True})
    assert response.status_code == 200
    assert response.json()["granted"] is True


def test_consent_required_for_every_ai_feature(client):
    use_provider(FakeProvider([]))
    assert client.get("/api/v1/ai/consent").json()["granted"] is False
    assert client.post("/api/v1/ai/chat", json={"message": "salut"}).status_code == 403
    assert client.post("/api/v1/ai/recommendations").status_code == 403
    assert client.post("/api/v1/ai/profile/analyze").status_code == 403


def test_consent_can_be_revoked(client):
    use_provider(FakeProvider([]))
    grant(client)
    assert client.put("/api/v1/ai/consent", json={"granted": False}).json()["granted"] is False
    assert client.post("/api/v1/ai/chat", json={"message": "salut"}).status_code == 403


def test_chat_sends_anonymous_redacted_input(client):
    provider = FakeProvider(["Bonjour !"])
    use_provider(provider)
    grant(client)
    response = client.post(
        "/api/v1/ai/chat",
        json={"message": "Écris à a.b@mail.com ou au +33 6 12 34 56 78"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["reply"] == "Bonjour !"
    assert body["ai_generated"] is True and body["disclaimer"]
    sent = json.dumps(provider.calls[0], ensure_ascii=False)
    assert "a.b@mail.com" not in sent and "12 34 56" not in sent
    assert "firebase-user-a" not in sent


def test_chat_rejects_oversized_message_and_degrades_on_failure(client):
    use_provider(FakeProvider([LLMError("timeout")]))
    grant(client)
    assert client.post("/api/v1/ai/chat", json={"message": "x" * 1001}).status_code == 422
    assert client.post("/api/v1/ai/chat", json={"message": "bonjour"}).status_code == 503


def test_recommendations_validated_labelled_and_persisted(client):
    use_provider(FakeProvider([json.dumps(VALID)]))
    grant(client)
    response = client.post("/api/v1/ai/recommendations")
    assert response.status_code == 200
    item = response.json()[0]
    assert item["source"] == "ai" and item["ai_generated"] is True
    assert item["status"] == "pending"
    assert len(client.get("/api/v1/ai/recommendations").json()) == 1


def test_invalid_json_retries_then_succeeds(client):
    provider = FakeProvider(["pas du json", f"```json\n{json.dumps(VALID)}\n```"])
    use_provider(provider)
    grant(client)
    response = client.post("/api/v1/ai/recommendations")
    assert response.json()[0]["source"] == "ai"
    assert len(provider.calls) == 2


@pytest.mark.parametrize(
    "replies",
    [
        [LLMError("down")],
        ["nope", "still nope"],
        [json.dumps({"recommendations": [{"title": "ok ok", "description": "d d d",
                                           "category": "hack"}]})] * 2,
    ],
)
def test_provider_failure_falls_back_to_rules(client, replies):
    use_provider(FakeProvider(replies))
    grant(client)
    response = client.post("/api/v1/ai/recommendations")
    assert response.status_code == 200
    items = response.json()
    assert items and all(i["source"] == "rules" and i["ai_generated"] is False for i in items)


def test_no_provider_configured_uses_rules(client):
    use_provider(None)
    grant(client)
    assert client.post("/api/v1/ai/recommendations").json()[0]["source"] == "rules"
    assert client.post("/api/v1/ai/chat", json={"message": "hello"}).status_code == 503


def test_accept_modify_reject_flow(client):
    use_provider(FakeProvider([json.dumps(VALID)]))
    grant(client)
    rec_id = client.post("/api/v1/ai/recommendations").json()[0]["id"]
    url = f"/api/v1/ai/recommendations/{rec_id}"

    assert client.patch(url, json={"status": "modified"}).status_code == 422
    assert client.patch(url, json={"status": "accepted", "title": "xxx"}).status_code == 422
    modified = client.patch(url, json={"status": "modified", "title": "Nouveau titre"}).json()
    assert modified["status"] == "modified" and modified["title"] == "Nouveau titre"
    assert client.patch(url, json={"status": "rejected"}).json()["status"] == "rejected"


def test_recommendations_are_isolated_between_users(client, db_session):
    from app.api.deps import get_current_uid

    use_provider(FakeProvider([json.dumps(VALID)]))
    grant(client)
    rec_id = client.post("/api/v1/ai/recommendations").json()[0]["id"]

    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    assert client.get("/api/v1/ai/recommendations").json() == []
    assert client.patch(f"/api/v1/ai/recommendations/{rec_id}",
                        json={"status": "rejected"}).status_code == 404
    # consent is per user
    assert client.get("/api/v1/ai/consent").json()["granted"] is False


def test_profile_analysis_stored_as_insight(client):
    use_provider(FakeProvider(["Analyse courte."]))
    grant(client)
    insight = client.post("/api/v1/ai/profile/analyze").json()
    assert insight["ai_generated"] is True and insight["body"] == "Analyse courte."
    assert [i["id"] for i in client.get("/api/v1/ai/insights").json()] == [insight["id"]]

    use_provider(FakeProvider([LLMError("x")]))
    fallback = client.post("/api/v1/ai/profile/analyze").json()
    assert fallback["ai_generated"] is False and fallback["body"]


def test_helpers():
    assert redact("a@b.co et 0612345678") == "[email] et [téléphone]"
    with pytest.raises(LLMError):
        parse_recommendations('{"recommendations": []}')
