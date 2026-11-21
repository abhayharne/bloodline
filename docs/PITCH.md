# Pitch Outline (5-7 slides)

1. **Problem** — "Humanitarian & Social Good: volunteer dispatch for blood emergencies."
2. **Who suffers** — patients' families, blood banks (inventory they can't surface), donors (alert fatigue).
3. **Solution** — one request = one live chat room; banks first, then matched donors; closes when fulfilled.
4. **Demo** — live (see DEMO_SCRIPT.md).
5. **Why Nexconn chat** — rooms, history, media, location pins, delivery guarantees out of the box; we built the whole product in a day on top of Chat UI.
6. **Impact and roadmap** — metrics to track (time-to-first-donor, fulfilment rate), donor verification, compatibility matching, e-Raktkosh integration, push.
7. **Ask/close.**

## Likely judge questions
- *Why not just use blood banks?* We don't replace them; we connect banks, replacement donors and families in real time and surface bank stock.
- *Isn't there e-Raktkosh?* It is an inventory portal; we address last-mile coordination and replacement donors. Integration is on the roadmap.
- *Trust/fraud?* Demo uses simple auth. Roadmap: phone OTP, donor verification via banks, abuse reporting, room moderation.
- *Privacy?* Share only what's needed; exact locations only inside the room; data minimisation planned.
- *Business model?* Free for citizens; B2B for blood banks/hospital networks, CSR sponsorship.
- *Scale?* Chat infra handled by Nexconn; matching is geospatial query, easily moved to Postgres/PostGIS.
