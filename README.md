# StudyMate 📚

Application mobile de vie étudiante : cours et emploi du temps, tâches et notes, calendrier et notifications, flashcards et quiz générés par l'IA, PDF de cours, tableau de bord de progression — avec un **mode hors ligne complet** (SQLite) et une synchronisation automatique.

| | |
|---|---|
| **Mobile** | Flutter 3 (Material 3, thème clair/sombre), `sqflite`, `dio`, Firebase Auth/Messaging |
| **Backend** | FastAPI + SQLAlchemy + Alembic, PostgreSQL 16 (pgvector) avec sécurité par ligne |
| **IA** | Groq (modèle `openai/gpt-oss-120b`, API compatible OpenAI), avec repli par règles |
| **Tests** | 140 tests backend (pytest) · 32 tests Flutter |

---

## 🧩 Les 4 modules

### 1. Authentification et profil
- Inscription / connexion e-mail et **Google**, vérification d'e-mail, mot de passe oublié, changement de mot de passe (Firebase Auth).
- Le backend vérifie le jeton Firebase à chaque requête ; PostgreSQL isole les données de chaque étudiant (**row-level security** sur `app.firebase_uid`).
- Profil : photo (galerie ou appareil photo, envoyée sur Cloudinary et affichée en haut de l'accueil), niveau, filière, objectifs, style d'apprentissage, objectif quotidien.

### 2. Cours et emploi du temps
- CRUD des cours avec **détection des chevauchements** d'horaires (refus 409).
- Emploi du temps de la semaine, **agenda hebdomadaire** (cours + événements + jours fériés).
- **Partage de l'emploi du temps** par lien sécurisé (jeton, expiration) et **QR code**.
- **PDF de cours** : envoi (20 Mo max, vérification du format, doublons refusés), lecture dans l'app avec zoom, **cache local pour la lecture hors ligne**, extraction du texte page par page pour l'IA.

### 3. Tâches, notes et révisions
- Tâches avec priorité et échéance ; **planificateur intelligent** : calcule les créneaux libres entre les cours/événements, classe les tâches (priorité × urgence), estime leur durée et propose un planning.
- **Découpage d'une tâche en étapes** par l'IA.
- Notes cliquables : lecture complète, modification sur place, copie, **complément Wikipédia**.
- **Flashcards générées par l'IA** à partir d'une note, d'un texte ou d'un PDF de cours ; **répétition espacée** (facteur de facilité, prochaine révision).
- **Quiz** (QCM de 10 questions tirées des flashcards) : chaque réponse met à jour la répétition espacée, le score est enregistré comme évaluation.
- **Tableau de bord** : temps passé dans l'app (7 jours, série de jours), scores des quiz, maîtrise des flashcards, parcours par cours, moyenne des notes.

### 4. Calendrier et notifications
- Événements (révision, examen, rendu…) avec **détection de conflits**, rappels, lieu sur carte (OpenStreetMap) et **lieux à proximité** (Geoapify).
- Centre de notifications, **notifications push** (Firebase Cloud Messaging).

---

## 💾 SQLite (sqflite) — mode hors ligne

| Base / table | Fichier | Rôle |
|---|---|---|
| `courses`, `tasks`, `notes`, `flashcard_decks`, `flashcards`, `evaluations` | [`local_database.dart`](mobile/studymate_app/lib/data/local/local_database.dart) | Cache local : l'app s'ouvre et s'utilise sans réseau |
| `events`, `calendar_items`, `notifications` | [`events_local_db.dart`](mobile/studymate_app/lib/data/local/events_local_db.dart) | Calendrier et notifications hors ligne |
| `outbox` | [`offline_outbox.dart`](mobile/studymate_app/lib/data/sync/offline_outbox.dart) | **File d'attente** des créations / modifications / suppressions faites hors ligne |
| `usage`, `quiz_results` | [`usage_tracker.dart`](mobile/studymate_app/lib/data/local/usage_tracker.dart) | Temps passé dans l'app et historique des quiz |

**Synchronisation** ([`sync_service.dart`](mobile/studymate_app/lib/data/sync/sync_service.dart)) :
- ordre d'enregistrement respecté (FIFO) ;
- fusion des opérations : *créer puis modifier* = une seule création, *créer puis supprimer* = rien à envoyer ;
- les identifiants `local-…` sont remplacés par ceux du serveur, y compris dans les éléments qui les référencent ;
- déclenchée au retour du réseau, au retour de l'app au premier plan, et en réessai automatique (15 s → 5 min) ;
- erreur réseau / 5xx → on garde l'opération ; refus du serveur (409, 422…) → annulée sur le téléphone et signalée ; 404 sur modification/suppression → ignorée.

> Démo : passer en mode avion, ajouter/cocher une tâche, supprimer une note → badge ☁️ dans la barre du haut ; réactiver le réseau → tout part automatiquement.

---

## 🌐 API externes consommées

| Service | Utilisation |
|---|---|
| **Groq** (LLM) | Flashcards, analyse d'apprentissage, chat, découpage de tâches |
| **Firebase** | Authentification (e-mail, Google), notifications push |
| **Cloudinary** | Hébergement des photos de profil |
| **Geoapify** | Recherche de lieux à proximité d'un événement |
| **OpenStreetMap** | Tuiles de carte (`flutter_map`) |
| **Nager.Date** | Jours fériés (Tunisie par défaut, `HOLIDAYS_COUNTRY`) |
| **QR Server** | QR code du lien de partage de l'emploi du temps |
| **Wikipédia (REST)** | Résumé encyclopédique pour compléter une note |

---

## 🚀 Installation

### Prérequis
Python 3.11+, Flutter 3.x, Docker (pour PostgreSQL), un projet Firebase.

### 1. Base de données
```bash
docker compose up -d          # PostgreSQL 16 + pgvector sur le port 5433
```

### 2. Backend
```bash
cd backend
python -m venv .venv
.venv\Scripts\activate         # Windows  (macOS/Linux : source .venv/bin/activate)
pip install -e ".[dev]"
cp .env.example .env           # puis remplir les valeurs (voir ci-dessous)
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
- Santé : `http://localhost:8000/api/v1/health` → `{"status":"ok","database":"connected"}`
- Documentation interactive : `http://localhost:8000/docs`

Variables principales du `.env` : `DATABASE_URL`, `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` (compte de service Firebase), `LLM_API_KEY` / `LLM_MODEL` / `LLM_BASE_URL`, `PLACES_PROVIDER=geoapify` + `GEOAPIFY_API_KEY`, `HOLIDAYS_COUNTRY`.

### 3. Application mobile
```bash
cd mobile/studymate_app
flutter pub get
cp dart_defines.example.json dart_defines.local.json   # puis remplir les valeurs
flutter run --dart-define-from-file=dart_defines.local.json
```
- Sur un **téléphone réel**, `STUDYMATE_API_URL` doit contenir l'**adresse IP du PC** sur le même Wi-Fi (ex. `http://192.168.1.20:8000/api/v1`) ; sur l'émulateur Android : `http://10.0.2.2:8000/api/v1`.
- Raccourcis : `run_phone.bat` (Windows) ou la configuration de lancement VS Code « StudyMate (phone) ».
- Connexion Google : ajouter les empreintes SHA-1 et SHA-256 de la clé de debug dans la console Firebase.

> 🔒 `.env`, `dart_defines.local.json`, `google-services.json` et les comptes de service sont dans `.gitignore` : **ne jamais les committer**.

---

## 🏗️ Architecture

```
mobile/studymate_app/lib/
├── core/            # thème (palette, dégradés), configuration
├── data/
│   ├── local/       # SQLite : cache, calendrier, temps d'utilisation
│   ├── sync/        # file d'attente hors ligne + synchronisation
│   ├── models/      # modèles (fromJson / toJson)
│   └── services/    # client HTTP de l'API (dio)
├── state/           # StudyController (ChangeNotifier)
└── features/        # auth, home, courses, events, study, insights, profile…

backend/app/
├── api/routes/      # endpoints FastAPI
├── services/        # logique métier (planning, conflits, PDF, IA, partage…)
├── repositories/    # accès aux données
├── models/          # modèles SQLAlchemy
├── schemas/         # validation Pydantic
└── ml/              # profils d'apprentissage et recommandations
backend/alembic/     # migrations (0001 → 0014)
```

### Endpoints principaux (`/api/v1`)
| Domaine | Routes |
|---|---|
| Compte | `GET/PUT /users/me`, `GET/PUT /profile` |
| Cours | `/courses`, `/timetable`, `/schedule/week-agenda`, `/timetable/shares`, `/timetable/shared/{token}` |
| PDF | `GET/POST /courses/{id}/documents`, `GET /documents/{id}/file`, `PATCH/DELETE /documents/{id}` |
| Tâches et notes | `/tasks`, `GET /tasks/plan`, `/notes`, `GET /knowledge/wikipedia` |
| Révisions | `/flashcard-decks`, `POST /flashcard-decks/{id}/generate`, `/flashcards`, `/evaluations` |
| Calendrier | `/events`, `/calendar`, `/notifications`, `/places` |
| IA | `/ai/consent`, `/ai/chat`, `/ai/tasks/{id}/breakdown`, `/ml/…` |

---

## 🧪 Tests
```bash
cd backend && pytest -q                    # 140 tests
cd mobile/studymate_app && flutter test    # 32 tests
```
Les tests backend tournent sur SQLite en mémoire (aucun service externe appelé) ; les tests Flutter couvrent notamment la file d'attente hors ligne, le tableau de bord, les PDF de cours et les notes.

---

## 🆘 Problèmes fréquents
| Symptôme | Solution |
|---|---|
| « Firebase n'est pas configuré » au lancement | Lancer avec `--dart-define-from-file=dart_defines.local.json` |
| L'app ne joint pas l'API sur le téléphone | PC et téléphone sur le même Wi-Fi, IP du PC dans `STUDYMATE_API_URL`, pare-feu Windows ouvert sur le port 8000 |
| Connexion Google refusée | Empreintes SHA-1/SHA-256 manquantes dans Firebase |
| Erreur 500 après une mise à jour | `alembic upgrade head` dans `backend/` |
| Flashcards IA indisponibles | Vérifier `LLM_API_KEY` ; sans clé, l'app utilise la génération par règles |

---

Dernière mise à jour : 11 novembre 2026
