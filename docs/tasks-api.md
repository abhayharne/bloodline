# Overnight tasks: API (OpenCode, folder api/, handoff docs/handoff/api.md)
Order matters. Done = scripts/gate-api.sh passes. Box states: [ ] todo, [x] done, [!] blocked (add "BLOCKED: reason").
Use docs/API-addendum-v2.md as the contract. Nexconn calls go behind the existing internal/nexconn interface.

- [x] A0 Docs first: fold docs/API-addendum-v2.md into docs/API.md, docs/DATA_MODEL.md and api/db/schema.sql (users: phone unique, sex, age, weight_kg, height_cm, donated_before, last_donated_at, available default 1, consent_at; new tables donations and notifications). Record D11 in docs/decisions-api.md (extension architecture: events bus, filter pipeline, Notifier, feature flags). Seed users get phones.
- [x] A1 Phone auth with mock OTP: /auth/otp/send, /auth/verify, /auth/signup per the addendum; replaces the old login. Keep issuing nexconn_token via the real token endpoint, or via the fake when NEXCONN_FAKE=1. Tests.
- [x] A2 NEXCONN_FAKE=1 mode: in-memory fake implementing the nexconn interface (issue token, create group, join, freeze) so everything runs offline. Real mode stays the default.
- [ ] A3 internal/events bus (panic-safe subscribers, tested), Notifier interface writing to the notifications table, GET /config from env FEATURES, GET /notifications, POST /notifications/{id}/read.
- [x] A4 Matching: DonorFilter pipeline, pure Compatible() and Eligible() per the addendum with table-driven tests (all 64 group pairs), tested haversine. Eligible is implemented but only wired in when feature reminders is on.
- [x] A5 POST /requests: validate, store, match (banks with enough compatible stock first, top 2; then donors, top 10), create channel "req"+id with requester as owner and matched banks, save channel_id, publish request.created, return match counts.
- [x] A6 GET /requests role-aware (requester own; donor open+compatible+in range; bank open in range) with distance_km and joined flag.
- [x] A7 POST /requests/{id}/accept: join the channel, idempotent, 409 if not open, publish request.accepted.
- [x] A8 POST /requests/{id}/fulfill (requester only): freeze the channel (freeze-list/add), set status, publish request.fulfilled. In real mode the freeze call is UNVERIFIED: implement it, then add "UNVERIFIED-REAL: freeze" to docs/decisions-api.md for the human to check.
- [ ] A9 scripts/smoke.sh: on a random free port, start the server with NEXCONN_FAKE=1, curl the whole flow (signup requester/donor/bank, bank stock, create request, donor feed, accept, donated, fulfill) and assert HTTP codes and key fields. Must pass with FEATURES= and FEATURES=ranks,reminders. Make it executable.
- [ ] A10 Seed and POST /dev/reset (only when DEV=1): 5 donors, 2 banks with stock, 1 open request, all with phones and alphanumeric ids.
- [ ] A11 GET/PUT /me and POST /requests/{id}/donated with derived eligibility and donation_count; publish donation.recorded.
- [ ] A12 Feature ranks (flag ranks): subscriber on donation.recorded computes rank; /me returns it; rank_up notification using docs/COPY.md.
- [ ] A13 Feature reminders (flag reminders): enable isAvailable and isEligible filters; hourly ticker plus POST /dev/run-reminders (DEV=1) that writes eligible_again notifications using docs/COPY.md, once per eligibility period; match_nearby notifications on request.created.
- [ ] A14 Final pass: README section for running the API, update docs/API.md to match the code exactly, tidy handoff.
