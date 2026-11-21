# Handoff
**From:** opencode (api, overnight loop, iteration 5)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** this iteration (see `git log -1`)

## Done this iteration
- Entry gate PASS; exit gate PASS (both `FEATURES=` and `FEATURES=ranks,reminders` smoke modes).
- No A<N> code owned this iteration: a duplicate iteration-6 api loop was already
  in-flight on A13 (D15/D17/D18 recurrence). Per the D15 precedent, deferred A13
  to it instead of racing on the same files. Recorded the recurrence and a
  deterministic tie-break rule in D22.

## State
- HEAD includes the sibling's `3d17bce`: notifications and requests now sort by
  `created_at DESC, rowid DESC`, so tied timestamps stay truly newest-first (D21).
- A12 (ranks) remains complete; the first unchecked task is still A13.
- No fixed ports, no `.env`, no docs/PLAN.md, no `app/` edits, no pushes.

## Next action
- A13 (owned by the higher-numbered in-flight loop at the time of writing): wire
  `ByAvailability`/`ByEligibility` under `reminders`; hourly ticker plus
  `POST /dev/run-reminders` (DEV=1) writing once-per-eligibility-period
  `eligible_again` per COPY.md; `match_nearby` on `request.created`. Keep
  subscribers panic-safe and idempotent, then gate, tick A13, decision, handoff,
  commit.
- After that: A14 (README API run section, reconcile docs/API.md with code, tidy handoff).
- Two api loops are still running on this tree. Until a human stops the extra one,
  re-read files before every write, commit atomically, never revert peer work (D22).

## Blockers
- None for the API code itself. The duplicate-loop process issue needs a human to
  stop one `scripts/loop.sh opencode api` process (out of scope for an iteration).
