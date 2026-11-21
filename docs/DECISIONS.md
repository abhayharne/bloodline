# Decisions (append only; newest at bottom)

## D1 — SQLite over Postgres
Zero setup, single file, fine for demo scale. Reconsider only if concurrency problems appear.

## D2 — Go stdlib net/http
Go 1.22 mux supports method+path patterns; fewer dependencies, faster to get running.

## D3 — Backend owns room creation and membership
Client never decides who is in a room. Server creates the channel via Nexconn server API.
Fallback if the server API cannot do it: see PLAN T0.4.

## D4 — Matching order
Banks with sufficient stock first (sorted by distance), then donors with same blood group
within MATCH_RADIUS_KM (default 10), max 10 donors notified, sorted by distance.

## D5 — Simple auth
JWT from signup/login with no passwords (name + role + group). Hackathon scope, noted in pitch as a known limitation.

## Parked ideas (do NOT build)
- Donor verification, donation history, eligibility timers (90-day rule)
- Component-wise requests (platelets, plasma)
- e-Raktkosh integration
- Multi-language UI

## D6 — Nexconn data center: Singapore
App created in the Singapore data center. Server API base: https://api.sg-light-api.com (backup https://api-b.sg-light-api.com).
The App Key's data center must match the Server API's. Client SDK must be initialised with `areaCode: AreaCode.sg`.
Source: docs.nexconn.ai/guides/data-center.

## D7 — Nexconn server request format (from docs)
Example: `POST /v4/auth/access-token/issue` with headers `App-Key`, `Nonce`, `Timestamp`, `Signature`, `Content-Type: application/json`
and body `{"userId","name","avatarUrl"}`. Signature algorithm NOT yet confirmed: check Server API -> Chat -> request signing
(RongCloud-style is sha1(appSecret + nonce + timestamp); VERIFY before relying on it). Prefer the official Go server SDK (NexconnAI-Dev/nexconn-server-sdk-go).
Call the Server API only from our backend, never from the app (App Secret must not leak).
