# App Handoff
**From:** agy (app agent)  **To:** next agent / human  **Time:** 2026-11-22 02:53 IST
**Branch:** feat/app

## Done this iteration
- Task B0: Vendored `ai_nexconn_chatui_plugin` into `app/packages/ai_nexconn_chatui_plugin` with reproducible Kotlin plugin class casing fix (`AiNexconnChatUIPlugin.kt`).
- Updated `app/pubspec.yaml` with path dependency to `packages/ai_nexconn_chatui_plugin`.
- Excluded `packages/**` from analyzer in `app/analysis_options.yaml`.
- Recorded decision in `docs/decisions-app.md`.
- Gate `scripts/gate-app.sh` passed cleanly (19/19 tests passing, analyzer clean).

## State of the code
- Gate: `scripts/gate-app.sh` PASS (flutter analyze + 19 widget/unit tests green).
- Plugin dependency is fully vendored and reproducible without manual `~/.pub-cache` edits.

## Next action
- Task B1: Architecture alignment — `lib/core/api_client.dart` (ensure abstract `ApiClient` + `HttpApiClient` + `MockApiClient` selected by `--dart-define=USE_MOCK`), `lib/core/features.dart` (loads `GET /config`), `lib/core/slots.dart` (`SlotRegistry: homeCards, profileSections, roomHeaderBadges`), verify provider-based state & routing.

## Blockers / Human notes
- A human must verify Android build with `flutter build apk` on a real device/SDK environment in the morning.
