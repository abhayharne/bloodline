# Data Model

See `api/db/schema.sql` for DDL. Fresh databases get the DDL as written; existing
databases receive idempotent `ALTER TABLE ... ADD COLUMN` migrations on boot so the
columns below are always present.

## Tables
- `users(id, name, role, blood_group, lat, lng, push_token, created_at)`; role in requester|donor|bank; bank users use `name` as bank name; `created_at` is RFC3339 UTC `Z` and is exposed on `user` responses (including `/me`)
  - phone auth / donor profile additions: `phone` (TEXT UNIQUE), `sex` (`male|female|other`),
    `age` (integer years), `weight_kg` (real), `height_cm` (real),
    `donated_before` (integer 0/1, default 0), `last_donated_at` (TEXT, nullable),
    `available` (integer 0/1, default 1), `consent_at` (TEXT, nullable).
    `consent_at` is set when signup sends `consent: true`; an explicit `false` is rejected.
- `bank_stock(bank_id, blood_group, units, updated_at)` PK(bank_id, blood_group)
- `requests(id, requester_id, blood_group, units, hospital, urgency, lat, lng, status, channel_id, created_at, fulfilled_at)`; status in open|fulfilled|cancelled; urgency in low|medium|high|critical (see aliases below); `created_at` is RFC3339 UTC `Z`
- `request_members(request_id, user_id, role, joined_at)` PK(request_id, user_id)
- `donations(id, request_id, donor_id, units, created_at)` — one pledged donation per
  (request, donor); written when a donor accepts. `units` defaults to the request's units.
- `notifications(id, user_id, type, title, body, request_id, read_at, created_at)` —
  in-app notification feed written by the Notifier (D11). Types: `request.created`,
  `request.accepted`, `request.fulfilled`. `created_at` is RFC3339 UTC `Z`.
  No push token is required.

## Timestamps and urgency

New rows write `created_at` as RFC3339 UTC with a trailing `Z`
(`YYYY-MM-DDTHH:MM:SSZ`). Existing SQLite `datetime('now')` values use a space
instead of `T`; every read normalises them to RFC3339 UTC, and a missing or
unparseable legacy value is reported as `1970-01-01T00:00:00Z` so JSON fields are
never empty. `donated_at` is the donation's `created_at` in the same format.

Canonical urgency values are `low`, `medium`, `high`, `critical`. The API
normalises the legacy aliases `planned`→`low`, `med`→`medium`, `urgent`→`high`
before insert. On boot, an older `requests` table is rebuilt so its CHECK
constraint accepts only the canonical values and its existing rows are mapped
through those aliases; `GET /requests` then sorts by urgency priority
(critical → high → medium → low), then `created_at DESC`, then insertion order.

## ID conventions
All ids are alphanumeric only (A-Z, a-z, 0-9; no `_` or `-`) because Nexconn channel ids
reject other characters.
- `users.id`: `u` + random hex (seed: `ureq1`, `udon1`, `ubank1`)
- `requests.id`: `r` + random hex (seed: `r1`)
- `notifications.id`: `n` + random hex; `donations.id`: `d` + random hex
- `requests.channel_id`: `"req" + request id` (request `r1` -> channel `reqr1`)

## Blood groups
A+, A-, B+, B-, AB+, AB-, O+, O-

## Matching (v1 live path: exact group, no compatibility chart)
```
banks  = bank users with stock[group] >= units, ordered by distance, top 2
donors = donor users with blood_group == group and distance <= MATCH_RADIUS_KM,
          ordered by distance, top 10
distance = haversine(request.lat,lng ; user.lat,lng) in km
```
Compatibility (`Compatible(patientGroup, donorGroup)`) and donor eligibility
(`Eligible(donor, now)`) are implemented and unit-tested in `internal/matching` (D11),
but are **not wired into the live feed yet** — the demo uses the exact-group rule above.
Roadmap: enable the full `DonorFilter` pipeline behind a `FEATURES` flag.

### Eligibility rules (tested, not live)
- age must be 18..65 inclusive
- weight must be >= 45 kg
- interval since `last_donated_at`: >= 90 days for male donors, >= 120 days for female
  donors (and for `other`/unspecified, conservatively)
- a donor with `donated_before = false` and no `last_donated_at` is eligible on age/weight
- `available = false` excludes a donor from matching

## Request lifecycle
open -> fulfilled (by requester) | cancelled (by requester)
Room stays readable after close; no new messages from users.
Events published (D11): `request.created`, `request.accepted`, `request.fulfilled`.
