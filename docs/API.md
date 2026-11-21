# API Contract (v1)

Base: `http://<host>:8080`. JSON. Auth: `Authorization: Bearer <jwt>` except `/health`,
`/auth/*` and `GET /config`.
Errors: `{"error":"message"}` with status 400/401/403/404/409/500.
Change this doc FIRST, then the code.

**IDs are alphanumeric only (A-Z, a-z, 0-9; no `_` or `-`)** — Nexconn rejects
non-alphanumeric channel ids. User ids look like `u1a2b3c4`, request ids like `r1a2b3c4`,
and `channel_id` is always `"req" + request id` (request `r1` -> channel `reqr1`).

## GET /health
200 `{"status":"ok"}`

## GET /config
Public (no auth). Exposes client-safe feature flags only; never secrets or tokens.
`FEATURES` is a comma-separated env list, empty by default.
200 `{"features":["notifications"]}` (or `{"features":[]}` by default).

## Phone auth (mock OTP)
OTP is a demo stub: there is no SMS gateway. The accepted code is the value of the
`DEMO_OTP` env var (default `123456`). The code is never returned by the API and is
never logged. In production this must be replaced with a real OTP provider.

### POST /auth/otp/send
```json
{ "phone": "+919876543210" }
```
200 `{"sent":true}` for any syntactically valid phone. Unknown numbers are accepted too,
so the endpoint cannot be used to enumerate accounts. 400 for an invalid phone.

### POST /auth/verify
```json
{ "phone": "+919876543210", "code": "123456" }
```
200 with the same shape as signup **if the phone belongs to an existing user** (this is
the login path). 401 `{"error":"invalid otp"}` for a wrong code, 404
`{"error":"user not found"}` if no account has that phone. 400 for missing/invalid fields.

### POST /auth/signup
```json
{
  "phone": "+919876543210", "name": "Asha", "role": "donor", "blood_group": "O+",
  "lat": 21.1458, "lng": 79.0882,
  "sex": "female", "age": 28, "weight_kg": 58, "height_cm": 163,
  "donated_before": false, "last_donated_at": null, "available": true,
  "consent": true
}
```
`blood_group` is required for requester and donor; omit for bank. `phone` is unique.
`sex` is `male|female|other`; `age`, `weight_kg`, `height_cm`, `donated_before`,
`last_donated_at` and `available` are optional donor profile fields used by the
eligibility checks (see DATA_MODEL.md). `last_donated_at` is an RFC3339 timestamp or
`YYYY-MM-DD`. `consent: true` records `consent_at`; an explicit `false` is rejected.
201:
```json
{ "user":{"id":"u1","phone":"+919876543210","name":"Asha","role":"donor",
           "blood_group":"O+","lat":21.14,"lng":79.08,"sex":"female","age":28,
           "weight_kg":58,"height_cm":163,"donated_before":false,
           "last_donated_at":null,"available":true,"consent_at":"2026-11-22 10:00:00"},
  "token":"<app jwt>", "nexconn_token":"<chat token>" }
```

### POST /auth/login (legacy, deprecated)
```json
{ "name": "Asha", "role": "donor" }
```
200 same shape as signup. 404 if the user does not exist. Kept additive for seed users
and older clients; new clients should use `POST /auth/verify`.

## GET /banks/me/stock  (bank)
200 `{"stock":[{"blood_group":"O+","units":5,"updated_at":"..."}]}`

## PUT /banks/me/stock  (bank)
```json
{ "stock":[{"blood_group":"O+","units":5},{"blood_group":"O-","units":0}] }
```
200 same as GET.

## GET /notifications  (any authenticated role)
Notifications created by the in-process notifier from request events. Newest first.
200 `{"notifications":[{"id":"n1","user_id":"u1","type":"request.created",
  "title":"New blood request","body":"O- needed at City Hospital",
  "request_id":"r1","read_at":null,"created_at":"..."}]}`
An empty inbox returns `{"notifications":[]}`. There is no mark-read endpoint in v1;
the app treats the list as an in-app banner feed.

## POST /requests  (requester)
```json
{ "blood_group":"O-", "units":2, "hospital":"City Hospital", "urgency":"critical",
  "lat":21.15, "lng":79.09 }
```
201:
```json
{ "request":{"id":"r1","blood_group":"O-","units":2,"hospital":"City Hospital",
             "urgency":"critical","status":"open","channel_id":"reqr1","created_at":"..."},
  "matches":{"banks":1,"donors":4} }
```
Publishes `request.created`; matched users get a notification row.

## GET /requests  (role-aware)
Query: `status=open|fulfilled|all` (default open).
- requester: own requests
- donor: open requests whose blood_group equals the donor's and within MATCH_RADIUS_KM
- bank: open requests within MATCH_RADIUS_KM
200 `{"requests":[{ ...request, "distance_km":3.2, "requester_name":"Ravi", "joined":false }]}`

## POST /requests/{id}/accept  (donor|bank)
Adds the caller to the room. 200 `{"channel_id":"reqr1"}`. 409 if request not open.
Publishes `request.accepted`; the requester gets a notification row. A donor accept also
creates a `donations` row for the request.

## POST /requests/{id}/fulfill  (requester who owns it)
Posts a system message, closes the room. 200 `{"request":{...,"status":"fulfilled"}}`.
Publishes `request.fulfilled`; all joined members get a notification row.

## POST /requests/{id}/cancel  (requester)
Same as fulfill but status=cancelled. (Optional; implement only if time.)

## Dev only
`POST /dev/reset` reloads seed data (enabled when `DEV=1`).
