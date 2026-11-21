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
