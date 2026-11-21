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

## D8 — T0.3 spike: Nexconn server API signing + room creation CONFIRMED
Status: all three calls returned `code: 0` against `https://api.sg-light-api.com` (2026-11-21).
Code: `api/cmd/spike/` (throwaway; delete after T0.3 sign-off). SDK added: `github.com/NexconnAI-Dev/nexconn-server-sdk-go v0.1.2`.

**Signing (confirmed in docs.nexconn.ai/platform-chat-api/prepare-to-use-api/auth and in the SDK source):**
- `Signature = sha1(AppSecret + Nonce + Timestamp)` hex-encoded. No MD5, no body in the hash.
- `Nonce`: random string, max 18 chars, unique per request (SDK: random decimal up to 1e18).
- `Timestamp`: Unix **milliseconds**.
- Headers on every call: `App-Key`, `Nonce`, `Timestamp`, `Signature`, `Content-Type: application/json`,
  optional `X-Request-ID` (SDK adds a UUID automatically). All endpoints are `POST`. HTTPS only.
- 401 means signature/app-key mismatch.

**Official Go SDK fits — use it.** Module `github.com/NexconnAI-Dev/nexconn-server-sdk-go` (v0.1.2, go 1.18,
zero external deps, OpenAPI-generated). It signs requests, generates nonce/timestamp/X-Request-ID, and does
primary->backup failover. Notes:
- `cfg.SetNexconnCredentials(appKey, appSecret)`; `cfg.SetPrimaryBackupDomains(primary, backup)` — both URLs
  are required, the SDK embeds no default domain.
- Generated method names differ from the README example: `CreateGroupChannel`, `JoinGroupChannel`
  (not `CreateGroup`/`Join`). Builder: `client.GroupChannelManagementAPI.CreateGroupChannel(ctx).GroupChannelCreateRequest(req).Execute()`.
- Errors: `*ncsdk.GenericOpenAPIError` with `HttpStatus()`, `ErrorCode()`, `ErrorMessage()`, `Body()`.

**Working calls (bodies shown exactly as sent; secrets/tokens redacted):**
1. Mint user token — `POST /v4/auth/access-token/issue`
   `{"userId":"test1","name":"BloodLine Test One"}` -> `code:0, result:{userId:"test1", accessToken:<84 chars>}`.
   This call *is* user registration; no separate register step exists. Tokens are valid indefinitely by default
   and re-issuing for the same userId is safe.
2. Create group — `POST /v4/group-channel/create`
   `{"channelId":"blspike1795251938","name":"BloodLine spike room","owner":"test1"}` -> `code:0`.
   Creator/owner joins automatically. `channelId` max 64 chars, **alphanumeric only** (no `_`/`-`), so generate
   ids like `req<id>` / `blspike<unix>`. `name` max 64 chars.
3. Add member — `POST /v4/group-channel/join`
   `{"channelId":"blspike1795251938","userIds":["test2"]}` -> `code:0, result:{memberCount:2, owner:"test1", ...}`.
   Adds without approval, max 100 users per call. **The member does not need to exist first** (test2 had never
   obtained a token and join still succeeded), so T1.4 can create the room + add banks in one go.

**Implications for T1.4/T1.6:**
- Create the room with `owner` = requester and pass `userIds` (max 30) for the first banks directly in
  `/group-channel/create`; use `/group-channel/join` later for donors accepting (`POST /requests/{id}/accept`).
- Store the Nexconn `channel_id` on the request row; `join` returns `memberCount` for verification.
- Room "close" on fulfill: `/v4/group-channel/freeze-list/add` (freeze) or `/v4/group-channel/dismiss` (delete) —
  decide in T1.7, not needed for the spike.
- Verified in the console/app: pending AG's T0.2 — the channel `blspike1795251938` (and later spike rooms)
  should appear in `test1`'s channel list once the Flutter client connects.


## D9 — ai_nexconn_chatui_plugin Android plugin class casing bug
The pub.dev package (v26.2.11) declares `pluginClass: AiNexconnChatUIPlugin` in its pubspec.yaml
but the Kotlin source file is named `AiNexconnChatuiPlugin.kt` (lowercase "ui"). On case-sensitive
Linux filesystems, Flutter's plugin loader cannot find the class and the build fails at plugin
registration. Workaround: rename `AiNexconnChatuiPlugin.kt` to `AiNexconnChatUIPlugin.kt` inside the
pub cache (a symlink causes a Kotlin "Redeclaration" compiler error because both files get compiled).
Noted in DECISIONS so other developers can reproduce the fix. The class *inside* the file
is correctly named `AiNexconnChatUIPlugin`.

## D10 — Debug screen as default home for T0.2 spike
During P0, the app starts on a DebugScreen where you paste a Nexconn user token and connect.
This will be replaced by the login flow in T2.2. The screen also has a shortcut to open the
spike room `blspike1795251938` for quick end-to-end verification.

## D11 — App Extensibility Architecture & SlotRegistry
`SlotRegistry` singleton provides extension slots (`homeCards`, `profileSections`, `roomHeaderBadges`).
Each feature folder (`lib/features/<name>/`) provides a `register.dart`. In the core build, the registry
is empty by default so core screens render cleanly without clutter, while extension packages can register
rich widgets, cards, and room badges dynamically.

## D12 — Resilient ApiClient with In-Memory Mock Store
`ApiClient` conforms to `docs/API.md` contract. When backend is offline or `mockMode` is enabled,
it provides stateful mock data (users, requests, matches, bank stocks) to enable offline testing and
parallel UI development. All JSON model `fromJson` factories safely ignore unknown fields to prevent breaking changes.

## D13 — Phone + Mock OTP & Demographic Form Flow
Authentication uses phone number with 6-digit mock OTP (default 123456) and quick demo profiles.
Profile form captures name, age, weight, height, sex, previous donation history, and location via device GPS
with typed-area fallback (preset popular areas).

