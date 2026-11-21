# Handoff
**From:** opencode (api, overnight loop, iteration 3)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** this iteration (see `git log -1`)

## Done this iteration
- Gate was PASS at entry and PASS after the change (`bash scripts/gate-api.sh`).
- A10 complete (first unchecked task; now ticked). `api/db/seed.sql` now seeds
  5 donors, 2 stocked banks, 1 requester and 1 open request `rseed1` (channel
  `reqrseed1`), all with unique phones, alphanumeric ids and full donor profiles.
- `POST /dev/reset` is registered only when `DEV=1`, via `httpapi.WithDevRoutes()`
  passed from `main` through a `devRoutes(cfg.Dev)` helper. Unauthenticated so the
  demo can reset before login. Response: `{"status":"ok","seeded":true}`.
- Reset is transactional: wipes notifications, donations, request_members,
  requests, bank_stock and users, then applies the embedded seed. Repeatable.
- `Store.Reset` plus a `Reseed` alias; service `Reset` and handler call it.
- Tests: store seed counts/repeatability, HTTP route gating (404 when DEV off),
  seed load + prior-data wipe, config `DEV` flag and `devRoutes` helper.
- D18 records the third duplicate-loop race and the in-place convergence.

## State
- `go test ./...` and the full gate pass (build, vet, race tests, both smoke
  variants). No servers started on fixed ports; no `.env` or PLAN.md edits.
- Next unchecked task is A11.

## Next action (A11, first unchecked task)
- Implement `GET /me` and `PUT /me` returning the profile plus `derived`
  (`eligible`, `next_eligible_at`, `donation_count`, `rank: null` for now), and
  `POST /requests/{id}/donated` (donor who joined the room) -> 201
  `{"donation":{"id","request_id","donated_at"},"donation_count":int}`,
  idempotent per (donor, request), publishing `donation.recorded`.
- Reuse `matching.Compatible`/`Eligible` for derived eligibility. Keep A8/A9's
  donation-on-accept row and the smoke's SQLite check intact; extend with HTTP.
- Then gate, tick A11, append decisions, rewrite this file, commit.

## Gotchas / blockers
- No blockers; no human input needed (no device, credentials or fixed port).
- Duplicate api loops recur (D15/D17/D18): re-read files before each write,
  keep commits atomic, dedupe rather than revert a peer's version.
- Auth contract drift: addendum v2 says `otp`, handler reads `code`. Smoke sends
  both; reconciling docs/handler is part of A14.
- Do NOT edit `.env`, docs/PLAN.md, docs/API.md or the other agent's `app/`
  files (overnight-loop rule 5 restricts edits to api/ + handoff/tasks/decisions).
- docs/API.md still shows old v1 notifications/config shape and "no mark-read
  endpoint"; reconciling it is deferred to A14 (doc pass).
- `NEXCONN_FAKE` / `NEXCONN_MOCK` are dev env switches, not `GET /config` flags;
  real SDK mode is the default.
