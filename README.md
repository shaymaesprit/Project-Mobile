# StudyMate

StudyMate contains a Flutter mobile app and a FastAPI backend. PostgreSQL with
pgvector stores application data. Firebase Authentication provides identity;
the API verifies Firebase ID tokens and scopes records to the authenticated
Firebase UID.

## Project structure

```text
mobile/
  studymate_app/      Flutter and Android Studio project
backend/
  app/
    api/               Versioned HTTP routes and dependency wiring
    core/              Settings, errors, and logging
    database/          SQLAlchemy Base, engine, and request sessions
    models/            SQLAlchemy persistence models
    repositories/      PostgreSQL queries and persistence
    schemas/           Pydantic request/response contracts
    services/           Application and business rules
  alembic/             Database migrations
  tests/               Backend tests
docker-compose.yml    Local PostgreSQL with pgvector
```

## Windows prerequisites

- Flutter SDK with the Android SDK and an Android Studio emulator.
- Python 3.12 or another supported Python 3.11+ version.
- Git for Windows.
- Docker Desktop for the local PostgreSQL service.

## Run the mobile app

```powershell
Set-Location mobile\studymate_app
flutter pub get
flutter run
```

Open `mobile\studymate_app` in Android Studio to work on the Flutter project.
Firebase authentication and the API must be configured before the app can
show account data; it does not substitute sample records for backend data.

To connect Firebase on Android, register an Android app in Firebase Console
with application ID `com.example.studymate`, enable email/password
and Google authentication, then pass the project client configuration to
Flutter. Google Sign-In also needs the OAuth **Web application** client ID from the
same Firebase/Google Cloud project:

```powershell
flutter run `
  --dart-define="STUDYMATE_FIREBASE_API_KEY=<Firebase Web API key>" `
  --dart-define="STUDYMATE_GOOGLE_SERVER_CLIENT_ID=<OAuth Web client ID>" `
  --dart-define="STUDYMATE_FIREBASE_STORAGE_BUCKET=<Firebase Storage bucket>"
```

The StudyMate Android app ID, project ID, and sender ID provided in Firebase
Console are configured as Flutter defaults (`1:406992456210:android:f0189e87cc8c19f67a26cb`,
`studymate-8930d`, and `406992456210`). The project ID is also prefilled in
`backend\.env.example`. The Firebase Web API key and Google OAuth Web client ID
are still required launch values; find them in Firebase project settings and
Google Cloud credentials, respectively. Create a Firebase Storage bucket and
pass its exact bucket name (shown in Firebase Console) as
`STUDYMATE_FIREBASE_STORAGE_BUCKET`.

The Firebase client options and OAuth client ID identify the app; they are not
Firebase Admin credentials. Never put a Firebase service-account private key in
Flutter, source control, or a `--dart-define`.

### Firebase Console setup

1. Use Firebase project `studymate-8930d`, then add/confirm its Android app
   with package name `com.example.studymate` and app ID
   `1:406992456210:android:f0189e87cc8c19f67a26cb`.
2. In `mobile\studymate_app\android`, run
   `.\gradlew signingReport`. Add the debug SHA-1 and SHA-256 fingerprints for
   local development under the Android app settings in Firebase Console.
   Register the release signing fingerprints separately before publishing.
3. In **Authentication → Sign-in method**, enable **Email/Password** and
   **Google**. Set the support email for Google sign-in.
4. In **Project settings → General**, copy the Android app ID, project ID,
   sender ID, and Web API key into the corresponding Flutter defines above.
5. In **Google Cloud Console → APIs & Services → Credentials**, copy the OAuth
   2.0 client ID of type **Web application** for this project into
   `STUDYMATE_GOOGLE_SERVER_CLIENT_ID` (not the Android OAuth client ID).
6. For the backend, set `FIREBASE_PROJECT_ID` in `backend\.env`. For local
   development, create a Firebase Admin service-account key and store it
   outside the repository; set `GOOGLE_APPLICATION_CREDENTIALS` to its
   absolute path. Prefer Application Default Credentials or workload identity
   instead of a downloaded key in deployed environments.
7. In **Storage**, create a bucket, then publish the root `storage.rules`
   rules. They allow only an authenticated user to access that user's profile
   photo and limit uploads to 5 MB JPEG/PNG/WebP images.
8. From `mobile\studymate_app`, run `flutter pub get` and the Flutter command
   shown above. Start the backend as described below before syncing data.

Email registration, sign-in, and password reset use Firebase Authentication
directly. Google sign-in exchanges Google's ID token for a Firebase session.
The app obtains a Firebase ID token for each authenticated API request and
sends it as `Authorization: Bearer <token>`. FastAPI verifies the token with
Firebase Admin; protected routes derive the UID only from that verified token,
scope PostgreSQL queries to it, and create the local user row on first use.
The account menu lets the signed-in user update their display name/photo
(Firebase and `PUT /api/v1/users/me`) or sign out.
The profile screen reads and updates the authenticated account and learning
profile through the API. Academic level, specialty, goals, learning style,
daily study target, and study preferences are persisted in PostgreSQL.
Profile images are uploaded from Flutter to
`users/{verified Firebase UID}/profile/avatar` in Firebase Storage; the
resulting download URL is stored in the user's API profile. Storage access
rules are in `storage.rules` and must be published to the project's bucket.

## Start PostgreSQL

Start Docker Desktop first, then run this command from the repository root:

```powershell
docker compose up -d db
```

The local database uses development-only credentials from
`docker-compose.yml` and is published on port `5433` to avoid colliding with an
existing PostgreSQL installation on port `5432`. Change the development
credentials before exposing the database outside the local development
machine.

`backend\schema.sql` is the proposed complete schema for a fresh database.
The running project is currently managed by Alembic; review and convert this
reference into an Alembic migration before applying it to an existing database.
Its row-level security policies require the API to set the verified Firebase
UID transaction-locally as `app.firebase_uid` for each request.

## Configure and run the backend

From the repository root, copy the example backend settings:

```powershell
if (-not (Test-Path backend\.env)) {
  Copy-Item backend\.env.example backend\.env
}
```

Edit `backend\.env` and set `FIREBASE_PROJECT_ID`. For local Firebase Admin
authentication, download a service-account key and store it outside this
repository. Set `GOOGLE_APPLICATION_CREDENTIALS` to its absolute path in
`backend\.env`. Never commit or share the service-account key.
`DATABASE_URL` is also read from this file; do not put database credentials in
source code or paste the URL into logs or issue reports.
For Flutter Web, set `CORS_ORIGINS` to a JSON array containing the exact local
web origins you use. The development default also accepts loopback origins
with a port; set `CORS_ORIGIN_REGEX` to an empty value and configure explicit
origins when deploying. Native Android and iOS Flutter apps do not enforce
browser CORS.

Create a Python 3.12 virtual environment and install the backend:

```powershell
Set-Location backend
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -e ".[dev]"
```

Apply database migrations and start the API:

```powershell
.\.venv\Scripts\alembic.exe upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The current database is at Alembic revision `0004_sha256_fixed_width`.
`app.database.connection` creates SQLAlchemy's engine and `SessionLocal`;
`get_db` provides request-scoped sessions. Firebase-authenticated requests set
the verified UID transaction-locally for PostgreSQL row-level security.

From a second terminal, check `http://127.0.0.1:8000/api/v1/health` or
`http://127.0.0.1:8000/api/v1/health/database`. Both return HTTP 503 with a
generic message if PostgreSQL is unavailable. Interactive API documentation is
available at `http://127.0.0.1:8000/docs` and OpenAPI JSON at
`http://127.0.0.1:8000/openapi.json`. Android
emulators access the development host using `10.0.2.2`; the Flutter app uses
`http://10.0.2.2:8000/api/v1` by default.

## REST API

The versioned API exposes authenticated user and learning-profile resources,
courses, tasks, notes, flashcards, evaluations, calendar events, and
notifications. Each record lookup and mutation is scoped to the Firebase UID
from the verified ID token. `PUT /api/v1/users/me` updates application profile
fields; email and credentials remain managed by Firebase Authentication.
Deleting `/api/v1/users/me` deletes the Firebase account and the associated
database records. Notifications are listed with `limit`/`offset` pagination
and marked read through `PUT /api/v1/notifications/{id}/read`.

Courses are private to the authenticated student and support `GET`, `POST`,
`PUT`/`PATCH`, and `DELETE` at `/api/v1/courses`. Optional weekly schedule
fields are `weekday` (ISO-style, Monday `0` through Sunday `6`),
`start_time`, and `end_time` (local `HH:MM`); provide all three or none.
`GET /api/v1/courses/schedule` lists scheduled courses for the current
student. Overlapping courses on the same weekday return HTTP 409, while
adjacent time intervals are allowed. The Flutter Courses page offers course
details, create/edit/delete actions, and a weekday-filtered timetable.

## Tests

Flutter checks (from `mobile\studymate_app`):

```powershell
flutter analyze
flutter test
```

Backend tests (from `backend`):

```powershell
.\.venv\Scripts\python.exe -m pytest
```

## Git safety

Initialize the repository from the root with `git init`. Environment files,
Firebase service-account keys, Android signing files, local Python virtual
environments, and Flutter build outputs are excluded by `.gitignore`.
