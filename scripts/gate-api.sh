#!/usr/bin/env bash
# Verification gate for the Go API. Exit 0 = healthy.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/api"
go build ./...
go vet ./...
go test -race -count=1 ./...
# The smoke test only counts once task A9 is ticked (older smoke scripts expect a running server).
if [ -x "$root/scripts/smoke.sh" ] && grep -qE '^[[:space:]]*- \[x\] A9\b' "$root/docs/tasks-api.md"; then
  FEATURES= NEXCONN_FAKE=1 "$root/scripts/smoke.sh"
  FEATURES=ranks,reminders NEXCONN_FAKE=1 "$root/scripts/smoke.sh"
fi
echo "GATE-API OK"
