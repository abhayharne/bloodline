# API v2 design reference

This document records the v2 API design. See [API.md](API.md) for the implemented
contract and known deviations from this reference. All IDs are alphanumeric
(no `_` or `-`). Clients must ignore unknown JSON fields.

## Auth (replaces /auth/signup and /auth/login from API.md)
Demo OTP: env `DEMO_OTP` (default `123456`). Any phone number is accepted. Responses include `"demo":true`.
- `POST /auth/otp/send` `{"phone":"+919999900001"}` -> 200 `{"sent":true,"demo":true}`
- `POST /auth/verify` `{"phone","otp"}` -> existing user: 200 `{"is_new":false,"user":{...},"token","nexconn_token"}`; unknown phone: 200 `{"is_new":true}`; wrong otp: 401
- `POST /auth/signup` `{"phone","otp","name","role","blood_group?","sex?" (male|female),"age?","weight_kg?","height_cm?","donated_before?","last_donated_at?" (RFC3339 date),"lat?","lng?","consent":true}` -> 201 `{"user","token","nexconn_token"}`. `consent` must be true for donors. Roles: requester|donor|bank.

## Profile
- `GET /me` -> `{"user":{...profile...},"derived":{"eligible":bool,"next_eligible_at":null|date,"donation_count":int,"rank":null|{"key","label"}}}` (`rank` is null unless feature `ranks` is on)
- `PUT /me` `{"available?","lat?","lng?","weight_kg?","height_cm?","last_donated_at?"}` -> same shape as GET /me

## Config and notifications
- `GET /config` -> `{"features":["ranks","reminders"],"demo_mode":true}` (from env `FEATURES`, comma separated, empty by default)
- `GET /notifications` -> `{"notifications":[{"id","type","title","body","created_at","read":bool}]}` newest first
- `POST /notifications/{id}/read` -> 204

## Donations
- `POST /requests/{id}/donated` (donor who joined the room) -> 201 `{"donation":{"id","request_id","donated_at"},"donation_count":int}`. Idempotent per (donor, request). Publishes event `donation.recorded`.

## Rules (pure functions, unit tested)
- Compatible(patient, donor) red-cell table: O-<-O-; O+<-O+,O-; A-<-A-,O-; A+<-A+,A-,O+,O-; B-<-B-,O-; B+<-B+,B-,O+,O-; AB-<-AB-,A-,B-,O-; AB+<- all 8. Rank exact-group donors first.
- Eligible(donor, now): age 18..65, weight_kg >= 45, available, and now >= last_donated_at + 90 days (male) / 120 days (female). Unknown values count as eligible (permissive), except an explicit available=false.
- Ranks by donation_count: 1 "First Drop", 3 "Helper", 5 "Silver Lifeline", 10 "Gold Lifeline", 25 "Lifesaver".
- Core matching filters: compatible group + within MATCH_RADIUS_KM. Filters `isAvailable` and `isEligible` are enabled only when feature `reminders` is on (so the core demo path stays simple).

## Events (in-process bus, subscribers must never break a request)
`user.signed_up`, `request.created`, `request.accepted`, `request.fulfilled`, `donation.recorded`.
Features subscribe; the core never imports feature code.
