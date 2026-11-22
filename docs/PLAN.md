# Plan

Legend: `[ ]` todo, `[~]` in progress, `[x]` done. Owner: OC = opencode, AG = antigravity.
Update this file as you start/finish tasks. Each task should take 30-90 min.

## Scope (FROZEN)
In: 3 roles (requester, donor, blood bank), blood request with group/units/hospital/urgency,
bank stock dashboard, matching (bank stock first, then donors by group + distance),
one group chat room per request, accept to join, location pin, mark fulfilled closes room.
Out of scope: payments, admin panel, ML, real verification, maps beyond a location pin,
iOS polish, multi-language, ratings, scheduling donation appointments.
Stretch only if all else is done: AI summary pinned in room; push notifications (fallback: in-app banner).

## Timeline (14h build day)
| Hours | Phase | Goal |
|---|---|---|
| 0-1 | P0 Spikes | Two phones chat; server can create a room + add members |
| 1-5 | P1 Backend | Full API on seed data (OC) |
| 1-7 | P2 App | All screens against API (AG), in parallel with P1 using mock responses until API is ready |
| 7-10 | P3 Integrate | End-to-end happy path on two phones |
| 10-12 | P4 Polish | Notifications/banners, empty states, seed data, bug bash |
| 12-14 | P5 Ship | Demo rehearsal x3, backup video, pitch deck |

## P0 — Spikes (do first, blocks everything)
- [x] T0.1 (human) Create Nexconn project (BloodLine, Singapore), get app key/secret into `.env`  <- verify .env filled
- [x] T0.2 (AG) Minimal Flutter app: init SDK, connect as user A and B on two devices, exchange messages. DONE WHEN: message sent on device 1 appears on device 2.
- [x] T0.3 (OC) Go spike (base URL https://api.sg-light-api.com, see DECISIONS D6/D7; first call to prove signing: POST /v4/auth/access-token/issue): with Nexconn server API, (a) mint a user token, (b) create a group channel, (c) add members. Record exact calls in DECISIONS.md. DONE WHEN: a curl-triggered Go call creates a room visible in the app. (SIGNED OFF 2026-11-21; see D8. Spike code removed.)
- [x] T0.4 FALLBACK DECISION: NOT NEEDED — T0.3 succeeded, so client-side room creation fallback is not used.

## P1 — Backend (OC)
- [x] T1.1 Project init: go.mod, config from env, SQLite open + run db/schema.sql on boot, `/health`
- [x] T1.2 Phone auth: `POST /auth/otp/send`, `POST /auth/verify`, `POST /auth/signup` (phone, profile, consent) -> app JWT + Nexconn token; legacy `POST /auth/login` kept additive
- [x] T1.3 `PUT /banks/me/stock` and `GET /banks/me/stock`
- [x] T1.4 `POST /requests`: create, run matching, create Nexconn room, add requester + top banks, return request + channel_id + matched counts
- [x] T1.5 `GET /requests` (role-aware feed: requester sees own; donor sees open matches; bank sees open requests in range)
- [x] T1.6 `POST /requests/{id}/accept` (donor or bank joins room)
- [x] T1.7 `POST /requests/{id}/fulfill` (requester only): post system message, close/disable room, status=fulfilled
- [ ] T1.8 `db/seed.sql` loaded by `scripts` or boot flag: 5 donors, 2 banks with stock, 1 open request
- [x] T1.9 Tests for matching (distance, group, stock), handlers happy paths
- [x] T1.12 scripts/smoke.sh: signup -> request -> accept -> fulfill (NEXCONN_MOCK=1 for offline runs)
- [x] T1.10 (D11 extension base) events bus with panic-safe subscribers, Notifier -> notifications, GET /notifications
- [x] T1.11 (D11 extension base) DonorFilter pipeline + pure Compatible/Eligible with tests (not wired into live matching)
- [x] T1.13 (D29 human task) Embedded hospital lookup, request components/notes, component-aware matching, apheresis_ok, specific 400 errors, requester-feed regression test

## P2 — App (AG)
- [x] T2.1 `flutter create`, add deps, theme, routing, API client with base URL setting
- [x] T2.2 Signup/login with role picker, blood group, location (device GPS or manual lat/lng fallback)
- [x] T2.3 Requester: new request form (group, units, hospital, urgency) + "My requests" list
- [x] T2.4 Donor: feed of matching open requests + "I can help" (calls accept, opens chat)
- [x] T2.5 Bank: stock editor (8 groups) + open requests list + open chat
- [x] T2.6 Chat: wire `ChannelPage` (inbox) and `ChatPage` with custom header showing request summary chip (group, units, hospital, status)
- [x] T2.7 Location pin message in chat (send current location / hospital location)
- [x] T2.8 Fulfill button for requester; closed rooms show read-only banner
- [x] T2.9 Notification: in-app banner when new matching request arrives (poll `GET /requests` every 10s as fallback; push if time)
- [x] T2.10 Verify and repair live profile, registration, broadcast and donation flows with Go-backed Dart and widget tests

## P3 — Integration
- [ ] T3.1 Run API on laptop, phones on same Wi-Fi (or tunnel), full flow on 2 phones
- [ ] T3.2 Fix contract mismatches; update docs/API.md if contract changed

## P4 — Polish
- [ ] T4.1 Seed demo data, one-tap "reset demo" script
- [ ] T4.2 Empty/error/loading states, app icon, name, splash
- [ ] T4.3 Bug bash against docs/DEMO_SCRIPT.md
- [x] T4.3a (human) Review and fix confirmed API and Flutter defects
- [ ] T4.4 (stretch) AI summary pinned in room

## P5 — Ship
- [ ] T5.1 Rehearse demo x3 with a timer
- [ ] T5.2 Record backup demo video
- [ ] T5.3 Finish deck per docs/PITCH.md
- [ ] T5.4 README screenshots, repo cleanup

## Risks and mitigations
| Risk | Mitigation |
|---|---|
| Server SDK cannot create rooms/add members | T0.3 spike first; fallback T0.4 |
| Push setup eats hours | In-app banner + polling for demo |
| Phones cannot reach laptop API | Same Wi-Fi hotspot, or ngrok/cloudflared tunnel; keep a hosted fallback |
| Scope creep | Scope frozen above; extra ideas go in DECISIONS.md "parked" |
| Agent context loss | /handoff and /resume every switch; commit often |
| Demo fails live | Backup video; seed data; rehearsed script |
