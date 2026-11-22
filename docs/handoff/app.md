# App Handoff
**From:** antigravity (app agent)  **To:** next agent / human  **Time:** 2026-11-22 14:30 IST
**Branch:** feat/app

## Done this iteration
1. **Error surfacing & OTP UX:**
   - Every failed API call logs details and surfaces the server's error message via SnackBar.
   - Displayed "demo mode, code 123456" on OTP verification screen.
   - Added phone normalization (`normalizePhone`) prepending `+91` to 10-digit phone numbers before sending.
2. **Broadcast & Urgency contract fix:**
   - Diagnosed root cause of requests not appearing: backend validates urgency against `critical|urgent|planned` (rejecting `low|medium|high` with 400).
   - Reconciled UI to send `critical|urgent|planned` per `docs/API.md`. Added request/response debug logging.
   - Immediately refetches `GET /requests` on broadcast; displays confirmation dialog with match counts and button to open chat room.
3. **LocationController:**
   - Created `LocationController` supporting sources `gps|preset|typed`.
   - "Use Device GPS" button is always enabled; choosing GPS clears preset selection; last choice wins.
   - Added `ACCESS_FINE_LOCATION` to `AndroidManifest.xml`.
   - High-accuracy GPS with 15s timeout, falling back to `getLastKnownPosition`.
   - Explicit handling and messages for services off (`openLocationSettings`), denied (retry), denied forever (`openAppSettings`), and timeout.
   - Shows "Using GPS (±N m)" with coordinates; shows "Location not set" when unset.
4. **Logout & Debug icon:**
   - Added confirm logout dialog in Profile and Settings screens that clears token/user, disconnects Nexconn, resets `RequestsProvider` and `NotificationsProvider`, and returns to login.
   - Hid debug icon on HomeScreen unless running in demo/mock mode.
5. **Hospital Picker:**
   - Added `getHospitals` in `ApiClient`, `HttpApiClient`, and `MockApiClient` (sorted nearest first by user location).
   - Searchable/selectable picker with "Other (type a name)" option; selecting one sets request coordinates.
6. **Component & Donor profile:**
   - Added Component dropdown (`Whole blood`, `Red cells`, `Platelets`, `Plasma`, `Other`) and optional notes field.
   - Displayed component chip in `RequestSummaryHeader` chat room header.
   - Added "I can donate platelets/plasma" switch to donor profile.
7. **Verification & Tests:**
   - Added comprehensive widget and unit tests in `core_screens_test.dart`.
   - `scripts/gate-app.sh` 100% GREEN (92/92 tests passing, 0 analyzer errors/warnings).

## State of the code
- Gate: `scripts/gate-app.sh` PASS (92/92 tests passing, clean analyzer).
- Working tree clean, all 6 requested items verified.

## Next action
- Live end-to-end rehearsal with backend (`scripts/smoke.sh` and two-device chat test).
