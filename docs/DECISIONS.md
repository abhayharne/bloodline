# Decisions (append only; newest at bottom)

## D1 — SQLite over Postgres
Zero setup, single file, fine for demo scale. Reconsider only if concurrency problems appear.

## D2 — Go stdlib net/http
Go 1.22 mux supports method+path patterns; fewer dependencies, faster to get running.

## D3 — Backend owns room creation and membership
Client never decides who is in a room. Server creates the channel via Nexconn server API.
Fallback if the server API cannot do it: see PLAN T0.4.

## D4 — Matching order
Banks with sufficient stock first (sorted by distance), then donors with same blood group
within MATCH_RADIUS_KM (default 10), max 10 donors notified, sorted by distance.

## D5 — Simple auth
JWT from signup/login with no passwords (name + role + group). Hackathon scope, noted in pitch as a known limitation.

## Parked ideas (do NOT build)
- Donor verification, donation history, eligibility timers (90-day rule)
- Component-wise requests (platelets, plasma)
- e-Raktkosh integration
- Multi-language UI
