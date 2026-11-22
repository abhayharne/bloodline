# API Contract (v2 — reconciled with the shipped code)

Base: `http://<host>:8080` (the port is configurable with `PORT`). All bodies are
JSON. Auth is `Authorization: Bearer <jwt>` on every route **except** `/health`,
`/config`, `/auth/*` and the dev-only `/dev/*` routes.

Errors are `{"error":"message"}` with status 400 (bad input), 401 (missing/invalid
token or OTP), 403 (wrong role or ownership), 404 (not found), 409 (conflict /
request not open), or 500. Unknown JSON fields are ignored everywhere.

Change this doc FIRST, then the code. `docs/API-addendum-v2.md` is the shared v2
contract; the few places where the shipped code has not caught up with it are
listed under **Deviations from addendum v2** at the end of this file so nothing
breaks silently.

**IDs are alphanumeric only (A-Z, a-z, 0-9; no `_` or `-`)** — Nexconn rejects
non-alphanumeric channel ids. User ids look like `u<hex>`, request ids `r<hex>`,
donation ids `d<hex>`, notification ids `n<hex>`, and `channel_id` is always
`"req" + request id` (request `r1` -> channel `reqr1`).

**Timestamps:** every `created_at` returned by the API (signup/verify/login
`user`, `/me`, requests, notifications, and `donated_at`, which maps from a
donation's `created_at`) is RFC3339 UTC with a trailing `Z`, for example
`2026-11-22T10:00:00Z`. New rows are written in that format; legacy SQLite
`YYYY-MM-DD HH:MM:SS` rows are normalised on read, and a missing/unparseable
legacy value is reported as `1970-01-01T00:00:00Z` so the field is never empty.

## Configuration (environment)

Secrets are read from the environment / `.env` only and never appear in a response.

| Var | Default | Purpose |
|---|---|---|
| `PORT` | `8080` | Listen port |
| `DB_PATH` | `./bloodline.db` | SQLite file (created/migrated on boot) |
| `JWT_SECRET` | required | Signs app JWTs |
| `DEMO_OTP` | `123456` | Fixed mock OTP accepted by `/auth/verify` |
| `MATCH_RADIUS_KM` | `10` | Positive float; radius for the donor/bank feed |
| `FEATURES` | empty | Comma-separated, lowercased, de-duplicated flags (`ranks`, `reminders`) |
| `DEV` | unset | `1` registers the unauthenticated `/dev/*` routes |
| `NEXCONN_FAKE` | unset | `1` uses the in-memory stateful fake chat client (offline) |
| `NEXCONN_MOCK` | unset | `1` uses the no-op chat client (offline); fake wins if both set |
| `NEXCONN_APP_KEY`, `NEXCONN_APP_SECRET`, `NEXCONN_API_BASE`, `NEXCONN_API_BASE_BACKUP` | required | Real Nexconn credentials/base URLs; not required in fake/mock mode |

## GET /health

Public. 200 `{"status":"ok"}`.

## GET /config

Public. Exposes client-safe flags only; never secrets or tokens.

200 `{"features":["ranks","reminders"],"demo_mode":true}`. `features` is the
parsed `FEATURES` list (empty `[]` by default); `demo_mode` is a fixed `true`
marker for the demo build.

## Phone auth (mock OTP)

OTP is a demo stub: there is no SMS gateway. The accepted code is the value of
`DEMO_OTP` (default `123456`). The code is never returned by the API and is never
logged. In production this must be replaced with a real OTP provider.

Phone syntax: 7-15 digits, optional leading `+`; spaces, parentheses and hyphens
are stripped before validation.

Both `POST /auth/verify` and `POST /auth/signup` accept the one-time code in
either the `code` or `otp` field (aliases for the same value). If both are
supplied, `code` wins. Signup treats a supplied code as optional for legacy
clients, but a wrong value is rejected with 401 `invalid otp`.

### POST /auth/otp/send

```json
{ "phone": "+919876543210" }
```

200 `{"sent":true}` for any syntactically valid phone. Unknown numbers are
accepted too, so the endpoint cannot be used to enumerate accounts. 400 for an
invalid phone.

### POST /auth/verify

```json
{ "phone": "+919876543210", "code": "123456" }
```
`otp` may be used instead of `code` (or as well; `code` wins).

200 with the same shape as signup **if the phone belongs to an existing user**
(this is the login path). 401 `{"error":"invalid otp"}` for a wrong code, 404
`{"error":"user not found"}` if no account has that phone, 400 for missing or
invalid fields.

### POST /auth/signup

```json
{
  "phone": "+919876543210", "otp": "123456", "name": "Asha", "role": "donor", "blood_group": "O+",
  "lat": 21.1458, "lng": 79.0882,
  "sex": "female", "age": 28, "weight_kg": 58, "height_cm": 163,
  "donated_before": false, "last_donated_at": null, "available": true,
  "consent": true
}
```

Rules: `name` required; `role` is `requester|donor|bank`; `blood_group` required
for requester and donor and must be **omitted** for bank; `phone` unique; `sex`
is `male|female|other`; `age` is 0-120 (0/absent = unknown); `weight_kg` and
`height_cm` must not be negative; `last_donated_at` is an RFC3339 timestamp or a
`YYYY-MM-DD` date; `available` defaults to `true`; an explicit `consent: false`
is rejected and `consent: true` records `consent_at`. `otp`/`code` is optional
but, when present, must equal `DEMO_OTP` (401 otherwise).

201:
```json
{ "user":{ "id":"u...", "phone":"+919876543210", "name":"Asha", "role":"donor",
           "blood_group":"O+", "lat":21.14, "lng":79.08, "sex":"female", "age":28,
           "weight_kg":58, "height_cm":163, "donated_before":false,
           "last_donated_at":null, "available":true, "consent_at":"2026-11-22 10:00:00",
           "created_at":"2026-11-22T10:00:00Z" },
  "token":"<app jwt>", "nexconn_token":"<chat token>" }
```

### POST /auth/login (legacy, deprecated)

```json
{ "name": "Asha", "role": "donor" }
```

200 same shape as signup; 404 `{"error":"user not found"}`. Kept for seed users
and older clients; new clients should use `POST /auth/verify`.

## Profile

### GET /me

Any authenticated role. `user.created_at` is included in RFC3339 UTC `Z` form
(as in signup). 200:
```json
{ "user":{...profile..., "created_at":"2026-11-22T10:00:00Z"},
  "derived":{ "eligible":true, "next_eligible_at":null,
              "donation_count":2,
              "rank":{ "key":"helper", "label":"Helper" } } }
```
- `eligible` and `next_eligible_at` (a `YYYY-MM-DD` date or null) are computed for
  donors only; non-donors report `eligible:false`, `next_eligible_at:null`.
- `next_eligible_at` is null when no last donation is stored or the wait has
  elapsed. Unknown age/weight count as eligible (permissive defaults).
- `rank` is `null` unless the `ranks` feature is on. Keys/labels by donation
  count: `first_drop`/First Drop (1), `helper`/Helper (3),
  `silver_lifeline`/Silver Lifeline (5), `gold_lifeline`/Gold Lifeline (10),
  `lifesaver`/Lifesaver (25); highest reached wins.

### PUT /me

Partial update — only these fields are applied; omitted fields are unchanged:
```json
{ "available":false, "lat":21.1, "lng":79.0, "weight_kg":58,
  "height_cm":163, "last_donated_at":"2026-10-01" }
```
An empty `last_donated_at` clears the column. lat/lng/weight/height/date are
validated before any write. 200 with the same shape as `GET /me` (no follow-up
GET needed).

## Bank stock (bank role)

### GET /banks/me/stock

200 `{"stock":[{"blood_group":"O+","units":5,"updated_at":"..."}]}`.

### PUT /banks/me/stock

```json
{ "stock":[{"blood_group":"O+","units":5},{"blood_group":"O-","units":0}] }
```

200 same as GET.

## Notifications (any authenticated role)

### GET /notifications

Newest first (`created_at DESC`, insertion-order tiebreak); `created_at` is
RFC3339 UTC with a `Z` suffix.
```json
{ "notifications":[{
    "id":"n...", "user_id":"u...", "type":"request.created",
    "title":"New blood request", "body":"O- needed at City Hospital",
    "request_id":"r...", "read_at":null, "read":false, "created_at":"2026-11-22T10:00:00Z"
  }] }
```
`read` is the client-facing boolean derived from `read_at`; `user_id`,
`request_id` and `read_at` are additive extras. An empty inbox returns
`{"notifications":[]}`. Notification types: `request.created`,
`request.accepted`, `request.fulfilled`, `rank_up`, `match_nearby`,
`eligible_again`.

### POST /notifications/{id}/read

204 with an empty body. Owner-scoped and idempotent: re-marking an already-read
row is still 204. A missing row or a row owned by another user returns 404 (so
the endpoint cannot be used to probe another user's inbox).

## Requests

### POST /requests (requester)

```json
{ "blood_group":"O-", "units":2, "hospital":"City Hospital", "urgency":"critical",
  "lat":21.15, "lng":79.09 }
```
`blood_group` must be one of A+, A-, B+, B-, AB+, AB-, O+, O-; `units` must be
positive; `hospital` is required. Canonical `urgency` values are
`low|medium|high|critical`; the aliases `planned`→`low`, `med`→`medium` and
`urgent`→`high` are accepted and normalised before storage (400 for anything
else). `created_at` is RFC3339 UTC with a `Z` suffix.
201:
```json
{ "request":{ "id":"r...", "requester_id":"u...", "blood_group":"O-", "units":2,
              "hospital":"City Hospital", "urgency":"critical", "status":"open",
              "lat":21.15, "lng":79.09, "channel_id":"reqr...", "created_at":"2026-11-22T10:00:00Z",
              "fulfilled_at":null },
  "matches":{ "banks":1, "donors":4 } }
```
Matched banks are those holding enough compatible stock (top 2 by distance);
matched donors are the closest donors (top 10). With the `reminders` flag on,
the `isAvailable` and `isEligible` filters also apply to donors. Publishes
`request.created`; matched users get a notification row.

### GET /requests (requester, donor or bank)

Query: `status=open|fulfilled|cancelled|all` (default `open`). Rows are ordered
by urgency priority (`critical`, `high`, `medium`, `low`) and then by
`created_at` descending with an insertion-order tiebreak.
- requester: own requests
- donor: open requests whose `blood_group` equals the donor's and within `MATCH_RADIUS_KM`
- bank: requests within `MATCH_RADIUS_KM`

200 `{"requests":[{ ...request, "distance_km":3.2, "requester_name":"Ravi", "joined":false }]}`.

### POST /requests/{id}/accept (donor or bank)

Adds the caller to the room. 200 `{"channel_id":"reqr..."}`. Idempotent; 409 if
the request is not open. Publishes `request.accepted` (the requester gets a
notification row); a donor accept also writes a `donations` row for the request.

### POST /requests/{id}/donated (donor who joined the room)

Records a donor's pledge. 201:
```json
{ "donation":{ "id":"d...", "request_id":"r...", "donated_at":"..." },
  "donation_count":3 }
```
Idempotent per (donor, request); `donation_count` never double-counts. 403 if the
caller is not a donor or has not joined the room, 404 for a missing request.
Publishes `donation.recorded` on every successful call (subscribers must be
idempotent).

### POST /requests/{id}/fulfill (requester who owns it)

Posts a system message, freezes the Nexconn room and sets status to `fulfilled`.
200 `{"request":{...,"status":"fulfilled"}}`. Publishes `request.fulfilled`; all
joined members get a notification row. 403 for a non-owner, 409 if not open.
The response reflects the row read before the status write, so its `fulfilled_at`
may still be null even though the stored row is stamped.

## Dev routes (only when DEV=1, all unauthenticated)

- `POST /dev/reset` -> `{"status":"ok","seeded":true}` — reloads the demo seed
  (5 donors, 2 banks with stock, 1 open request, all with phones).
- `POST /dev/run-reminders` -> `{"status":"ok","sent":N}` — runs one
  `eligible_again` eligibility scan; `sent` is the number of reminders written
  (0 on a repeat). Works even when the `reminders` flag is off.

## Events and feature flags

In-process bus (a failing subscriber never breaks a request): `user.signed_up`,
`request.created`, `request.accepted`, `request.fulfilled`, `donation.recorded`.
- `ranks`: `/me` fills `derived.rank`; a `rank_up` notification is emitted once
  per crossed threshold on `donation.recorded`.
- `reminders`: enables the donor availability/eligibility filters in matching,
  a `match_nearby` notification on `request.created`, and a hourly
  `eligible_again` ticker (plus the dev route above).

## Offline / chat modes

Real Nexconn mode is the default and requires the four `NEXCONN_*` credentials.
`NEXCONN_FAKE=1` uses a stateful in-memory client: token
`fake-chat-token-<userID>`, room create/join/message/freeze, all per-process and
lost on restart. `NEXCONN_MOCK=1` is a no-op client kept for older scripts. Both
offline modes still require `JWT_SECRET`. `scripts/smoke.sh` uses the fake mode
on a random free port; `scripts/gate-api.sh` runs it with `FEATURES=` and
`FEATURES=ranks,reminders`.

## Deviations from docs/API-addendum-v2.md (as shipped)

These are known gaps between the running code and the addendum; clients should
tolerate them until the code is reconciled:

- `POST /auth/otp/send` returns `{"sent":true}` without the addendum's `demo` field.
- `POST /auth/verify` now accepts `otp` and `code`, but has no `is_new`
  pre-signup path: an unknown phone returns 404 `user not found`, not
  200 `{"is_new":true}`.
- `POST /auth/signup` now accepts `otp`/`code` when supplied, but only rejects an
  **explicit** `consent:false`; it does not require `consent:true` for donors.
- `GET /notifications` rows carry additive `user_id`, `request_id` and `read_at`
  beyond the addendum's minimal shape.
- `GET /config` exposes `features:[]` by default; there is no `notifications`
  default flag.
