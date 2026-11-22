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

## D11 — Extension architecture: events, filters, notifier, flags
Goal: keep the hackathon happy path simple while making later extension cheap.

1. **Events bus** (`api/internal/events`): tiny in-process synchronous pub/sub. Subscribers
   register by event name; `Publish` delivers to each matching subscriber. A panic in one
   subscriber is recovered and reported per-subscriber so it cannot crash the request or
   starve other subscribers. No network, no persistence, no globals: the bus is injected
   into the service. Event names: `request.created`, `request.accepted`, `request.fulfilled`.
   Payloads carry ids/labels only — never JWTs, chat tokens, OTPs or phone numbers beyond
   the recipient user id. Synchronous delivery keeps the demo deterministic and testable;
   replace with a queue only if the bus ever does real I/O.
2. **DonorFilter pipeline** (`api/internal/matching`): matching is expressed as an ordered
   list of `DonorFilter` predicates (compatibility, distance, availability, eligibility).
   `Compatible(patientGroup, donorGroup)` is a pure ABO/Rh chart; `Eligible(donor, now)`
   is a pure rule (age 18-65, weight >= 45 kg, >= 90 days since last donation for male /
   >= 120 days for female or unspecified). Both are unit-tested now, but are **not wired
   into the live matching path** in this phase: D4's exact-group rule stays live so the
   seeded demo keeps its expected counts. Enabling the pipeline is a feature-flagged
   follow-up, not a silent contract change.
3. **Notifier** (`api/internal/notify`): an events subscriber that writes rows to
   `notifications`. The app polls `GET /notifications` and shows an in-app banner; no push
   provider is added (stretch item in PLAN). Notification rows are additive and safe to
   ignore for older clients. Errors are logged without secrets; a failed notification
   write never rolls back the primary request mutation.
4. **Feature flags** (`config.FEATURES`): comma-separated env list exposed by public
   `GET /config` as `{"features":[...]}`; empty by default. Flags describe client-visible
   capabilities only; they never contain credentials and do not change the core contract.
   `DEMO_OTP` (default `123456`) is a separate mock-auth setting, not a flag.
5. **User profile + donations tables**: `users` gains phone (unique), sex, age, weight_kg,
   height_cm, donated_before, last_donated_at, available (default 1) and consent_at for
   phone signup and future eligibility filtering. `donations` records a donor's pledge on
   accept; `notifications` records events. Fresh databases use `db/schema.sql`; existing
   databases get idempotent `ALTER TABLE` migrations on boot.

## D12 — NEXCONN_MOCK=1 for offline smoke runs
Dev-only env switch: when set, the API uses `nexconn.NoopClient` (dummy chat token, no
network) and skips credential validation. It exists solely so `scripts/smoke.sh` can
verify signup -> request -> accept -> fulfill without Nexconn credentials or internet.
Never enable in production; it is not a feature flag and is not exposed by GET /config.
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

## D14 — Error Handling, Defensive Timestamps, and Explicit Demo/Logout Semantics
1. Real error surfacing: Never silently fall back to mock data when USE_MOCK is false. Connection and login errors are displayed via SnackBar while remaining on the LoginScreen. A prominent "Demo mode (offline data)" banner displays when mockMode is active.
2. Defensive timestamp parsing: null or empty created_at never throws; invalid date strings surface in a SnackBar via rootScaffoldMessengerKey.
3. Request broadcast: Upon creating a request, GET /requests is immediately refetched and active requests list updates.
4. Urgency enum: Segmented button sends low|medium|high|critical.
5. Logout with confirmation dialog: Clears tokens, user profile, SharedPreferences, disconnects Nexconn chat, and navigates to login.

## D15 — LocationController, Hospital Picker, Component Dropdown, and Reconciled Urgency Contract
1. Urgency contract reconciliation: API contract (docs/API.md line 195 and Go service validation) strictly mandates urgency as `critical|urgent|planned`. The backend rejects non-conforming urgency with HTTP 400 Bad Request, which caused requests to be rejected and fail to appear in the active feed. SegmentedButton now sends `critical|urgent|planned`, and full request/response payloads are logged.
2. LocationController architecture: Centralized `LocationController` supporting source `gps|preset|typed`. "Use Device GPS" button remains perpetually active; choosing GPS clears preset selection; the last selection wins. High-accuracy location query configured with 15s timeout and fallback to `getLastKnownPosition`. Explicit handling and user messages for services disabled (`Geolocator.openLocationSettings`), permission denied (retry action), denied forever (`Geolocator.openAppSettings`), and timeout. "Location not set" is shown when unset rather than defaulting silently to a preset.
3. Phone number normalization: 10-digit phone inputs normalize by prepending `+91` before calling OTP endpoints and profile registration. "demo mode, code 123456" is displayed on the OTP verification screen.
4. Hospital picker with GET /hospitals: Searchable picker backed by `GET /hospitals` sorted nearest first using user coordinates, including an "Other (type a name)" option. Selecting a hospital sets the request's geographical coordinates.
5. Component dropdown & notes: Added component dropdown (`Whole blood`, `Red cells`, `Platelets`, `Plasma`, `Other`) and optional notes field to the requester form. Room header displays component chip in live chat. Donor profile gets "I can donate platelets/plasma" capability toggle.
6. Unified logout with provider reset: `confirmAndLogout` dialog in Profile and Settings screens clears auth tokens, user profile, SharedPreferences, disconnects Nexconn, resets `RequestsProvider` and `NotificationsProvider`, and navigates to login. Debug screen launcher is hidden unless running in demo/mock mode.

## D16 — Location Pin Sharing in Chat and Live Requests Polling
1. Location pin message in chat (T2.7): Added `chat_share_location_button` to `BloodRequestChatScreen` AppBar actions and integrated `MessageInputExtensionPlugin.location` with `ChatPageConfig`. Users can share either the hospital location or current device GPS coordinates (with graceful fallback to profile coordinates). Messages are sent as `LocationMessageParams` through Nexconn Chat and surfaced via `location_pin_shared_snackbar`. Tapping any `LocationMessage` bubble presents coordinates and POI metadata in a modal details dialog.
2. Live feed synchronization (T2.9): Added periodic polling (`startPolling`, `stopPolling`, `isPolling`) to `RequestsProvider`, initialized in `main.dart` at a 10s interval matching `NotificationsProvider`. Uses silent background loading to refresh open requests without UI loading flicker or unhandled timer leaks in widget tests.

## D17 — Safe Navigation Stack, Fallback Routes, and Profile Screen Save Handling
1. Safe Profile Save handling: ProfileScreen in edit mode is embedded as a tab inside HomeScreen. Unconditional `Navigator.pop(context)` attempted to pop the root route, causing the screen to go black. In edit mode, ProfileScreen now refreshes user data via `fetchMe()`, displays a 'Profile saved' SnackBar, checks if embedded in HomeScreen (`context.findAncestorWidgetOfExactType<HomeScreen>()`), and only calls `Navigator.of(context).pop()` if running as a standalone route where `canPop()` is true.
2. Clean back stack on registration: In registration mode (`Complete Profile`, `isNewUser == true`), completing the profile now uses `pushAndRemoveUntil` to navigate to `HomeScreen`, clearing the back stack. Login and quick-login similarly use `pushAndRemoveUntil`.
3. Root MaterialApp fallback route & PopScope protection: Added `onGenerateRoute` and `onUnknownRoute` handlers returning `RootGate()` so unmatched or stray routes gracefully fallback to the home gate instead of a blank screen. Root shell and HomeScreen are wrapped with `PopScope(canPop: false)` to prevent accidental pops.



## D17 — Review fixes across API and Flutter
1. Red-cell ABO/Rh compatibility is keyed by recipient. The helper follows the
   Australian Red Cross Lifeblood chart. Live red-cell matching keeps D4's
   exact-group rule. Whole blood and other also require exact groups.
2. Limit donor notifications to the feed radius. Check group, component and
   distance before admitting new donors to a room, and check distance before
   admitting a new bank. Existing room members retain access.
3. Create the chat room before inserting the SQLite request and initial
   membership in one transaction. A chat outage therefore cannot leave an
   open request pointing to a missing room. A database failure after successful
   chat creation can still leave a remote room without a request.
4. Scope Flutter polling to the signed-in session, with all statuses for
   requesters. Keep the eight-row bank editor scoped to whole blood and surface
   live hospital lookup errors so users can fall back to manual entry.

Reference: https://www.lifeblood.com.au/patients-recipients/blood-plasma-platelets/blood-for-transfusion/matching-blood-groups

## D18 — Verify the Flutter client against the shipped Go contract

- The live API accepted whole-number profile fields and canonical and legacy
  urgency values. The broadcast failure was the component display label on
  the wire. Flutter now sends snake_case component values and presents the
  canonical urgency options.
- Flutter accepts the existing OTP response shapes in API.md. The HTTP
  session is ready once saved, while native Nexconn connection proceeds
  asynchronously. Live role controls use the account's server-assigned role.
- Profile saving uses PUT /me for server-supported fields and retains the
  existing local storage for fields outside that contract. No API contract
  or schema change was needed.
- Overpass mirrors did not yield usable results. Keep the embedded samples
  and identify them as samples in the hospital picker.
