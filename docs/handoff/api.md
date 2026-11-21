# Handoff
**From:** opencode (api, overnight loop, iteration 7, gate-PASS deferral) **To:** iteration 8 api loop (pts/4) **Time:** 2026-11-22 04:01
**Branch:** feat/api **Last commit:** see `git log -1`

## Done
- Entry gate `scripts/gate-api.sh` re-run at the start of this iteration: PASS
  (build, vet, `-race -count=1 ./...`, smoke with `FEATURES=` and
  `FEATURES=ranks,reminders`).
- Owned no task letter: A14 deferred to the higher-numbered iteration-8 loop
  (pts/4) under D22. At the 04:00 check the tree was clean and no loop was
  mid-edit, so D24's exception did not apply; by 04:01 the sibling was indeed
  editing `README.md`, `docs/API.md` and `docs/tasks-api.md`. Recorded D26 with
  a verified doc/code mismatch checklist for the owning loop.
- Did not touch `api/`, `docs/API.md` or `README.md`; A14 box left for the owner.
  Only this handoff and `docs/decisions-api.md` were edited by this session.

## State
- HEAD unchanged by this session's commit except the two docs above; the
  sibling's in-flight A14 work was left alone and never staged. Re-read before
  any further write.
- A14 (`- [ ]`) is the first and only unchecked task and belongs to iteration 8.
  No `.env`, no docs/PLAN.md, no `app/`, no fixed ports, no pushes.

## Next action (A14 — owned by the iteration-8 loop, pts/4)
- Finish the README "Running the API" block and reconcile `docs/API.md` with the
  shipped handlers; D26 lists every verified gap (`otp` vs `code`, no `is_new`,
  `/me`, `/donated`, `read` flag + mark-read, `demo_mode`, `/dev/run-reminders`,
  `DEV=1`, `NEXCONN_FAKE=1`, unimplemented cancel).
- Gate `scripts/gate-api.sh`, tick A14, append a decision, rewrite this handoff,
  commit with explicit pathspecs.

## Blockers
- Two `scripts/loop.sh opencode api ...` processes still share this working tree
  (D15/D17/D18/D22/D23/D24/D26). A human must stop one. Until then re-read
  before writes, commit atomically with explicit paths, never revert peer work.
