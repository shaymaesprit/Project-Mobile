# StudyMate (StudentLife)

A mobile-first Flutter productivity app for university students. This frontend currently runs on realistic in-memory academic sample data; the API client and repository boundary are ready to connect to a Spring Boot REST API.

## Run

```powershell
flutter pub get
flutter run
```

## Included

- Welcome, sign-in, and account creation entry flow
- Home dashboard with academic stats, today schedule, task preview, and notifications
- Courses and weekly schedule with add/edit/delete and course detail
- Tasks with status/priority filters, progress, completion, reminders, and CRUD
- Personal notes with search, course filtering, and CRUD
- Academic calendar with month/week/day modes and event creation
- Notification center and student profile
- Responsive Material 3 UI, bottom navigation, quick-create action, confirmation dialogs, and feedback
- Typed entities, mock repository, and token-aware REST client foundation

## Backend integration

Set `ApiClient.baseUrl` to the Spring Boot API origin and implement the endpoints in `lib/data/study_repository.dart`. Store access tokens via a platform secure-storage implementation before production use. Passwords are only sent to the authentication endpoint over HTTPS; they are never persisted by this Flutter client. The API must hash passwords and scope every data query to the authenticated student.
