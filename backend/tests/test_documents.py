import json

import pytest

from app.core.config import get_settings
from app.main import app
from app.services.ai_service import get_llm_provider

CARDS = {
    "cards": [
        {"question": "Qu'est-ce que la photosynthèse ?", "answer": "La production de sucre grâce à la lumière."},
        {"question": "Où a-t-elle lieu ?", "answer": "Dans les chloroplastes."},
        {"question": "Quel gaz est libéré ?", "answer": "Le dioxygène."},
    ]
}


def make_pdf(*pages: str) -> bytes:
    """Construit un vrai PDF (texte Helvetica, une ligne par page)."""
    objects: list[bytes] = []
    kids = " ".join(f"{3 + 2 * i} 0 R" for i in range(len(pages)))
    font_id = 3 + 2 * len(pages)
    objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
    objects.append(f"<< /Type /Pages /Kids [{kids}] /Count {len(pages)} >>".encode())
    for i, text in enumerate(pages):
        content_id = 4 + 2 * i
        objects.append(
            (
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
                f"/Contents {content_id} 0 R /Resources << /Font << /F1 {font_id} 0 R >> >> >>"
            ).encode()
        )
        stream = f"BT /F1 12 Tf 72 760 Td ({text}) Tj ET".encode("latin-1")
        objects.append(
            b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream"
        )
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{number} 0 obj\n".encode() + body + b"\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    for offset in offsets:
        out += f"{offset:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    return bytes(out)


LESSON = make_pdf(
    "La photosynthese produit du sucre grace a la lumiere.",
    "Elle a lieu dans les chloroplastes et libere du dioxygene.",
)


class FakeProvider:
    def __init__(self, reply: str) -> None:
        self.reply = reply
        self.prompts: list[str] = []

    def complete(self, messages, json_mode=False):
        self.prompts.append(messages[-1]["content"])
        return self.reply


@pytest.fixture(autouse=True)
def storage(tmp_path, monkeypatch):
    monkeypatch.setattr(get_settings(), "documents_dir", tmp_path / "documents")
    monkeypatch.setattr(get_settings(), "document_max_mb", 1)
    return tmp_path / "documents"


def _course(client) -> str:
    response = client.post("/api/v1/courses", json={"title": "Biologie végétale"})
    assert response.status_code == 201, response.text
    return response.json()["id"]


def _upload(client, course_id: str, data: bytes = LESSON, name: str = "chapitre_1.pdf", **form):
    return client.post(
        f"/api/v1/courses/{course_id}/documents",
        files={"file": (name, data, "application/pdf")},
        data=form,
    )


def test_upload_list_download_and_delete_a_course_pdf(client, storage):
    course_id = _course(client)

    response = _upload(client, course_id)
    assert response.status_code == 201, response.text
    document = response.json()
    assert document["title"] == "chapitre 1"
    assert document["page_count"] == 2
    assert document["processing_status"] == "ready"
    assert document["text_chunks"] == 2
    assert document["file_size_bytes"] == len(LESSON)

    # Le fichier est rangé sous un nom généré, pas sous le nom envoyé.
    stored = list(storage.rglob("*.pdf"))
    assert len(stored) == 1 and stored[0].name == f"{document['id']}.pdf"

    listed = client.get(f"/api/v1/courses/{course_id}/documents").json()
    assert [d["id"] for d in listed] == [document["id"]]

    downloaded = client.get(f"/api/v1/documents/{document['id']}/file")
    assert downloaded.status_code == 200
    assert downloaded.headers["content-type"] == "application/pdf"
    assert downloaded.content == LESSON

    renamed = client.patch(f"/api/v1/documents/{document['id']}", json={"title": "Photosynthèse"})
    assert renamed.json()["title"] == "Photosynthèse"

    assert client.delete(f"/api/v1/documents/{document['id']}").status_code == 204
    assert client.get(f"/api/v1/courses/{course_id}/documents").json() == []
    assert list(storage.rglob("*.pdf")) == []


def test_custom_title_is_used(client):
    course_id = _course(client)
    response = _upload(client, course_id, title="  Cours n°1  ")
    assert response.json()["title"] == "Cours n°1"


def test_rejects_files_that_are_not_pdf(client):
    course_id = _course(client)
    response = _upload(client, course_id, data=b"MZ\x90\x00 pas un pdf", name="virus.pdf")
    assert response.status_code == 422
    assert "PDF" in response.json()["detail"]


def test_rejects_corrupted_pdf(client):
    course_id = _course(client)
    response = _upload(client, course_id, data=b"%PDF-1.4\nrien de valide", name="casse.pdf")
    assert response.status_code == 422


def test_rejects_too_large_pdf(client):
    course_id = _course(client)
    big = LESSON + b"%" + b"0" * (1024 * 1024)
    response = _upload(client, course_id, data=big)
    assert response.status_code == 413


def test_same_pdf_twice_in_a_course_is_refused(client):
    course_id = _course(client)
    assert _upload(client, course_id).status_code == 201
    again = _upload(client, course_id, name="copie.pdf")
    assert again.status_code == 409
    assert "chapitre 1" in again.json()["detail"]


def test_unknown_course_is_refused(client):
    response = _upload(client, "00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404


def test_documents_are_private_to_their_owner(client):
    from app.api.deps import get_current_uid

    course_id = _course(client)
    document_id = _upload(client, course_id).json()["id"]

    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    assert client.get(f"/api/v1/documents/{document_id}").status_code == 404
    assert client.get(f"/api/v1/documents/{document_id}/file").status_code == 404
    assert client.delete(f"/api/v1/documents/{document_id}").status_code == 404


def test_generates_flashcards_from_a_pdf(client):
    provider = FakeProvider(json.dumps(CARDS))
    app.dependency_overrides[get_llm_provider] = lambda: provider
    assert client.put("/api/v1/ai/consent", json={"granted": True}).status_code == 200
    course_id = _course(client)
    document_id = _upload(client, course_id).json()["id"]
    deck = client.post("/api/v1/flashcard-decks", json={"title": "Photosynthèse", "course_id": course_id})

    response = client.post(
        f"/api/v1/flashcard-decks/{deck.json()['id']}/generate",
        json={"document_id": document_id},
    )

    assert response.status_code == 201, response.text
    assert len(response.json()["cards"]) == 3
    # Le texte du PDF a bien été envoyé à l'IA.
    assert "chloroplastes" in provider.prompts[0]


def test_scanned_pdf_without_text_cannot_feed_flashcards(client):
    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider(json.dumps(CARDS))
    client.put("/api/v1/ai/consent", json={"granted": True})
    course_id = _course(client)
    scanned = make_pdf("")
    document = _upload(client, course_id, data=scanned, name="scan.pdf").json()
    assert document["text_chunks"] == 0
    deck = client.post("/api/v1/flashcard-decks", json={"title": "Scan"}).json()

    response = client.post(
        f"/api/v1/flashcard-decks/{deck['id']}/generate", json={"document_id": document["id"]}
    )
    assert response.status_code == 422
