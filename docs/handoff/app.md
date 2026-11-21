# App Handoff
**From:** antigravity  **To:** opencode / user  **Time:** 2026-11-22 02:15 IST
**Branch:** main  **Last commit:** 31d987f

## Current task
T2.1-T2.6, T2.8 are DONE. Extensible app core and all screens built against docs/API.md.

## Done this session
- Built `lib/core`:
  - `api_client.dart`: Full HTTP client matching docs/API.md with automatic in-memory mock fallback.
  - `slot_registry.dart`: `SlotRegistry` with `homeCards`, `profileSections`, `roomHeaderBadges` (empty in core build).
  - `nexconn_service.dart`: Wraps Nexconn Chat SDK lifecycle & connection state.
  - `location_service.dart`: GPS detection via `geolocator` with typed-area fallback.
  - Models (`User`, `AuthResponse`, `BloodRequest`, `BloodStockItem`, `AppConfig`): `fromJson` safely ignores unknown fields.
  - Providers: `AuthProvider`, `RequestsProvider`, `BankStockProvider`, `ConfigProvider`.
- Built `lib/features/<name>/` with `register.dart` per feature:
  - `auth`: Phone + 6-digit mock OTP, one-tap demo profiles, demographic form (age, weight, height, sex, previous donation, GPS + typed area fallback), renders `profileSections` slot.
  - `requester`: New request broadcast form (group, units, hospital, urgency) and "My Requests" list.
  - `donor`: Emergency feed filtered by group with "I Can Help" accept button calling POST /requests/{id}/accept.
  - `bank`: 8 blood group inventory stock editor (GET/PUT /banks/me/stock) + open requests list.
  - `chat`: ChannelPage inbox + ChatPage with `RequestSummaryHeader`, fulfill button for requester, and closed-room banner when fulfilled. Renders `roomHeaderBadges` slot.
  - `home`: Role-aware dashboard, bottom navigation, renders `homeCards` slot.
  - `debug`: Token connector, mock mode switcher, and base URL config.
- Added comprehensive unit & widget test suite in `app/test/` (19 tests, 100% passing).
- Updated `docs/PLAN.md` (ticked T2.1-T2.6, T2.8) and logged D11-D13 in `docs/DECISIONS.md`.

## State of the code
- Tests: `cd app && flutter test` passes 19/19 tests (100% passing).
- App is structured for extension without modifying core screens.

## Next action
- T2.7: Add location pin message in chat (send current location / hospital pin).
- T2.9: In-app banner / polling when matching request arrives.
- P1 backend integration (opencode finishing T1.4 - T1.9).

## Do NOT touch
- `api/` (owned by opencode).
