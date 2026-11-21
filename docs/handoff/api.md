# Handoff
**From:** opencode (api, overnight loop, iteration 2)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** this iteration (see `git log -1`)

## Done this iteration
- Gate was PASS at entry and PASS after the change (`bash scripts/gate-api.sh`).
- A9 complete (first unchecked task; now ticked). Replaced the old "expect a
  server already running" `scripts/smoke.sh` with a self-contained 10-step
  end-to-end script; still executable.
- New smoke: builds `./cmd/server` into a temp dir, OS-assigned random free
  port, temp `DB_PATH`, explicit `JWT_SECRET`/`DEMO_OTP`/`MATCH_RADIUS_KM`,
  `NEXCONN_FAKE=1`, inherited `FEATURES`, EXIT trap kills the server.
- Covers signup requester/donor/bank, OTP send+verify (and a 401 wrong-code
  check), bank stock PUT/GET, create request (match counts + `req<id>` room),
  role-aware donor feed, idempotent accept, donation row + notification read,
  fulfill and feed transitions, and exact `GET /config` features.
- Gate runs it twice (`FEATURES=`, `FEATURES=ranks,reminders`); both SMOKE OK.
- Decision recorded as D16 in `docs/decisions-api.md`.

## State
- `go build ./...`, `go vet ./...`, `go test -race -count=1 ./...` and both
  smoke variants pass via the gate.
- Working tree clean after the final commit; nothing pushed. No stray server
  processes: the trap kills the child on every exit path.
- First unchecked task is now A10 (`/dev/reset` + seed data).

## Next action (A10, first unchecked task)
- Seed 5 donors, 2 banks with stock, 1 open request, all with unique phones
  and alphanumeric ids; expose `POST /dev/reset` only when `DEV=1` (reload
  seed into a fresh DB). Keep additive to existing `api/db/seed.sql`.
- Then gate, tick A10, append decisions, rewrite this file, commit. Do not
  skip A11+. Remember the gate now runs smoke on every pass, so keep the
  happy path green.

## Gotchas / blockers
- No blockers; no human input needed. No device, real credentials or fixed
  port. Smoke needs curl, jq, python3 and go (all present in this environment).
- Auth contract drift: addendum v2 says `otp`, handler reads `code`. Smoke
  sends both; reconciling docs/handler is part of A14, not this task.
- No donation read endpoint until A11, so smoke checks the SQLite `donations`
  row directly. Do not remove that check when adding A11; extend it with HTTP.
- Do NOT edit `.env`, docs/PLAN.md, docs/API.md or the other agent's `app/`
  files (overnight-loop rule 5 restricts edits to api/ + handoff/tasks/decisions).
- docs/API.md still shows the old v1 notifications/config shape and "no mark-read
  endpoint"; reconciling it is deferred to A14 (doc pass).
- `NEXCONN_FAKE` / `NEXCONN_MOCK` are dev env switches, not `GET /config` flags;
  real SDK mode is the default.
