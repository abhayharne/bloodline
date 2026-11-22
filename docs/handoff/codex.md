# Codex handoff

Work is on `main` in `[codex]` commits. Changes are in Flutter and the
verification scripts.

## Reproduced and fixed

- `real HTTP accepts the component sent by the broadcast form` reproduced HTTP 400
  for `Whole blood`. The client sends `whole_blood` and other snake_case values.
  The broadcast form uses the four canonical urgency values and refreshes the feed.
- `real HTTP profile and request lifecycle` reproduced a wrapped JSON donation
  error. The client now exposes `role not allowed` with status 403. Whole-number
  signup and profile fields and all seven urgency spellings already worked against Go.
- `ProfileScreen inside bottom-nav shell saves profile and stays on screen without going blank`
  and `BloodLineApp resolves unknown root routes to the login gate` cover the
  existing route fix and fallback. Profile save now calls PUT /me, surfaces
  its error and allows retry.
- `Live OTP registration finishes on HomeScreen with a clean back stack` covers
  the shipped 404 new-user response, failed signup and retry. Existing-user
  verification accepts the shipped response without `is_new`. Saving an API
  session no longer waits for the native chat connection.
- `RequesterScreen broadcasts and immediately updates My Active Requests with refetched requests`
  verifies an error, retry and display of the refetched row.
- `Requester never sees donation or accept actions on their own request` and
  `Only a joined donor sees the donation action in a request room` cover role
  and membership. Live role switching is disabled because roles are assigned
  by the server.

## Verification and limits

- Both gates passed. The app gate ran 107 tests. The API gate ran race
  tests and both random-port smoke variants.

- The Dart e2e uses the real Go server with a temporary database, a random
  loopback port and fake Nexconn. Widget tests use headless HTTP fixtures for
  the UI. Tests include numeric parsing and HTTP diagnostics redaction.
- PUT /me persists coordinates, weight, height, last donation date and
  apheresis preference. Fields outside that contract retain their existing
  local storage behavior.
- Overpass queries for 21.00,78.85,21.30,79.25 timed out on Kumi and
  private.coffee. overpass-api.de timed out or returned 502. The Swiss
  mirror returned zero results. The original 12 entries remain and the
  picker says “Sample hospitals.”

## Verified on the Motorola Edge 50 Fusion

- Installed the current debug APK over USB. The old API on port 18080 served
  health but returned 404 for OTP and config. Used the current Go API with
  a fresh database and live Nexconn for the final run.
- Registration reached Home. Saving weight kept Edit Profile visible and
  showed “Profile saved.” A fresh sign-in showed 79.0 and the API returned 79.
- Broadcast matched one donor. The requester saw the open row and owner
  controls. The donor saw the accept action before joining, then recorded
  one donation and received the Donated badge.
- The donor sent “BloodLine phone check BL7261.” After switching accounts
  on the same phone, the requester read it in the same Nexconn room.
- The requester fulfilled the request. The phone displayed the read-only
  banner and the API returned fulfilled for request r2627d75159e83110.
