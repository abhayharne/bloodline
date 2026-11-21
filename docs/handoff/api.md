# Handoff
**From:** opencode (api, overnight loop, iteration 8) **To:** next api session / human **Time:** 2026-11-22
**Branch:** feat/api **Last commit:** see `git log -1`

## Done
- Entry gate PASS. First unchecked task was A14; it is now complete and ticked.
- Rewrote `docs/API.md` as a v2 contract matching the shipped code: phone auth,
  `/me`, notifications (`read` + mark-read), `/donated`, dev routes, feature
  flags, offline modes and exact response shapes. Known code/addendum gaps are
  listed in a "Deviations from addendum v2" section (D27) — no code changed.
- Added a "Running the API" section to root `README.md` (offline `NEXCONN_FAKE=1`
  startup, env knobs, gate/smoke script).
- Recorded D27 (doc-pass scope + duplicate-loop ownership); the peer's D26
  deferral checklist is preserved. Appended-only, no decision was reverted.
- Verification: `scripts/gate-api.sh` PASS — build, vet, `-race -count=1 ./...`,
  smoke with `FEATURES=` and `FEATURES=ranks,reminders`.

## State
- All tasks A0–A14 in `docs/tasks-api.md` are `[x]`; there is no unchecked API task.
- This session's work: `README.md`, `docs/API.md`, `docs/tasks-api.md`,
  `docs/decisions-api.md`, this handoff. Committed with explicit pathspecs; no
  uncommitted work left.
- No code edits this iteration, no `.env`, no docs/PLAN.md, no `app/`, no fixed
  ports, no pushes, no sudo.

## Next action
- None in the task list — the API scope is complete. A human should review the
  deviations in D27/D26 and decide whether to reconcile the auth wire to addendum
  v2 (`code`->`otp`, `is_new`, `demo`, donor consent) in a follow-up task.
- A human must stop one of the two duplicate `scripts/loop.sh opencode api ...`
  processes (loop.sh 126314 and 127627); agents cannot do this from a session.

## Blockers
- None for A14. The duplicate api loops (D15/D17/D18/D22/D24/D26/D27) remain an
  operational hazard; until a human stops one, re-read before writes, commit
  with explicit paths and never revert peer work.
