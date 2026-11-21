# API Contract (v1)

Base: `http://<host>:8080`. JSON. Auth: `Authorization: Bearer <jwt>` except /health and /auth/*.
Errors: `{"error":"message"}` with status 400/401/403/404/409/500.
Change this doc FIRST, then the code.

## GET /health
200 `{"status":"ok"}`

## POST /auth/signup
```json
{ "name":"Asha", "role":"donor", "blood_group":"O+", "lat":21.1458, "lng":79.0882 }
```
`blood_group` required for requester and donor; omit for bank. 201:
```json
{ "user":{"id":"u_1","name":"Asha","role":"donor","blood_group":"O+","lat":21.14,"lng":79.08},
  "token":"<app jwt>", "nexconn_token":"<chat token>" }
```

## POST /auth/login
```json
{ "name":"Asha", "role":"donor" }
```
200 same shape as signup. 404 if the user does not exist.

## GET /banks/me/stock  (bank)
200 `{"stock":[{"blood_group":"O+","units":5,"updated_at":"..."}]}`

## PUT /banks/me/stock  (bank)
```json
{ "stock":[{"blood_group":"O+","units":5},{"blood_group":"O-","units":0}] }
```
200 same as GET.

## POST /requests  (requester)
```json
{ "blood_group":"O-", "units":2, "hospital":"City Hospital", "urgency":"critical",
  "lat":21.15, "lng":79.09 }
```
201:
```json
{ "request":{"id":"r_1","blood_group":"O-","units":2,"hospital":"City Hospital",
             "urgency":"critical","status":"open","channel_id":"ch_abc","created_at":"..."},
  "matches":{"banks":1,"donors":4} }
```

## GET /requests  (role-aware)
Query: `status=open|fulfilled|all` (default open).
- requester: own requests
- donor: open requests whose blood_group equals the donor's and within MATCH_RADIUS_KM
- bank: open requests within MATCH_RADIUS_KM
200 `{"requests":[{ ...request, "distance_km":3.2, "requester_name":"Ravi", "joined":false }]}`

## POST /requests/{id}/accept  (donor|bank)
Adds the caller to the room. 200 `{"channel_id":"ch_abc"}`. 409 if request not open.

## POST /requests/{id}/fulfill  (requester who owns it)
Posts system message, closes room. 200 `{"request":{...,"status":"fulfilled"}}`.

## POST /requests/{id}/cancel  (requester)
Same as fulfill but status=cancelled. (Optional; implement only if time.)

## Dev only
`POST /dev/reset` reloads seed data (enabled when `DEV=1`).
