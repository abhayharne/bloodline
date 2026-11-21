# API-agent decisions (append only; newest at bottom)

This file is the overnight-loop decision log for the `api` agent. Earlier
decisions D1-D12 live in `docs/DECISIONS.md` (append-only, shared).

## D11 (backfill) — Extension architecture
Events bus (`internal/events`, panic-safe synchronous subscribers), `DonorFilter`
pipeline with pure `Compatible`/`Eligible`, `notify.Notifier` writing to
`notifications`, and `FEATURES` flags from env. Full text in `docs/DECISIONS.md`.

## D12 (backfill) — NEXCONN_MOCK=1
Dev-only no-op chat client for offline smoke runs; never a `GET /config` flag.
Full text in `docs/DECISIONS.md`. Kept working for older scripts.

## D13 — NEXCONN_FAKE=1 in-memory Nexconn client (task A2)
Real SDK mode remains the default. `NEXCONN_FAKE=1` selects a stateful in-memory
`nexconn.FakeClient`; the legacy `NEXCONN_MOCK=1` no-op stays for older scripts.
If both flags are set, fake wins. Both offline flags skip Nexconn credential
validation, but still require `JWT_SECRET`.

The fake implements the whole `nexconn.Client` interface: deterministic token
`fake-chat-token-<userID>`, room create (owner + initial members), join,
message send and freeze. It tracks users, room members, message contents and
frozen state; join/freeze are idempotent, unknown channels, duplicate creates,
empty ids, >100-member joins and messages to frozen rooms are rejected, and a
cancelled context is honoured. `Channel(id)` exposes a copy for tests.

Rationale: the offline loop can exercise request lifecycle and room behaviour
without network or credentials, and A9's smoke script can assert real fake
state later. State is per-process and lost on restart; no credentials or tokens
are stored or logged. This is a dev env switch, never a `GET /config` flag and
never enabled in production.

## D14 — A3 notification read state and config shape (task A3)
`POST /notifications/{id}/read` (auth required, 204) marks one notification read
via `Store.MarkNotificationRead`. It is owner-scoped and idempotent: re-marking
an already-read row keeps the original `read_at` and still returns 204. A missing
row or a row owned by someone else both map to 404 (`ErrNotFound`), deliberately
not 403, so the endpoint cannot be used to probe another user's inbox.

`GET /notifications` now also returns a `read` boolean per row (derived from
`read_at`) per addendum v2; the legacy `read_at`, `user_id` and `request_id`
fields remain as additive extras that clients ignore. `GET /config` adds the
fixed `demo_mode: true` marker from the addendum. docs/API.md still describes the
older v1 shape; reconciling it is deferred to task A14 (doc pass) because the
overnight-loop rules restrict this iteration's edits to api/ + handoff/tasks/
decisions files. The bus, notifier, config and notifications code already had
tests; added race-free concurrent pub/sub, partial notifier write-failure,
mark-read store/HTTP owner-scoping and `read`/`demo_mode` shape tests.

## D15 — Duplicate loop processes on iteration 1 (operational)
Two `scripts/loop.sh opencode api ...` invocations were running the identical
"iteration 1" prompt against the same working tree at once (two `opencode run`
PIDs). The parallel process authored and committed A3 (`ca676a3`) while this
process verified the gate and deferred further writes to avoid racing it. No
code was duplicated or reverted. Decision: when a parallel api loop is detected,
let the in-flight process finish its commit, verify gate + task box + handoff,
and record the anomaly here instead of competing on the same task.

## D16 — A9 self-contained smoke script
`scripts/smoke.sh` no longer expects an externally running server. It builds
`./cmd/server` into a temp dir, asks the OS for a free ephemeral port with a
tiny Python socket helper, starts the server with `NEXCONN_FAKE=1`, an explicit
`JWT_SECRET`, `DEMO_OTP=123456`, `MATCH_RADIUS_KM=10`, a temp `DB_PATH` and the
inherited `FEATURES`, then kills it in an EXIT trap. Explicit env values win
over any local `.env` the server loads, so runs are deterministic.

The script asserts health, config, three signups (requester/donor/bank), the
mock OTP send/verify pair, bank stock PUT/GET, request creation with match
counts and `channel_id == "req"+id`, the donor feed's `joined`/`distance_km`
fields, idempotent accept, notification read, fulfill and feed transitions.
Auth bodies include both `otp` (addendum v2) and `code` (what the current
`/auth/verify` handler actually reads); unknown fields are ignored, so the one
script keeps working when the handler is reconciled in A14.

There is no donation read endpoint until A11, so the "donated" step checks the
`donations` row written on donor accept directly in the throwaway SQLite DB
with Python's stdlib `sqlite3`; it also asserts the requester's
`request.accepted` notification. When A11 lands, add an HTTP assertion rather
than removing the DB check. The gate now runs the script twice (`FEATURES=`
and `FEATURES=ranks,reminders`); both passed. Requires curl, jq, python3 and go.

## D17 — Duplicate api loops again on iteration 2 (operational)
Two `opencode run` api loops for iteration 2 were live on the same tree again
(D15 recurrence). Two independently written smoke scripts raced: this session's
version was committed first (`6377709`), then the parallel process overwrote
the working tree with its own, broader version whose `jq_ok` helper dropped the
`--arg` options and whose failure path printed raw responses (including a JWT).
Rather than revert the other version, we fixed it in place (`e9b2286`): `jq_ok`
forwards every argument except the trailing label to jq, and failures redact
`token`, `otp` and `phone` fields. Kept the parallel version's extra coverage
(OTP send/verify, idempotent mark-read, SQLite donation-row check, post-flow
config check). Rule retained: with duplicate loops, commit small atomic changes,
re-read files before each write, verify the gate, and never revert a peer's work.

## D18 — A10 duplicate-loop convergence (operational)
Iteration 3 had two api loops writing A10 at once (D15/D17 recurrence). The
peer's `db/seed.sql` (extra `request_members` rows, full donor profiles) and
`db/embed.go` Seed embed were kept; my duplicate Seed declaration was removed
in place, never reverted. The store method raced between `Reset` and `Reseed`,
so `api/internal/store/seed.go` now defines `Reset` plus a `Reseed` alias,
which keeps every caller compiling regardless of which name a loop used.
The dev route is registered only via `httpapi.WithDevRoutes()` when `DEV=1`;
`POST /dev/reset` is unauthenticated so the demo can reset before login.
The transaction wipes notifications, donations, request_members, requests,
bank_stock and users before inserting the seed, so resets are repeatable.
