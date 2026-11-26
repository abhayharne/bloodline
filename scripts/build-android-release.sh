#!/usr/bin/env bash
# Build a signed universal APK for direct distribution.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_base="${1:-}"
if [[ -z "$api_base" ]]; then
  echo "Usage: scripts/build-android-release.sh https://your-public-api.example" >&2
  exit 1
fi
api_base="${api_base%/}"
client_app_key="${NEXCONN_APP_KEY:-qf3d5gbjqvm5h}"
python3 - "$api_base" <<'PY'
import ipaddress
import sys
from urllib.parse import urlparse
url = urlparse(sys.argv[1])
if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment:
    raise SystemExit("Use a public HTTPS API URL without credentials, query or fragment.")
if url.hostname in {"localhost", "localhost.localdomain"} or url.hostname.endswith((".local", ".localhost")):
    raise SystemExit("A downloadable app needs a public API, not localhost.")
try:
    address = ipaddress.ip_address(url.hostname)
except ValueError:
    address = None
if address is not None and not address.is_global:
    raise SystemExit("Private network API addresses cannot be distributed as a public release.")
PY
python3 - "$api_base" <<'PY'
import json
import sys
import time
import urllib.request

base = sys.argv[1]
deadline = time.monotonic() + 90
while True:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise SystemExit("API did not become healthy within 90 seconds; no APK built.")
    try:
        with urllib.request.urlopen(base + "/health", timeout=min(10, remaining)) as response:
            if json.load(response).get("status") == "ok":
                break
    except (OSError, ValueError):
        pass
    time.sleep(min(2, max(0, deadline - time.monotonic())))
with urllib.request.urlopen(base + "/config", timeout=10) as response:
    config = json.load(response)
if not isinstance(config.get("features"), list) or config.get("demo_mode") is not True:
    raise SystemExit("Unexpected demo API configuration; no APK built.")
print("Public demo API is healthy.")
PY
if [[ ! -f "$repo_root/app/android/key.properties" ]]; then
  echo "Run python3 scripts/create-android-signing.py first." >&2
  exit 1
fi
cd "$repo_root/app"
flutter build apk --release --dart-define="API_BASE=$api_base" \
  --dart-define="NEXCONN_APP_KEY=$client_app_key"
mkdir -p "$repo_root/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$repo_root/dist/bloodline.apk"
cd "$repo_root/dist"
sha256sum bloodline.apk > SHA256SUMS
echo "Ready: dist/bloodline.apk and dist/SHA256SUMS"
