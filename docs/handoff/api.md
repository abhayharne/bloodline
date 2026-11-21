# Handoff
**From:** opencode (api, overnight loop)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** this iteration (see `git log -1`)

## Done this iteration
- Gate was PASS at entry and PASS after the change (`bash scripts/gate-api.sh`).
- A3 complete (first unchecked task; now ticked). Confirmed the already-present
  `internal/events` bus, `notify.Notifier`, env-driven `GET /config`, and
  `GET /notifications`, then filled the gap: `POST /notifications/{id}/read`.
- Mark-read: auth required, 204, owner-scoped, idempotent (keeps original
  `read_at`). Missing/not-owned both return 404 to avoid inbox probing. Added
  `Store.MarkNotificationRead`, `Service.MarkNotificationRead`, handler + route.
- `GET /notifications` now includes addendum `read` bool (derived from `read_at`);
  legacy `read_at`/`user_id`/`request_id` kept as ignored extras.
- `GET /config` now includes fixed `demo_mode: true` (addendum v2).
- Tests added: store mark-read (idempotent/owner-scoped/missing), HTTP mark-read
  (204/auth/owner-scope), `read` bool + `demo_mode` shape, concurrent pub/sub
  (race-free), notifier continues after a partial store write failure.
- Decision recorded as D14 in `docs/decisions-api.md`.

## State
- `go build ./...`, `go vet ./...`, `go test -race -count=1 ./...` all pass via gate.
- First unchecked task is now A9 (`scripts/smoke.sh`); gate skips it until A9 is
  ticked. Note the gate will then run smoke with both `FEATURES=` and
  `FEATURES=ranks,reminders`.
- Working tree clean after the final commit; nothing pushed.

## Next action (A9, first unchecked task)
- Write `scripts/smoke.sh`, chmod +x. Random free port, start server with
  `NEXCONN_FAKE=1` and `JWT_SECRET` set, curl the full flow (signup requester/
  donor/bank, bank stock, create request, donor feed, accept, donated, fulfill)
  and assert status codes + key fields. Must pass under the two FEATURES values
  above. Make sure it kills the server on exit and uses a temp DB path.
- Then gate, tick A9, append decisions, rewrite this file, commit. Do not skip A10+.

## Gotchas / blockers
- No blockers; no human input needed. No device, real credentials or fixed port.
- Do NOT edit `.env`, docs/PLAN.md, docs/API.md or the other agent's `app/` files
  (overnight-loop rule 5 restricts edits to api/ + handoff/tasks/decisions).
- docs/API.md still shows the old v1 notifications/config shape and "no mark-read
  endpoint"; reconciling it is deferred to A14 (doc pass).
- `NEXCONN_FAKE` / `NEXCONN_MOCK` are dev env switches, not `GET /config` flags.
