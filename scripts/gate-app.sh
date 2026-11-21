#!/usr/bin/env bash
# Verification gate for the Flutter app (no phone needed). Exit 0 = healthy.
set -e
cd "$(dirname "$0")/../app"
flutter pub get > /dev/null
out=$(flutter analyze --no-fatal-infos 2>&1) && rc=0 || rc=$?
echo "$out" | grep -E "^ *(error|warning) " || true
echo "$out" | grep -E "issues? found|No issues" || true
[ "$rc" -eq 0 ] || exit 1
flutter test
echo "GATE-APP OK"
