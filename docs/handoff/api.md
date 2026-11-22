# Handoff
**From:** opencode (api, hospital/components task) **To:** next api session **Time:** 2026-11-22 14:35
**Branch:** feat/api **Last commit:** `fd0ccc2` `[opencode] Add hospital lookup, request components and apheresis matching`

## Done
- START checks done: AGENTS.md, this handoff, `docs/PLAN.md`, `docs/API.md`, `docs/API-addendum-v2.md`; `git status` and `git log` reviewed.
- Docs first: `docs/API.md` and `docs/DATA_MODEL.md` cover all new routes/fields, plus `docs/decisions-api.md` (D29), `docs/tasks-api.md` (A16) and `docs/PLAN.md` (T1.13), all ticked.
- `GET /hospitals` is public and reads `api/data/hospitals.json` via `go:embed` (new `api/data` package). `q` substring on name/area, nearest-first when both `lat`/`lng` are given, `limit` 1..50 default 20; bad params are 400.
- `POST /requests`: `hospital_id` resolves name/lat/lng from the directory and wins over supplied values; without it both coordinates and a hospital name are required. `component` defaults `whole_blood`; `notes` optional (<=500). Both returned on every request response.
- Component rules in `internal/matching`: whole blood/red cells/other keep the red-cell ABO/Rh chart; plasma/cryo use reverse ABO read literally as patient<-donor (`O`<-all, `AB`<-AB), Rh ignored; platelets rank same ABO first and Rh-negative donors first for Rh-negative patients.
- `bank_stock.component` added to the PK via idempotent rebuild; `requests.component`/`notes` and `users.apheresis_ok` via idempotent ALTERs. Apheresis components match component stock and only `apheresis_ok=true` donors; settable via `PUT /me`.
- Every validation failure returns 400 `{"error":"specific message"}`. App urgency values are already canonical `low|medium|high|critical`, so no enum change was needed.
- Tests added: table-driven compatibility, hospital/service/handler round trips, requester+feed open-request regression, legacy migration coverage. Smoke grew to 13 steps covering all of the above.
- Final `scripts/gate-api.sh` PASS: build, vet, `go test -race -count=1 ./...`, smoke with `FEATURES=` and `FEATURES=ranks,reminders`.

## State
- Working tree clean; no pushes. Only `api/` and docs plus `scripts/smoke.sh` touched; no `app/`, `.env`, `AGENTS.md` or `docs/PLAN.md` scope changes beyond ticking T1.13.
- A long-lived `go run ./cmd/server` (PID 279991) predates this session and was left running; no `loop.sh` / `opencode run` process is active.

## Next action
- None. Wait for the human to assign new work. If asked to re-verify, run `scripts/gate-api.sh` and inspect `TestRequesterSeesOwnOpenRequest`, `TestCompatibleForComponentPlasma` and `TestComponentAwareMatching`.

## Blockers
- None.
