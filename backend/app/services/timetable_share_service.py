"""Partage de l'emploi du temps par lien public et QR code.

* Le lien contient un jeton aléatoire (``secrets.token_urlsafe``), expire
  (7 jours par défaut) et peut être révoqué à tout moment.
* L'image du QR code est produite par l'API publique **QR Server**
  (https://goqr.me/api/) — aucune clé requise.
* La lecture publique ne révèle que les cours (titre, jour, heures, salle,
  enseignant) et le prénom affiché : ni email, ni tâches, ni notes.
"""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone
from html import escape
from urllib.parse import quote
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.exceptions import ResourceNotFoundError
from app.models.course import Course
from app.models.timetable_share import TimetableShare
from app.models.user import User

QR_API = "https://api.qrserver.com/v1/create-qr-code/?size=400x400&margin=12&data={data}"
DEFAULT_TTL = timedelta(days=7)
WEEKDAYS = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]


class SharedLinkGoneError(ResourceNotFoundError):
    status_code = 410
    code = "share_expired"


def qr_image_url(link: str) -> str:
    return QR_API.format(data=quote(link, safe=""))


class TimetableShareService:
    def __init__(self, db: Session) -> None:
        self._db = db

    # ── Propriétaire ────────────────────────────────────────────────────────

    def create(self, owner_uid: str, public_base_url: str, days: int = 7) -> TimetableShare:
        token = secrets.token_urlsafe(24)
        link = f"{public_base_url.rstrip('/')}/timetable/shared/{token}/page"
        share = TimetableShare(
            owner_uid=owner_uid,
            token=token,
            qr_url=qr_image_url(link),
            is_active=True,
            expires_at=datetime.now(timezone.utc) + timedelta(days=days),
        )
        self._db.add(share)
        self._db.commit()
        self._db.refresh(share)
        return share

    def list_active(self, owner_uid: str) -> list[TimetableShare]:
        now = datetime.now(timezone.utc)
        return [
            share
            for share in self._db.scalars(
                select(TimetableShare)
                .where(
                    TimetableShare.owner_uid == owner_uid,
                    TimetableShare.is_active.is_(True),
                )
                .order_by(TimetableShare.created_at.desc())
            )
            if _aware(share.expires_at) > now
        ]

    def revoke(self, owner_uid: str, share_id: UUID) -> None:
        share = self._db.get(TimetableShare, share_id)
        if share is None or share.owner_uid != owner_uid:
            raise ResourceNotFoundError("Timetable share not found.")
        share.is_active = False
        self._db.commit()

    # ── Lecture publique ────────────────────────────────────────────────────

    def public_schedule(self, token: str) -> dict:
        share = self._db.scalar(select(TimetableShare).where(TimetableShare.token == token))
        if share is None:
            raise ResourceNotFoundError("Shared timetable not found.")
        if not share.is_active or _aware(share.expires_at) <= datetime.now(timezone.utc):
            raise SharedLinkGoneError("This shared timetable link has expired.")
        owner_uid = share.owner_uid

        # Les cours sont protégés par RLS : on termine la transaction courante,
        # puis on ouvre la suivante dans le contexte du propriétaire du lien.
        self._db.commit()
        self._db.info["firebase_uid"] = owner_uid
        owner = self._db.get(User, owner_uid)
        courses = list(
            self._db.scalars(
                select(Course)
                .where(Course.owner_uid == owner_uid, Course.weekday.is_not(None))
                .order_by(Course.weekday, Course.start_time, Course.title)
            )
        )
        first_name = None
        if owner is not None and owner.display_name:
            first_name = owner.display_name.strip().split(" ")[0]
        return {
            "owner_name": first_name,
            "expires_at": share.expires_at,
            "courses": [
                {
                    "title": course.title,
                    "weekday": course.weekday,
                    "start_time": course.start_time,
                    "end_time": course.end_time,
                    "room": course.room,
                    "professor": course.professor,
                    "type_cours": course.type_cours.value if course.type_cours else None,
                }
                for course in courses
            ],
        }

    @staticmethod
    def render_html(schedule: dict) -> str:
        owner = escape(schedule["owner_name"] or "un·e étudiant·e")
        rows = []
        for weekday, label in enumerate(WEEKDAYS):
            day_courses = [c for c in schedule["courses"] if c["weekday"] == weekday]
            if not day_courses:
                continue
            items = "".join(
                "<li><b>{start}–{end}</b> {title}{room}{prof}</li>".format(
                    start=c["start_time"].strftime("%H:%M") if c["start_time"] else "?",
                    end=c["end_time"].strftime("%H:%M") if c["end_time"] else "?",
                    title=escape(c["title"]),
                    room=f" · salle {escape(c['room'])}" if c["room"] else "",
                    prof=f" · {escape(c['professor'])}" if c["professor"] else "",
                )
                for c in day_courses
            )
            rows.append(f"<h2>{label}</h2><ul>{items}</ul>")
        body = "".join(rows) or "<p>Aucun cours planifié.</p>"
        return (
            "<!doctype html><html lang='fr'><head><meta charset='utf-8'>"
            "<meta name='viewport' content='width=device-width,initial-scale=1'>"
            f"<title>Emploi du temps de {owner}</title><style>"
            "body{font-family:system-ui,sans-serif;margin:0;padding:24px;"
            "background:#F5F6FB;color:#14152B}"
            "header{background:linear-gradient(135deg,#5546FF,#8B5CF6,#EC4899);"
            "color:#fff;padding:22px;border-radius:22px;margin-bottom:18px}"
            "h1{margin:0;font-size:22px}h2{font-size:15px;color:#5546FF;margin:18px 0 6px}"
            "ul{list-style:none;padding:0;margin:0}li{background:#fff;border:1px solid #E4E5F1;"
            "border-radius:14px;padding:12px 14px;margin-bottom:8px}"
            "</style></head><body>"
            f"<header><h1>Emploi du temps de {owner}</h1>"
            "<div>Partagé avec StudyMate</div></header>"
            f"{body}</body></html>"
        )


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
