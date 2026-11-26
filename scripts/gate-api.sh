#!/usr/bin/env bash
# Verification gate for the Go API. Exit 0 = healthy.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/api"
go build ./...
go vet ./...
go test -race -count=1 ./...
# Run the isolated request-lifecycle smoke test in both feature configurations.
if [ -x "$root/scripts/smoke.sh" ]; then
  FEATURES= NEXCONN_FAKE=1 "$root/scripts/smoke.sh"
  FEATURES=ranks,reminders NEXCONN_FAKE=1 "$root/scripts/smoke.sh"
fi
echo "GATE-API OK"
