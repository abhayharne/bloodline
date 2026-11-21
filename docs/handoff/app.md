# App Handoff
**From:** agy (app agent)  **To:** next agent / human  **Time:** 2026-11-22 03:25 IST
**Branch:** main

## Done this iteration
- Task B1 Architecture:
  - Implemented abstract `ApiClient` with `HttpApiClient` and `MockApiClient`.
  - Added factory selection supporting `--dart-define=USE_MOCK` and `--dart-define=API_BASE`.
  - Added `lib/core/features.dart` which loads feature flags from `GET /config`.
  - Added `lib/core/slots.dart` with `SlotRegistry` (`homeCards`, `profileSections`, `roomHeaderBadges`), verified empty in core build.
  - Verified JSON models ignore unknown server fields safely.
  - Added unit and widget tests covering `ApiClient`, `Features.load`, and `SlotRegistry` (24/24 tests green).
  - Gate `scripts/gate-app.sh` passed cleanly.
  - Recorded decision D-APP-2 in `docs/decisions-app.md`.

## State of the code
- Gate: `scripts/gate-app.sh` PASS (flutter analyze clean, 24/24 tests green).
- Clean separation between core and feature extensions via slots.
- App is fully runnable against mock or real backend.

## Next action
- Task B2 Auth: phone entry, mock OTP screen (shows "demo mode, code 123456" when demo), signup form (role, name, age, weight, height, sex, donated before, optional last donation date, consent checkbox for donors), location permission request with a typed-area fallback. Connects Nexconn via nexconn_service.dart using nexconn_token and AreaCode.sg.

## Blockers / Human notes
- None. Real build verification (`flutter build apk`) needed on physical device/SDK when convenient.
