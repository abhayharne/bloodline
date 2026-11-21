# BloodLine

Emergency blood requests as live chat rooms. Requesters, blood banks and nearby donors
coordinate in one channel per request; the room closes when the request is fulfilled.

## Quick start
```
git init && git add -A && git commit -m "scaffold"      # or: bash scripts/init-git.sh
cp .env.example .env                                    # fill in Nexconn keys
cd api && go run ./cmd/server                           # check: curl localhost:8080/health
cd ../app && flutter create . --org com.bloodline --project-name bloodline && flutter pub get
```
Then open the repo in OpenCode or Antigravity and say:
"Read AGENTS.md, docs/handoff/<agent>.md (opencode: api.md, antigravity: app.md) and docs/PLAN.md, then continue." (or run `/resume`)

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
