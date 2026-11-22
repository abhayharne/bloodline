# BloodLine

Emergency blood requests as live chat rooms. Requesters, blood banks and nearby donors
coordinate in one channel per request; the room closes when the request is fulfilled.

## Android distribution

Signed APKs are prepared for direct installation through GitHub Releases.
See [deployment and installation instructions](deploy/README.md) for the public
API setup, private signing key, APK build and GitHub release steps.

## Launch video

[Watch the 22-second BloodLine launch film](brag-output/brag.mp4).
The [editable source and share caption](brag-output/README.md) are included.

## Quick start
```
git init && git add -A && git commit -m "scaffold"      # or: bash scripts/init-git.sh
cp .env.example .env                                    # fill in Nexconn keys
cd api && go run ./cmd/server                           # check: curl localhost:8080/health
cd ../app && flutter create . --org com.bloodline --project-name bloodline && flutter pub get
```
Then open the repo in OpenCode or Antigravity and say:
"Read AGENTS.md, docs/handoff/<agent>.md (opencode: api.md, antigravity: app.md) and docs/PLAN.md, then continue." (or run `/resume`)

## Running the API

From `api/` (Go 1.22). The API contract is in `docs/API.md`.

```sh
cd api
go test ./...                 # unit tests
go run ./cmd/server           # listens on :8080 (override with PORT)
curl localhost:8080/health    # -> {"status":"ok"}
```

**Offline demo (no real Nexconn credentials or network):** set `NEXCONN_FAKE=1`
for the in-memory stateful chat client and provide a JWT secret:

```sh
cd api
JWT_SECRET=dev-secret NEXCONN_FAKE=1 DEV=1 go run ./cmd/server
```

Useful env (see `.env.example`): `PORT`, `DB_PATH`, `JWT_SECRET`, `DEMO_OTP`
(default `123456`), `MATCH_RADIUS_KM`, `FEATURES` (comma list e.g.
`ranks,reminders`), `DEV=1` (enables unauthenticated `POST /dev/reset` and
`POST /dev/run-reminders`). Real mode needs the `NEXCONN_*` credentials and uses
the Singapore data center; never enable fake/mock/dev modes in production.

**End-to-end check:** `scripts/gate-api.sh` builds, vets, runs the race-enabled
Go tests and the self-contained smoke test. `scripts/smoke.sh` starts its own
throwaway server on a random free port with `NEXCONN_FAKE=1` and a temp DB, so it
needs no running server and touches no fixed port.

## Docs map
| File | Purpose |
|---|---|
| AGENTS.md | Rules for both agents |
| docs/PLAN.md | Task list, phases, timeline, scope |
| docs/handoff/<agent>.md (opencode: api.md, antigravity: app.md) | Baton passed between agents |
| docs/ARCHITECTURE.md | System design and flows |
| docs/API.md | REST contract |
| docs/DATA_MODEL.md | Tables and matching logic |
| docs/DEMO_SCRIPT.md | 3-minute demo |
| docs/PITCH.md | Pitch outline and Q&A |
| docs/DECISIONS.md | Decision log |
