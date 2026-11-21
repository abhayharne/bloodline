# Handoff
**From:** opencode  **To:** antigravity  **Time:** 2026-11-21 14:36 IST
**Branch:** main  **Last commit:** 2e41ca4

## Current task
P0 spikes. T0.3 (server-side Nexconn calls) is DONE; T0.2 (Flutter two-device chat) is the blocker.

## Done this session
- T0.3 spike: `api/cmd/spike/` proves token issue, group create, add member against
  https://api.sg-light-api.com. All three returned `code: 0`.
- Added `github.com/NexconnAI-Dev/nexconn-server-sdk-go v0.1.2` to `api/go.mod`
  (zero external deps; signs requests, adds X-Request-ID, does primary/backup failover).
- Signing confirmed: `sha1(AppSecret + Nonce + Timestamp)`, ms timestamp, JSON POSTs.
  Full details, exact bodies and implications for T1.4/T1.6 in docs/DECISIONS.md D8.

## State of the code
- Builds: `cd api && go build ./...` OK | Tests: `go test ./...` OK (no test files yet)
- API still serves only `GET /health`; T1.1 is the next backend task.
- Working spike room: `channelId=blspike1795251938`, owner `test1`, member `test2`.

## Next action (do this first)
- antigravity: T0.2 — minimal Flutter app, init SDK with `areaCode: AreaCode.sg`, connect
  as `test1` and `test2` on two devices, exchange a message.
- Quick check while you are there: `test1`'s channel list should show the spike room
  `blspike1795251938` (server-side creation already verified). That closes T0.3's
  "visible in the app" criterion.
- opencode (after T0.2): T1.1 project init (config from env, SQLite + schema, `/health`),
  then T1.4 using the SDK calls from D8.

## Gotchas / things I learned
- SDK method names are `CreateGroupChannel` / `JoinGroupChannel` (the README shows
  `CreateGroup`/`Join`, which do not exist).
- `channelId` must be alphanumeric, max 64 chars — no `_` or `-`.
- `/group-channel/join` adds members without approval and does **not** require the user
  to be registered first; max 100 per call. `/group-channel/create` takes up to 30 `userIds`.
- Access-token issue *is* user registration; tokens are valid indefinitely by default.
- `SetPrimaryBackupDomains` needs both URLs — the SDK embeds no default domain.
- `.env` is loaded by the spike itself (nearest `.env` walking up; real env wins).

## Open questions for the human
- Keep the `spike` command around as a connectivity check, or delete it after T0.3 sign-off?

## Do NOT touch
- Nothing yet. antigravity owns `app/`; opencode owns `api/` and `docs/API.md`/`DATA_MODEL.md`.
