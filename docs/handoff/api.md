# Handoff
**From:** opencode (api, overnight loop, iteration 4)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** this iteration (see `git log -1`)

## Done this iteration
- Gate was PASS at entry and PASS after the change (`bash scripts/gate-api.sh`).
- A11 complete (first unchecked task; now ticked): `GET`/`PUT /me` and
  `POST /requests/{id}/donated` per addendum v2.
- `derived` = `{eligible, next_eligible_at, donation_count, rank}`; rank is typed
  (`{key,label}`) but null until A12. `next_eligible_at` is `YYYY-MM-DD` or null.
- PUT /me applies only the six addendum fields, validates ranges/date, and lets an
  empty `last_donated_at` clear the column. Pointers mean "unchanged".
- /donated is donor-only and membership-scoped (403 otherwise, 404 unknown request);
  it reuses the A8 accept row, is idempotent per (request, donor), and publishes
  `donation.recorded` on every successful call (documented in D19).
- Added `DonationRecordedPayload`, `matching.NextEligibleAt`, store
  `DonationFor`/`DonationCount`/`UpdateProfile`, unit + HTTP tests, smoke HTTP
  assertions (A9's SQLite row check kept), and decision D19.

## State
- `go build`, `go vet`, `go test -race -count=1 ./...` and both smoke variants pass.
- No fixed ports, no `.env`, no docs/PLAN.md, no `app/` edits. Next unchecked task is A12.

## Next action (A12, first unchecked task)
- Implement feature `ranks`: subscribe to `events.DonationRecorded`, compute rank
  from `donation_count` (1 First Drop, 3 Helper, 5 Silver Lifeline, 10 Gold Lifeline,
  25 Lifesaver — addendum v2 line 26), fill `service.DerivedProfile.Rank` only when
  the flag is on, and emit a rank_up notification using COPY.md:
  `"{n} donations. You're now a {rank}."`
- `Service.Features()` is currently the only flag accessor (no `HasFeature` helper);
  compute rank on the fly from donation_count unless persistence is really needed,
  and record the choice in docs/decisions-api.md.
- Then gate, tick A12, append decision, rewrite this file, commit.

## Gotchas / blockers
- No blockers; no human input needed (no device, credentials or fixed port).
- Duplicate api loops recur (D15/D17/D18): re-read files before each write,
  keep commits atomic, dedupe rather than revert a peer's version.
- Auth drift (addendum `otp` vs handler `code`) and docs/API.md's old v1 shape are
  deferred to A14; overnight rule 5 forbids editing docs/API.md in this iteration.
- `NEXCONN_FAKE` / `NEXCONN_MOCK` are dev env switches, not `GET /config` flags.
