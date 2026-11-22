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

## Phone checklist

1. Use the real API base URL with `USE_MOCK=false`. Sign up with a fresh phone,
   navigate back from Home once and confirm the registration route is gone.
2. Edit weight or height from the Profile tab. Save, confirm the tab stays
   visible, and verify the values survive signing out and signing back in.
3. Broadcast a request and verify the row and room appear. The owner should
   see “Mark fulfilled” and neither donor action.
4. Sign in with a matching donor. Accept, open the room, verify live Nexconn
   chat, and record a donation. Return as the requester and fulfill.
