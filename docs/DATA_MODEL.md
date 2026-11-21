# Data Model

See `api/db/schema.sql` for DDL.

## Tables
- `users(id, name, role, blood_group, lat, lng, push_token, created_at)`; role in requester|donor|bank; bank users use `name` as bank name
- `bank_stock(bank_id, blood_group, units, updated_at)` PK(bank_id, blood_group)
- `requests(id, requester_id, blood_group, units, hospital, urgency, lat, lng, status, channel_id, created_at, fulfilled_at)`; status in open|fulfilled|cancelled; urgency in critical|urgent|planned
- `request_members(request_id, user_id, role, joined_at)` PK(request_id, user_id)

## Blood groups
A+, A-, B+, B-, AB+, AB-, O+, O-

## Matching (v1: exact group, no compatibility chart)
```
banks  = bank users with stock[group] >= units, ordered by distance, top 2
donors = donor users with blood_group == group and distance <= MATCH_RADIUS_KM,
         ordered by distance, top 10
distance = haversine(request.lat,lng ; user.lat,lng) in km
```
Compatibility (e.g. O- can donate to anyone) is a parked improvement; mention in pitch as roadmap.

## Request lifecycle
open -> fulfilled (by requester) | cancelled (by requester)
Room stays readable after close; no new messages from users.
