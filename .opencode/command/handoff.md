---
description: Write handoff for the other agent
---
# Handoff
Use when switching to the other agent or ending a session.
1. Run the build and tests (`cd api && go test ./...`; `cd app && flutter analyze` if app changed). Note results.
2. Commit all work with prefix `[opencode]`.
3. Update checkboxes in docs/PLAN.md.
4. Overwrite docs/handoff/api.md completely using its existing section layout: From, To (the other agent), time, branch, last commit hash, current task, done this session, state of the code, next action, gotchas, open questions, do-not-touch. Under 60 lines.
5. Commit PLAN.md and HANDOFF.md as `[opencode] handoff`.
6. Reply with a 5-line summary only.
