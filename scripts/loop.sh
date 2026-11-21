#!/usr/bin/env bash
# Overnight generate -> verify -> fix loop for ONE agent in ONE worktree. Run from the worktree root.
# usage: scripts/loop.sh <opencode|agy|fake> <api|app> <gate_script> <task_regex> [max_iters] [deadline_epoch]
# stop early:  touch .loop/STOP
set -uo pipefail

AGENT=${1:?agent: opencode|agy|fake}
ROLE=${2:?role: api|app}
GATE=${3:?gate script}
TASKRE=${4:?task id regex, e.g. A[0-9]+}
MAX=${5:-40}
DEADLINE=${6:-0}
ITER_TIMEOUT=${ITER_TIMEOUT:-1500}   # seconds per agent run
GATE_TIMEOUT=${GATE_TIMEOUT:-900}
MAX_STALLS=${MAX_STALLS:-3}          # stop after this many iterations with no new commit
MAX_QUOTA_WAITS=${MAX_QUOTA_WAITS:-24}
AGY_FLAGS=${AGY_FLAGS:-}
TASKS="docs/tasks-${ROLE}.md"

mkdir -p .loop
LOG=.loop/loop.log
log() { echo "$(date '+%F %T') [$ROLE] $*" | tee -a "$LOG"; }
excl=$(git rev-parse --git-path info/exclude)
grep -qxF '.loop/' "$excl" 2>/dev/null || echo '.loop/' >> "$excl"

[ -f "$TASKS" ] || { log "missing $TASKS"; exit 1; }
START=$(git rev-parse HEAD)
rm -f .loop/STOP

remaining() { grep -cE "^[[:space:]]*- \[ \] (${TASKRE})\b" "$TASKS" || true; }
run_gate()  { timeout "$GATE_TIMEOUT" bash "$GATE" > "$1" 2>&1; }

run_agent() {
  local prompt=$1
  case "$AGENT" in
    opencode) timeout "$ITER_TIMEOUT" opencode run --auto "$prompt" ;;
    agy)      timeout "$ITER_TIMEOUT" agy $AGY_FLAGS -p "$prompt" ;;
    fake)     timeout "$ITER_TIMEOUT" bash -c "${FAKE_CMD:?set FAKE_CMD}" ;;
    *) echo "unknown agent"; return 2 ;;
  esac
}

stalls=0; quota_waits=0; reason="max iterations"
for ((i=1; i<=MAX; i++)); do
  [ -f .loop/STOP ] && { reason="STOP file"; break; }
  if [ "$DEADLINE" -gt 0 ] && [ "$(date +%s)" -ge "$DEADLINE" ]; then reason="deadline"; break; fi
  left=$(remaining)
  [ "$left" -eq 0 ] && { reason="all tasks done"; break; }

  head_before=$(git rev-parse HEAD)
  if run_gate .loop/gate-before.txt; then gate=PASS; else gate=FAIL; fi
  log "iter $i/$MAX: gate=$gate tasks_left=$left"

  prompt=$(cat <<PROMPT
You are the "$ROLE" agent in an UNATTENDED overnight loop (iteration $i of $MAX). Nobody can answer questions: never ask, decide and record the decision.

Read first: AGENTS.md, docs/handoff/$ROLE.md, $TASKS, docs/API.md, docs/API-addendum-v2.md, docs/COPY.md.
Gate ($GATE) before this iteration: $gate
$( [ "$gate" = FAIL ] && { echo '--- last 60 lines of gate output ---'; tail -n 60 .loop/gate-before.txt; } )

Rules:
1. If the gate FAILED, fix that first. Then do the FIRST task marked "- [ ]" in $TASKS, and only that one.
2. A task is done only when the gate passes. Run it yourself ($GATE). Then change its box to "- [x]".
3. If a task is impossible without a human (real device, real credentials, missing info), change its box to "- [!]" and add a one-line "BLOCKED: reason" under it, then stop this iteration.
4. Commit small and often with the prefix "[$AGENT]". NEVER push. Never use sudo. Never edit .env. Never touch docs/PLAN.md.
5. Stay inside your folder (api/ or app/) plus docs/handoff/$ROLE.md, $TASKS and docs/decisions-$ROLE.md (append decisions there, not in DECISIONS.md).
6. Do NOT run "flutter build", "flutter run" or anything that needs a phone. Do not start servers on fixed ports (use a random free port).
7. Finish by rewriting docs/handoff/$ROLE.md (under 60 lines: done, state, next action, blockers) and commit.
PROMPT
)
  run_agent "$prompt" > ".loop/iter-$i.log" 2>&1
  rc=$?
  log "iter $i: agent exit=$rc"

  if grep -qiE 'quota|rate.?limit|429|resource.?exhausted' ".loop/iter-$i.log" && [ "$rc" -ne 0 ]; then
    quota_waits=$((quota_waits+1))
    log "quota/rate limit suspected ($quota_waits/$MAX_QUOTA_WAITS); sleeping 10 min"
    [ "$quota_waits" -ge "$MAX_QUOTA_WAITS" ] && { reason="quota exhausted"; break; }
    sleep 600; i=$((i-1)); continue
  fi

  if [ -n "$(git status --porcelain)" ]; then
    git add -A && git commit -qm "[loop] checkpoint after iter $i" || log "checkpoint commit refused (guards?)"
  fi
  if run_gate .loop/gate-after.txt; then
    git tag -f "good-$ROLE" >/dev/null 2>&1; log "iter $i: gate after = PASS (tag good-$ROLE moved)"
  else
    log "iter $i: gate after = FAIL"
  fi

  if [ "$(git rev-parse HEAD)" = "$head_before" ]; then stalls=$((stalls+1)); else stalls=0; fi
  log "iter $i: stalls=$stalls"
  [ "$stalls" -ge "$MAX_STALLS" ] && { reason="stalled ($MAX_STALLS iterations with no commit)"; break; }
done

{
  echo "# Loop report ($ROLE)"
  echo "- finished: $(date '+%F %T')   reason: $reason"
  echo "- tasks left: $(remaining)   blocked: $(grep -cE '^[[:space:]]*- \[!\]' "$TASKS" || true)"
  echo "- last good commit: $(git rev-parse --short good-$ROLE 2>/dev/null || echo none)   head: $(git rev-parse --short HEAD)"
  echo; echo "## Commits since start"; git log --oneline "$START"..HEAD
  echo; echo "## Blocked tasks"; grep -A1 -E '^[[:space:]]*- \[!\]' "$TASKS" || echo none
} > .loop/REPORT.md
log "DONE: $reason (see .loop/REPORT.md)"
