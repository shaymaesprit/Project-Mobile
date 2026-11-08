# Gestion Événements & Notifications

## Ce qui a été ajouté

**Backend (FastAPI)**

| Route | Rôle |
|---|---|
| `GET/POST/PUT/DELETE /events` | CRUD (statut, rappels, coordonnées du lieu) |
| `GET /events/conflicts` | Simulation d'un créneau : renvoie les conflits sans rien enregistrer |
| `POST/PUT /events?force=true` | Enregistre malgré un conflit (sinon HTTP 409 + liste `conflicts`) |
| `GET /calendar?from=&to=` | Calendrier unifié : événements + occurrences de cours + échéances de tâches (62 jours max) |
| `POST /ai/events/parse` | Phrase → brouillon d'événement (IA, consentement requis, rien n'est enregistré) |
| `GET /places/autocomplete`, `GET /places/details` | Recherche de lieux (OpenStreetMap par défaut, sans clé ; Geoapify ou Google en option) |
| `GET /notifications` (+ `unread_only`, `type`), `GET /notifications/unread-count`, `PUT /notifications/read-all`, `DELETE /notifications/{id}` | Centre de notifications |

**Métier avancé (code écrit dans le projet)**

1. **Moteur de rappels** (`services/reminder_service.py`) : file `event_reminders`, boucle asynchrone lancée avec l'API (toutes les 30 s), envoi **une seule fois** par rappel même avec plusieurs workers (réservation par `UPDATE … WHERE sent_at IS NULL`), message adapté au type (examen, échéance…), fuseau de l'utilisateur.
2. **Détection de conflits** (`services/event_conflicts.py`) : chevauchement avec les autres événements **et** avec les cours hebdomadaires (en heure locale de l'étudiant) ; les échéances et événements annulés sont ignorés.
3. **Calendrier unifié** (`services/calendar_service.py`) : fusion de trois sources, expansion des cours récurrents sur la période demandée.

**API externes**

* **FCM** (déjà dans le projet : `device_service.py`, `firebase_service.py`) : le moteur de rappels s'appuie dessus pour la livraison push.
* **OpenStreetMap (Photon)** : autocomplétion du lieu et coordonnées, sans clé ; carte affichée avec `flutter_map`. Geoapify et Google Places sont disponibles en option.
* **LLM** (Groq / Gemini / OpenAI-compatible via `LLM_*`) : création d'événement en langage naturel.

**Mobile (Flutter, dossier `lib/features/events/`)**

Agenda (mois / semaine / jour), formulaire en **page entière** (création/modification, lieu avec suggestions, rappels, avertissement de conflit), détail d'un événement, ajout par phrase (IA), centre de notifications. Accès par les icônes Agenda et cloche de la barre du haut.

## Mise en route

```bash
cd backend
alembic upgrade head          # applique 0010_event_reminders
```

Variables `backend/.env` (tout est gratuit, sans carte bancaire) :

```
# Lieux : OpenStreetMap via Photon, aucune clé nécessaire
PLACES_PROVIDER=photon

# IA : Groq (gratuit) — LLM_PROVIDER doit valoir "openai" pour tout service compatible OpenAI
LLM_PROVIDER=openai
LLM_API_KEY=gsk_...
LLM_MODEL=llama-3.3-70b-versatile
LLM_BASE_URL=https://api.groq.com/openai/v1

REMINDER_SCHEDULER_ENABLED=true
REMINDER_POLL_SECONDS=30
```

Alternatives : `PLACES_PROVIDER=geoapify` + `GEOAPIFY_API_KEY` (clé gratuite), ou `google` + `GOOGLE_MAPS_API_KEY` (carte bancaire). Pour l'IA avec Gemini : clé Google AI Studio, `LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta`, `LLM_MODEL=gemini-2.0-flash`.

Côté mobile, lance `flutter pub get` (nouvelles dépendances `flutter_map` et `latlong2` pour la carte OpenStreetMap du détail d'un événement).

## Démo rapide

1. Crée un événement « Examen » dans ~7 minutes avec le rappel **5 min** (ou « À l'heure »).
2. Attends moins d'une minute après l'heure du rappel : notification push + entrée dans le centre de notifications.
3. Crée un second événement qui chevauche le premier : le formulaire affiche l'avertissement de conflit.
