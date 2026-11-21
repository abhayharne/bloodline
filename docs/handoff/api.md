# Handoff
**From:** opencode (api, overnight loop, iteration 6, gate-FAIL loop) **To:** next api session **Time:** 2026-11-22
**Branch:** feat/api **Last commit:** see `git log -1`

## Done
- Entry gate FAILED: `ranks.TestHandleEmitsRankUpOncePerThreshold` ordered two
  same-second notifications by random IDs. Fixed with SQLite `rowid` as the
  newest-first tiebreaker in `Store.Notifications` and `Store.Requests` (D21).
- A13 complete and ticked. Store: `Donors`, `DonorsByGroupAll`,
  `HasNotificationForRequest`, `HasNotificationSince` + tests (D25).
- Service: `CreateRequest` applies `ByAvailability` + `ByEligibility` only when
  `reminders` is on; core path unchanged. Permissive age/weight defaults.
- New `internal/reminders`: `match_nearby` on `request.created` (donors only,
  COPY.md body, per-request dedupe) and `RunEligibilityChecks` writing
  `eligible_again` once per donation cycle using COPY.md. `RunTicker` supports
  the hourly schedule; both entry points are idempotent and log generically.
- HTTP: `POST /dev/run-reminders` (DEV=1, unauthenticated, returns `sent` count)
  via a `ReminderRunner` interface so httpapi never imports feature code.
  `main.go` subscribes the handler and starts the ticker only when flagged.
- Verification: `scripts/gate-api.sh` run locally — PASS (build, vet,
  `-race -count=1 ./...`, smoke with `FEATURES=` and `FEATURES=ranks,reminders`).

## State
- HEAD after this iteration: A13 http/wiring commit + this docs commit. No
  uncommitted work left by this session; sibling loops' commits were preserved.
- A13 is `[x]`; A14 is the first unchecked task. No `.env`, no docs/PLAN.md,
  no `app/`, no fixed ports, no pushes.

## Next action (A14, first unchecked task)
- Final pass: add a README section for running the API; reconcile docs/API.md
  with the shipped code (addendum v2 shapes: `otp` vs legacy `code`, `/me`,
  `/notifications` read flag, `/dev/run-reminders`, DEV=1); tidy docs/API.md
  and handoff. Note the stricter-loop rule limits edits to `api/` plus
  `docs/handoff/api.md`, `docs/tasks-api.md`, `docs/decisions-api.md` — a README
  or docs/API.md change needs the human's task wording to override that limit;
  otherwise record the conflict in decisions and leave the doc pass undone.
- Then gate, tick A14, append decision, rewrite handoff, commit.

## Blockers
- None for A13. Two api loops still share the tree (D22–D24); a human must stop
  one `scripts/loop.sh opencode api ...` process. Until then re-read before
  writes, commit atomically with explicit paths, never revert peer work.
