#!/usr/bin/env bash
# usage (inside tmux):  scripts/night.sh [hours=9]
# Keeps the laptop awake (lid closed too), installs guards, runs both loops in parallel, removes guards at the end.
set -u
HOURS=${1:-9}
API=${API_DIR:-$HOME/bloodline-api}; APP=${APP_DIR:-$HOME/bloodline-app}
if [ -z "${INHIBITED:-}" ]; then
  export INHIBITED=1 DEADLINE=$(( $(date +%s) + HOURS*3600 ))
  exec systemd-inhibit --what=sleep:idle:handle-lid-switch --who=bloodline-night --why="overnight agent loops" "$0" "$@"
fi
trap 'bash "$API/scripts/install-guards.sh" remove "$API" "$APP"' EXIT
bash "$API/scripts/install-guards.sh" install "$API" "$APP" || exit 1
echo "deadline: $(date -d @"$DEADLINE")"
( cd "$API" && PATH="$API/.loop/shims:$PATH" LOOP_ROOT="$API" bash scripts/loop.sh opencode api scripts/gate-api.sh 'A[0-9]+' 40 "$DEADLINE" ) &
( cd "$APP" && PATH="$APP/.loop/shims:$PATH" LOOP_ROOT="$APP" bash scripts/loop.sh agy app scripts/gate-app.sh 'B[0-9]+' 40 "$DEADLINE" ) &
wait
echo "both loops finished: see $API/.loop/REPORT.md and $APP/.loop/REPORT.md"
