# Handoff
**From:** opencode  **To:** antigravity  **Time:** 2026-11-22 02:10 IST
**Branch:** feat/api  **Last commit:** 5c8ff41

## Current task
P1 backend is now complete for the frozen demo scope: T1.1-T1.7 + T1.9 + T1.10-T1.12 done.
T1.8 (seed loader) is still open and optional. P2 app now has a stable phone-auth contract.

## Done this session (docs first, then code; commits 4a25df3..5c8ff41)
- Docs: API.md, DATA_MODEL.md, D11/D12 in DECISIONS.md, schema.sql, .env.example.
- T1.2 reworked to phone auth: `POST /auth/otp/send`, `POST /auth/verify`,
  `POST /auth/signup` with phone/profile/consent. Mock OTP from `DEMO_OTP` (default 123456),
  never returned or logged. Legacy `POST /auth/login` kept for seed/older clients.
- `GET /config` (public): `{"features":[...]}` from `FEATURES` env, empty by default.
- D11: `internal/events` bus (panic-safe, synchronous), `internal/notify` writing
  `notifications`, `GET /notifications` (JWT), `DonorFilter` pipeline with pure
  `Compatible`/`Eligible` (age 18-65, >=45 kg, 90d male / 120d female). Eligibility is
  tested but NOT wired into live matching; D4's exact-group rule remains live.
- T1.4-T1.7: `POST /requests`, `GET /requests` (role-aware), accept, fulfill
  (system message + channel freeze). Events `request.created/accepted/fulfilled` published.
- `scripts/smoke.sh`: signup -> request -> accept -> fulfill. Verified against a local
  server with `NEXCONN_MOCK=1` (dev-only no-op chat, see D12).

## State of the code
- `cd api && go build ./...`, `go test ./...`, `go test -race ./...` all pass.
- Run: `cd api && go run ./cmd/server` (loads nearest .env; :8080).
- DB schema auto-applies with idempotent ALTER migrations for older DBs.
- All ids alphanumeric; `channel_id = "req" + request id`.

## Next action
- antigravity: T2.2 must use phone OTP signup/verify. Signup body now:
  `{"phone":"+919876543210","name":"Asha","role":"donor","blood_group":"O+","lat":..,"lng":..,"sex":..,"age":..,"weight_kg":..,"height_cm":..,"donated_before":false,"last_donated_at":null,"available":true,"consent":true}`.
  Then call `POST /auth/otp/send`, `POST /auth/verify` with `DEMO_OTP` (demo code 123456).
  Response still has `user`, `token`, `nexconn_token`; `user` now includes profile fields.
  T2.9 can poll `GET /notifications` (JWT) instead of/in addition to `GET /requests`.
  `GET /config` is public and returns feature flags (empty by default).
- opencode (next session): T1.8 seed loader, or help AG integrate the new auth contract.

## Gotchas
- Bank needs `PUT /banks/me/stock` before it appears in `matches.banks`; top 2 banks by distance.
- Donors are exact blood-group matches within MATCH_RADIUS_KM (default 10), top 10 by distance.
- Never log tokens, OTPs or Nexconn secrets; SDK debug stays off.
- `app/` is antigravity's; never `git add -A` or stage it.
- NEXCONN_MOCK=1 is dev-only and not a GET /config feature flag.

## Open questions
- Confirm the app's OTP UX: auto-fill 123456 for the demo or let the human type it?
- Seed loader (T1.8) still needed for the one-tap demo reset (T4.1)?

## Do NOT touch
- `app/` and docs/DEMO_SCRIPT.md, docs/PITCH.md (antigravity).
- docs/AGENTS.md; DECISIONS.md is append-only.
