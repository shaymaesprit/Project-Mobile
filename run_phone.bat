@echo off
REM Lance StudyMate sur le telephone avec la config Firebase/API.
cd /d "%~dp0mobile\studymate_app"
flutter run --dart-define-from-file=dart_defines.local.json
pause
