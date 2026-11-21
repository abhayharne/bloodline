# App Handoff
**From:** agy (app agent)  **To:** next agent / human  **Time:** 2026-11-22 04:40 IST
**Branch:** main

## Done this iteration
- Task B11 Accessibility (large-font toggle via textScaler):
  - Implemented `SettingsProvider` in `lib/core/providers/settings_provider.dart` with `TextScaler.linear(1.3)` toggle, persistent in `SharedPreferences`.
  - Wired `textScaler` into `MaterialApp` builder in `lib/main.dart` so all UI scales dynamically when toggled.
  - Implemented `SettingsScreen` in `lib/features/settings/settings_screen.dart` with 'Large Text (1.3x)' switch, live legibility preview card, and voice-to-text notice.
  - Added entry points in `HomeScreen` AppBar actions and `ProfileScreen` settings button.
  - Added unit, widget, and integration tests in `test/settings_test.dart` (75/75 tests passing, gate clean).
  - Assessed voice-to-text: requires platform-specific manifest permissions (`RECORD_AUDIO`, `Info.plist`) and physical microphone input. Per task instruction and rule 3, marked B11 as `[!]` BLOCKED for the voice-to-text platform requirement.
  - Recorded decision D-APP-8 in `docs/decisions-app.md`.

## State of the code
- Gate: `scripts/gate-app.sh` PASS (flutter analyze clean 0 errors/warnings, 75/75 tests green).
- App-wide font scaling working seamlessly with Flutter 3 modern `TextScaler`.
- Settings screen accessible from dashboard and profile.

## Next action
- Task B12 Final pass: widget tests green, README section for running the app against the real API (flutter run --dart-define=API_BASE=... --dart-define=NEXCONN_APP_KEY=...), tidy handoff, list everything that needs a real device in docs/handoff/app.md.

## Blockers / Human notes
- Physical device verification needed in morning: real Android/iOS build, physical microphone testing if voice-to-text is pursued, and real GPS sensor checks.
