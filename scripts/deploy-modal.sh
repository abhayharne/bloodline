#!/usr/bin/env bash
# Build a small Linux API binary and deploy it without uploading local secrets.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
modal_bin="${MODAL_BIN:-modal}"
command -v go >/dev/null || { echo 'Go is required.' >&2; exit 1; }
command -v "$modal_bin" >/dev/null || { echo 'Install Modal and run modal setup first.' >&2; exit 1; }
mkdir -p "$root/dist/modal"
(
  cd "$root/api"
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w' \
    -o "$root/dist/modal/bloodline-api" ./cmd/server
)
# Recreate prevents old and new app versions writing the same SQLite file.
"$modal_bin" deploy --strategy=recreate "$root/deploy/modal_app.py"
