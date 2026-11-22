# App Handoff
**From:** antigravity (app agent)  **To:** next agent / human  **Time:** 2026-11-22 13:50 IST
**Branch:** main

## Done this iteration
- Real error surfacing on login & mock banner:
  - Eliminated silent mock fallback when `USE_MOCK` is false; connection/login errors are surfaced in a SnackBar and the user remains on `LoginScreen`.
  - Added visible "Demo mode (offline data)" banner on `LoginScreen` and `HomeScreen` when mock mode is active.
- Defensive `created_at` timestamp parsing:
  - Added `parseCreatedAt` to `BloodRequest` and `InAppNotification`; `null` or empty strings safely return `null` without throwing.
  - Invalid date strings surface error in a SnackBar via `rootScaffoldMessengerKey`.
- Request broadcast & immediate active requests refresh:
  - `RequestsProvider.createRequest` and `RequesterScreen` immediately refetch `GET /requests` so the newly broadcasted request appears in "My Active Requests".
- Urgency options:
  - Configured segmented urgency selector to send `low|medium|high|critical`.
- Logout with confirm dialog:
  - Added logout button to `HomeScreen` and `ProfileScreen` with confirmation dialog.
  - Clears stored auth token, user profile, SharedPreferences session, disconnects Nexconn chat SDK, and navigates to `LoginScreen`.
- Widget Tests & Gate Verification:
  - Added comprehensive widget tests for mock banner, real error snackbars on failure, defensive date parsing, broadcast refetching, urgency values, and logout confirmation.
  - Verification gate `scripts/gate-app.sh` is 100% GREEN (85/85 tests passing, 0 analyzer errors/warnings).

## State of the code
- Gate: `scripts/gate-app.sh` PASS (85/85 tests passing, clean analyzer).
- Working tree clean, all 5 requested items verified.

## Next action
- Run live e2e integration against Go backend with real credentials (`scripts/gate-api.sh` + `gate-app.sh`).
