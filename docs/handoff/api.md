# Handoff
**From:** opencode (api, overnight loop, iteration 5)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** this iteration (see `git log -1`)

## Done this iteration
- Gate was PASS at entry. Fixed smoke (rank-aware /me assertion) and gate is PASS now.
- A12 complete (ticked): `ranks` feature behind `FEATURES=ranks`.
- Pure `matching.RankForCount` implements thresholds (1 First Drop, 3 Helper, 5 Silver
  Lifeline, 10 Gold Lifeline, 25 Lifesaver). `GET/PUT /me` fills `derived.rank` only
  when `HasFeature("ranks")`; rank computed on the fly from donation_count (no DB column).
- New `internal/ranks` subscribes to `events.DonationRecorded` when flag enabled
  (wired in `cmd/server/main.go`); emits `rank_up` notification using COPY.md:
  `"{n} donations. You're now a {rank}."` Idempotent: ignores same-rank counts and
  dedupes via `store.HasNotification(userID,"rank_up",body)`.
- Added store `HasNotification`, service `HasFeature`, ranks/matching/store/service/http
  tests, smoke rank assertion when flag on. Decision D20 appended.

## State
- `go build`, `go vet`, `go test -race -count=1 ./...` and smoke (`FEATURES=` and
  `FEATURES=ranks,reminders`) pass via `scripts/gate-api.sh`.
- No fixed ports, no `.env`, no docs/PLAN.md, no `app/` edits. Next unchecked task is A13.

## Next action (A13, first unchecked task)
- Implement `reminders` flag: enable `ByAvailability` and `ByEligibility` filters in
  matching pipeline when flag on (core path stays simple when off). Add hourly ticker
  plus `POST /dev/run-reminders` (DEV=1) that writes `eligible_again` notifications
  using COPY.md once per eligibility period; also `match_nearby` notifications on
  `request.created`. Keep subscribers panic-safe and idempotent.
- Touch only api/ plus docs/handoff/api.md, docs/tasks-api.md, docs/decisions-api.md.
- Then gate, tick A13, append decision, rewrite handoff, commit.

## Gotchas / blockers
- No blockers; no human input needed.
- Duplicate api loops recur (D15/D17/D18): re-read files before writes, keep commits atomic.
- Auth drift (addendum `otp` vs handler `code`) and docs/API.md old v1 shape deferred to A14.
- Smoke step 8 had a hardcoded `rank==null`; now feature-aware. Keep smoke/gate green.
