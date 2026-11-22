# Handoff
**From:** opencode (api, OTP alias follow-up) **To:** next api session **Time:** 2026-11-22 14:05
**Branch:** feat/api **Last commit:** `3472f4e` `[opencode] cover both OTP field aliases on verify and signup`

## Done
- Re-read AGENTS.md, this handoff, `docs/PLAN.md` and `docs/API.md`, and checked `git status` / `git log -10 --oneline` before editing.
- Confirmed the handlers already accept both fields from `3275f19`: `POST /auth/verify` and `POST /auth/signup` read `code` or `otp`, `code` wins when both are present, and signup rejects a wrong supplied value with 401.
- Docs first: `docs/API.md` now states explicitly that **either field alone is sufficient** on both endpoints, for signup as well as verify.
- Closed the remaining test gap: `api/internal/httpapi/contract_test.go` now covers verify via `otp`, via `code`, both fields, and wrong values; signup via `otp` only, `code` only, both fields, and wrong values.
- `scripts/smoke.sh` signs up requester/donor via `otp` and the bank via `code`, so the e2e flow exercises both aliases on signup; verify still exercises both aliases.
- Final `scripts/gate-api.sh` PASS: build, vet, `go test -race -count=1 ./...`, smoke with `FEATURES=` and `FEATURES=ranks,reminders`.

## State
- Tasks A0-A15 remain `[x]`; no new task letter was needed for this coverage follow-up.
- Only working-tree item is the pre-existing untracked empty `api/data/hospitals.json`; it was not touched. No `app/`, `.env`, `AGENTS.md` or `docs/PLAN.md` edits; no pushes.
- A long-lived `go run ./cmd/server` (PID 279991) predates this session and was left running; no `loop.sh` / `opencode run` process is active.

## Next action
- None. Wait for the human to assign new work. If asked to re-verify this contract, run `scripts/gate-api.sh` and inspect `TestAuthAcceptsOTPAndCodeAliases`.

## Blockers
- None.
