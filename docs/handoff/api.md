# Handoff
**From:** opencode (api, overnight loop)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** ace2fb8

## Done this iteration
- Gate was PASS at entry and PASS after the change (`bash scripts/gate-api.sh`).
- A2: `nexconn.FakeClient` (`api/internal/nexconn/fake.go`) — stateful in-memory
  token issue, room create/join, message send and freeze; idempotent join/freeze,
  rejects unknown/duplicate rooms, frozen-room messages, empty ids and >100-member
  joins, honours cancelled contexts. `Channel(id)` gives a defensive snapshot.
- `NEXCONN_FAKE=1` selects the fake; real SDK stays default; legacy
  `NEXCONN_MOCK=1` no-op still works; fake wins if both are set. Both offline
  flags skip Nexconn credential validation (JWT_SECRET is still required).
- Tests: fake lifecycle/errors/concurrency, config flag combinations,
  `newChatClient` mode selection. D13 recorded in `docs/decisions-api.md`.
- Verified offline end-to-end on a random port with no Nexconn credentials:
  signup x3 -> bank stock -> request -> donor feed -> accept -> fulfill ->
  notifications. Chat tokens were `fake-chat-token-<userID>` throughout.

## State
- `go build ./...`, `go vet ./...`, `go test -race -count=1 ./...` all pass.
- First unchecked task is now A3. Much of A3 already exists in code from the
  earlier session: `internal/events`, `internal/notify`, `GET /config`,
  `GET /notifications`. Verify against the addendum instead of rebuilding.
- `scripts/smoke.sh` exists but A9 is unticked, so the gate does not run it yet.
- Working tree clean; nothing pushed.

## Next action (A3, first unchecked task)
- Add `POST /notifications/{id}/read` (204, owner-only), add tests for it and
  for the already-present bus/notifier/config/notifications code, and make
  `GET /notifications` use the addendum shape (`read` bool) if needed.
- Run `scripts/gate-api.sh`, tick A3 in `docs/tasks-api.md`, append decisions to
  `docs/decisions-api.md`, rewrite this file, commit. Do not skip to A4+.

## Gotchas / blockers
- No blockers; no human input needed. No device, real credentials or network
  used. Do not edit `.env`, docs/PLAN.md or the other agent's `app/` files.
- `NEXCONN_FAKE` is a dev env switch, not a `GET /config` feature flag.
- `docs/decisions-api.md` was created this iteration; D11/D12 full text still
  lives only in the shared `docs/DECISIONS.md` (append-only).
- Add `.env.example` note for `NEXCONN_FAKE=0` during A14 doc pass.
