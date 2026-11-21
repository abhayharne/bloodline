#!/usr/bin/env bash
# Verification gate for the Go API. Exit 0 = healthy.
set -e
cd "$(dirname "$0")/../api"
go build ./...
go vet ./...
go test -race -count=1 ./...
if [ -x ../scripts/smoke.sh ]; then
  FEATURES= NEXCONN_FAKE=1 ../scripts/smoke.sh                       # core only
  FEATURES=ranks,reminders NEXCONN_FAKE=1 ../scripts/smoke.sh        # core + all features
fi
echo "GATE-API OK"
