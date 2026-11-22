# Handoff
**From:** opencode (api, human-assigned contract fixes) **To:** next api session **Time:** 2026-11-22 13:56
**Branch:** feat/api **Last commit:** `3275f19` `[opencode] canonical urgency, RFC3339 created_at, OTP aliases`

## Done
- Docs updated first: `docs/API.md`, `docs/DATA_MODEL.md`, `docs/decisions-api.md` (D28), plus A15 in `docs/tasks-api.md`.
- Urgency is now canonical `low|medium|high|critical`. Service normalises `planned→low`, `med→medium`, `urgent→high` (case/whitespace insensitive); schema CHECK and seed use canonical values; `GET /requests` sorts by priority, then `created_at DESC`, then rowid. Boot migrates legacy `requests` tables in one transaction with FKs off.
- Every `created_at` (users including `/me`, requests, notifications, donations/`donated_at`) is RFC3339 UTC `Z`. New rows write `store.Timestamp()` / `strftime('%Y-%m-%dT%H:%M:%SZ','now')`; reads normalise legacy SQLite values and use `1970-01-01T00:00:00Z` for empty/unparseable ones. `User.CreatedAt` is now exposed in JSON.
- `/auth/verify` and `/auth/signup` accept either `code` or `otp`; `code` wins when both are supplied. Signup still permits a missing code but validates a supplied one (401 `invalid otp`).
- Tests added for timestamp normalisation, feed ordering, legacy `requests` migration, OTP aliases and wire timestamps; smoke now asserts aliases, ordering and `Z` timestamps.
- Entry and final `scripts/gate-api.sh` PASS: build, vet, `go test -race -count=1 ./...`, smoke with `FEATURES=` and `FEATURES=ranks,reminders`.

## State
- All tasks A0-A15 are `[x]`. The only working-tree item is the pre-existing untracked empty `api/data/hospitals.json`; it was not touched or committed.
- No `app/`, `.env`, `AGENTS.md` or `docs/PLAN.md` edits. No pushes. The earlier duplicate `loop.sh` processes are no longer running; a long-lived `go run ./cmd/server` (PID 279991) predates this session and was left alone.

## Next action
- None from the task list. Wait for the human to assign new work. If asked to verify D28, re-run `scripts/gate-api.sh` and read `docs/API.md` alongside `docs/decisions-api.md`.

## Blockers
- None.
