# Data Model

See `api/db/schema.sql` for DDL. Fresh databases get the DDL as written; existing
databases receive idempotent `ALTER TABLE ... ADD COLUMN` migrations on boot so the
columns below are always present. Tables whose primary key changed
(`requests` for urgency, `bank_stock` for component) are rebuilt in one
transaction instead, preserving every row.

## Tables
- `users(id, name, role, blood_group, lat, lng, push_token, created_at)`; role in requester|donor|bank; bank users use `name` as bank name; `created_at` is RFC3339 UTC `Z` and is exposed on `user` responses (including `/me`)
  - phone auth / donor profile additions: `phone` (TEXT UNIQUE), `sex` (`male|female|other`),
    `age` (integer years), `weight_kg` (real), `height_cm` (real),
    `donated_before` (integer 0/1, default 0), `last_donated_at` (TEXT, nullable),
    `available` (integer 0/1, default 1), `consent_at` (TEXT, nullable),
    `apheresis_ok` (integer 0/1, default 0, settable via `PUT /me`).
    `consent_at` is set when signup sends `consent: true`; an explicit `false` is rejected.
- `bank_stock(bank_id, blood_group, component, units, updated_at)` PK(bank_id, blood_group, component);
  `component` defaults to `whole_blood`, one of `whole_blood|red_cells|platelets|plasma|cryo|other`.
  Old rows are migrated with `whole_blood`; the old PK(bank_id, blood_group) table is rebuilt.
- `requests(id, requester_id, blood_group, units, hospital, urgency, lat, lng, status, channel_id, created_at, fulfilled_at, component, notes)`; status in open|fulfilled|cancelled; urgency in low|medium|high|critical (see aliases below); `component` defaults to `whole_blood`; `notes` is nullable text (<= 500 chars); `created_at` is RFC3339 UTC `Z`
- Hospital directory is **not** a SQL table: `api/data/hospitals.json` is embedded
  with `go:embed` and served by `GET /hospitals`. Each entry has an alphanumeric
  `id`, `name`, `area`, `lat`, `lng`; `POST /requests.hospital_id` resolves one
  into the request's `hospital`/`lat`/`lng`.
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

## Matching (component-aware live path)
```
groups = [request.blood_group]                      for whole_blood/red_cells/other
groups = compatible groups for the component        for plasma/cryo/platelets
banks  = bank users with stock[group, component] >= units, ordered by
         distance, top 2 distinct banks
donors = donor users with blood_group in groups and distance <= MATCH_RADIUS_KM,
         apheresis_ok = 1 for platelets/plasma/cryo,
         ordered by (component rank, then distance), top 10
distance = haversine(request.lat,lng ; user.lat,lng) in km
```
Compatibility is component-aware (`CompatibleForComponent` in `internal/matching`):
red cells use the red-cell ABO/Rh chart in the helper and exact groups in live
matching. Whole blood and other use exact groups. Plasma and
cryo use reverse ABO with Rh ignored; platelets prefer same ABO and put
Rh-negative donors first for Rh-negative patients (ranked, not excluded). All
rules are table-driven tested. The donor feed (`GET /requests`) applies the same
component rule so a plasma request is only visible to donors who can supply it.
Donor eligibility (`Eligible(donor, now)`, D11) is enabled in matching only when
the `reminders` feature is on; the pure filter pipeline stays available for
feature code.

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
