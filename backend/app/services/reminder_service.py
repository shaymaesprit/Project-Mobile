"""File de rappels d'événements et planificateur.

* ``sync_event_reminders`` aligne les lignes ``event_reminders`` d'un événement
  sur ses ``reminder_offsets`` (appelé à chaque création / modification).
* ``run_once`` envoie les rappels échus : chaque rappel est « réclamé » par un
  UPDATE conditionnel (``sent_at IS NULL``) avant l'envoi, ce qui garantit
  un seul envoi même avec plusieurs workers.
* ``reminder_loop`` est la boucle asynchrone lancée au démarrage de l'API.
"""

import asyncio
import logging
from collections.abc import Callable
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text, update
from sqlalchemy.orm import Session

from app.models.extended import EventReminder, StudyEvent
from app.services.device_service import NotificationDispatcher
from app.services.event_conflicts import as_utc, user_timezone

logger = logging.getLogger("studymate.reminders")

BATCH_SIZE = 100
# Un rappel manqué de plus de 12 h (serveur arrêté) n'a plus de sens.
MAX_LATENESS = timedelta(hours=12)


def sync_event_reminders(
    db: Session, event: StudyEvent, now: datetime | None = None
) -> None:
    """Aligne les rappels d'un événement sur ses décalages. Ne valide pas la transaction.

    Une ligne dont l'heure n'a pas changé est conservée telle quelle (envoyée ou
    non) : modifier le titre d'un événement ne renvoie donc jamais un rappel déjà
    parti, alors que déplacer l'événement recrée des rappels à la nouvelle heure.
    """
    now = now or datetime.now(timezone.utc)
    desired: dict[int, datetime] = {}
    if event.status == "planned":
        starts = as_utc(event.starts_at)
        for offset in event.reminder_offsets or []:
            desired[int(offset)] = starts - timedelta(minutes=int(offset))

    existing = list(
        db.scalars(select(EventReminder).where(EventReminder.event_id == event.id))
    )
    for row in existing:
        wanted = desired.get(row.offset_minutes)
        if wanted is not None and as_utc(row.remind_at) == wanted:
            desired.pop(row.offset_minutes)
        else:
            db.delete(row)
    db.flush()
    for offset, remind_at in desired.items():
        if remind_at > now:  # inutile de programmer un rappel déjà passé
            db.add(
                EventReminder(
                    owner_uid=event.owner_uid,
                    event_id=event.id,
                    offset_minutes=offset,
                    remind_at=remind_at,
                )
            )
    db.flush()


def describe_offset(minutes: int) -> str:
    if minutes <= 0:
        return "maintenant"
    if minutes % 1440 == 0:
        days = minutes // 1440
        return "demain" if days == 1 else f"dans {days} jours"
    if minutes % 60 == 0:
        return f"dans {minutes // 60} h"
    if minutes > 60:
        return f"dans {minutes // 60} h {minutes % 60:02d}"
    return f"dans {minutes} min"


_TYPE_LABEL = {
    "exam": "Examen",
    "deadline": "Échéance",
    "class": "Cours",
    "study": "Révision",
    "personal": "Personnel",
    "other": "Événement",
}


def build_message(event: StudyEvent, offset_minutes: int, tz) -> tuple[str, str, str]:
    label = _TYPE_LABEL.get(event.event_type, "Événement")
    local = as_utc(event.starts_at).astimezone(tz)
    when = describe_offset(offset_minutes)
    title = f"{label} : {event.title}"
    body = f"{label} {when}, à {local:%H:%M}"
    if event.location:
        body += f" — {event.location}"
    kind = {"exam": "exam", "deadline": "deadline"}.get(event.event_type, "reminder")
    return kind, title[:200], body


def run_once(
    session_factory: Callable[[], Session], now: datetime | None = None
) -> int:
    """Envoie les rappels échus ; renvoie le nombre de notifications créées."""
    now = now or datetime.now(timezone.utc)
    with session_factory() as db:
        # Lecture de la file sans utilisateur (politique « scheduler_read_due »).
        if db.get_bind().dialect.name == "postgresql":
            db.execute(text("SELECT set_config('app.scheduler', 'on', true)"))
        due = [
            (row.id, row.owner_uid, row.event_id, row.offset_minutes)
            for row in db.scalars(
                select(EventReminder)
                .where(
                    EventReminder.sent_at.is_(None),
                    EventReminder.remind_at <= now,
                    EventReminder.remind_at > now - MAX_LATENESS,
                )
                .order_by(EventReminder.remind_at)
                .limit(BATCH_SIZE)
            )
        ]
        db.rollback()

    sent = 0
    for reminder_id, owner_uid, event_id, offset in due:
        try:
            if _deliver(session_factory, reminder_id, owner_uid, event_id, offset, now):
                sent += 1
        except Exception as error:  # noqa: BLE001 - un échec n'arrête pas la boucle
            logger.warning("Reminder %s failed (%s)", reminder_id, type(error).__name__)
    return sent


def _deliver(session_factory, reminder_id, owner_uid, event_id, offset, now) -> bool:
    with session_factory() as db:
        db.info["firebase_uid"] = owner_uid
        claimed = db.execute(
            update(EventReminder)
            .where(EventReminder.id == reminder_id, EventReminder.sent_at.is_(None))
            .values(sent_at=now)
        ).rowcount
        db.commit()
        if claimed != 1:
            return False  # un autre worker l'a déjà pris
        event = db.scalar(
            select(StudyEvent).where(
                StudyEvent.id == event_id, StudyEvent.owner_uid == owner_uid
            )
        )
        if event is None or event.status != "planned":
            return False
        kind, title, body = build_message(event, offset, user_timezone(db, owner_uid))
        NotificationDispatcher(db).dispatch(
            owner_uid,
            kind,
            title,
            body,
            {
                "kind": "event_reminder",
                "event_id": str(event.id),
                "event_type": event.event_type,
                "starts_at": as_utc(event.starts_at).isoformat(),
                "offset_minutes": offset,
            },
        )
        return True


async def reminder_loop(
    session_factory: Callable[[], Session], poll_seconds: float
) -> None:
    logger.info("Reminder scheduler started (every %.0fs).", poll_seconds)
    while True:
        try:
            count = await asyncio.to_thread(run_once, session_factory)
            if count:
                logger.info("Reminder scheduler sent %d notification(s).", count)
        except asyncio.CancelledError:
            raise
        except Exception as error:  # noqa: BLE001
            logger.warning("Reminder scheduler error (%s)", type(error).__name__)
        await asyncio.sleep(poll_seconds)
