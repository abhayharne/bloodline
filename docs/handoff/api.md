# Handoff
**From:** opencode (api, overnight loop, iteration 6, pts/4)  **To:** next api session  **Time:** 2026-11-22
**Branch:** feat/api  **Last commit:** see `git log -1`

## Done this iteration
- Re-ran `scripts/gate-api.sh` on committed HEAD: PASS (all packages, both smoke modes).
- No A<N> code owned this iteration. Both api loops now name iteration 6: pts/6
  (gate-FAIL prompt, started 03:47) and pts/4 (this session, gate-PASS, started 03:52).
  The pts/6 loop already owns A13 per the handoff and D22, and had uncommitted A13
  work in `api/internal/store/notifications.go` when checked. Per D15/D22 and the
  refined equal-iteration tie-break in D23, deferred A13 to it rather than race on
  the same files. Did not touch api/ code or the peer's uncommitted work.

## State
- HEAD: `e524d9f` (iteration 5 deferral + D22); before it `3d17bce` (D21 rowid
  newest-first ordering fix). Working tree had a peer's uncommitted A13 edit to
  `api/internal/store/notifications.go` at check time — do not mistake it for ours.
- A13 is still the first unchecked task; A14 follows. No task box was changed.
- Only docs/decisions-api.md (appended D23) and this handoff were edited by us,
  committed with explicit pathspec. No fixed ports, no `.env`, no docs/PLAN.md,
  no `app/` edits, no pushes.

## Next action
- Let the in-flight pts/6 loop finish A13: `ByAvailability`/`ByEligibility` under
  `reminders`, hourly ticker + `POST /dev/run-reminders` (DEV=1) writing once-per-
  eligibility-period `eligible_again` per COPY.md, `match_nearby` on
  `request.created`, panic-safe/idempotent subscribers; then gate, tick A13, D24,
  handoff, commit. Verify its commit + task box before starting a new A<N>.
- After A13: A14 (README API run section, reconcile docs/API.md with code, tidy handoff).
- Two api loops are still running on this tree. A human must stop one
  `scripts/loop.sh opencode api ...` process. Until then re-read files before every
  write, commit atomically with explicit paths, and never revert peer work (D22/D23).

## Blockers
- None for the API code itself. The duplicate-loop process issue needs a human to
  stop one `scripts/loop.sh opencode api` process (out of scope for an iteration).
