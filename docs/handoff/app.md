# App Handoff
**From:** agy (app agent)  **To:** next agent / human  **Time:** 2026-11-22 03:45 IST
**Branch:** feat/app

## Done this iteration
- Task B2 Auth:
  - In `LoginScreen`, implemented phone entry and `sendOtp` triggering mock OTP UI.
  - Mock OTP screen prominently shows "demo mode, code 123456" when demo mode is active.
  - In `_onVerifyOtp`, routes existing user directly to dashboard and new users to profile registration.
  - In `ProfileScreen`, completed signup form with role, name, age, weight, height, sex, donated before switch, optional last donation date, and mandatory donor consent checkbox.
  - Added location permission request (`LocationService.getDeviceLocation()`) with typed-area text field and preset choice chips.
  - Connects to Nexconn Chat SDK via `NexconnService` with `AreaCode.sg` and `nexconn_token` upon successful authentication/signup.
  - Refactored `HomeScreen` tab loading to mount `ChannelInboxScreen` lazily and guarded `ChannelInboxScreen` against uninitialized native SDK in tests.
  - Added unit & widget tests in `test/core_screens_test.dart` (27/27 tests passing).
  - Gate `scripts/gate-app.sh` passes cleanly (analyze clean, 27/27 tests green).
  - Recorded decision D-APP-3 in `docs/decisions-app.md`.

## State of the code
- Gate: `scripts/gate-app.sh` PASS (flutter analyze clean, 27/27 tests green).
- Full end-to-end auth flow works smoothly in mock/test mode.
- Nexconn connection properly isolated in `NexconnService`.

## Next action
- Task B7 Fulfill and donated: requester "Mark fulfilled" button, closed-room read-only banner, donor "I donated" button (POST /requests/{id}/donated).

## Blockers / Human notes
- None. Physical device verification needed in morning for real APK builds.
