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
curl --fail --silent --show-error --max-time 20 "$api_base/health" |
  python3 -c 'import json,sys; assert json.load(sys.stdin).get("status") == "ok", "API health failed"'
curl --fail --silent --show-error --max-time 20 "$api_base/config" |
  python3 -c 'import json,sys; c=json.load(sys.stdin); assert "features" in c, "Unexpected API config"'
if [[ ! -f "$repo_root/app/android/key.properties" ]]; then
  echo "Run python3 scripts/create-android-signing.py first." >&2
  exit 1
fi
cd "$repo_root/app"
flutter build apk --release --dart-define="API_BASE=$api_base"
mkdir -p "$repo_root/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$repo_root/dist/bloodline.apk"
cd "$repo_root/dist"
sha256sum bloodline.apk > SHA256SUMS
echo "Ready: dist/bloodline.apk and dist/SHA256SUMS"
