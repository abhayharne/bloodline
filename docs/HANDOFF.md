# Handoff
**From:** opencode  **To:** antigravity  **Time:** 2026-11-21 15:18 IST
**Branch:** main  **Last commit:** 23757af

## Current task
P1 backend. T1.1, T1.2, T1.3 are DONE with tests. T1.4 (`POST /requests`) is next, not started.
P0: T0.3 signed off; T0.4 marked not needed; T0.2 (Flutter two-device chat) still open.

## Done this session
- T0.3 sign-off: spike deleted, PLAN ticked, T0.4 marked not needed.
- All ids are alphanumeric only. `docs/API.md` / `DATA_MODEL.md` document `channel_id = "req"+request_id`
  (request `r1` -> `reqr1`); `api/db/seed.sql` uses `ureq1` / `udon1` / `ubank1`.
- T1.1: `internal/config` (env + `.env` loader), embedded schema (`api/db/embed.go`), `internal/store`
  (SQLite open + schema), `GET /health`.
- T1.2: `internal/auth` HS256 JWT, `internal/id` alphanumeric ids, `internal/nexconn` SDK wrapper behind
  `nexconn.Client`, `internal/service` signup/login, `POST /auth/signup` + `POST /auth/login`.
  Both call Nexconn `IssueToken` and return `nexconn_token`.
- T1.3: `GET/PUT /banks/me/stock` with bank-role JWT middleware; stock upsert + read in store.
- Tests: config, store, JWT, id, and HTTP handlers with a fake Nexconn client.

## State of the code
- Builds: `cd api && go build ./...` OK.
- Tests: `cd api && go test ./...` OK; `go test -race ./...` OK.
- Run: `cd api && go run ./cmd/server` (loads nearest `.env`; listens on :8080).
- Implemented: `GET /health`, `POST /auth/signup`, `POST /auth/login`, `GET/PUT /banks/me/stock`.
  No request endpoints yet.
- DB: schema auto-applied on boot; `bank_stock` upsert keeps zero-unit rows.

## Next action (do this first)
- antigravity: T0.2 — two-device chat; confirm `test1` sees the spike room. Then continue P2 app screens.
- opencode (next session): T1.4 `POST /requests` using D8. `nexconn.Client` already has
  `CreateGroupChannel` / `JoinGroupChannel`; generate request id `r...` and channel id `req`+request id.

## Gotchas / things I learned
- Nexconn channel ids must be alphanumeric, max 64; use `req` + request id.
- Credentials come from env; `cfg.Debug=false`; never log secrets or tokens.
- SDK names are `CreateGroupChannel` / `JoinGroupChannel` (`CreateGroup` / `Join` do not exist).
- Access-token issue registers the user; re-issuing for the same user is safe.
- `go.mod` stays on Go 1.22 with `modernc.org/sqlite v1.34.5`; v1.62 forces Go 1.26.
- `store` uses `MaxOpenConns(1)` so SQLite PRAGMAs stay effective.
- `app/` is an untracked Flutter scaffold (not committed by opencode). Never `git add -A`.

## Open questions for the human
- T0.2 is still unchecked; is two-device chat confirmed?
- Keep real Nexconn credentials only in the local `.env`.

## Do NOT touch
- `app/` (antigravity). opencode owns `api/`, `docs/API.md`, `docs/DATA_MODEL.md`.
- Do not start T1.4 in this session (per instruction); next opencode session can.
