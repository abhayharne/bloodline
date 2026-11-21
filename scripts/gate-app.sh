#!/usr/bin/env bash
# Verification gate for the Flutter app (no phone needed). Exit 0 = healthy.
set -e
cd "$(dirname "$0")/../app"
flutter pub get > /dev/null
flutter analyze --no-fatal-infos
flutter test
echo "GATE-APP OK"
