# App Handoff
**From:** antigravity  **To:** opencode / user  **Time:** 2026-11-21 16:45 IST
**Branch:** main  **Last commit:** 78076c7

## Current task
T0.2 spike is DONE. Flutter app is created, builds, installs, and runs on connected Android device.

## Done this session
- Initialized Flutter project under `app/` with package `bloodline` (`com.bloodline`).
- Added dependencies: `ai_nexconn_chat_plugin: ^26.2.6`, `ai_nexconn_chatui_plugin: ^26.2.8`, `provider`, `http`, `geolocator`, `shared_preferences`.
- Initialized Nexconn Chat SDK with `areaCode: AreaCode.sg` and `NEXCONN_APP_KEY` from dart-define (`.env` fallback). Wrapped root in `NexconnChatUIProviders`.
- Implemented `DebugScreen` allowing login as `test1`/`test2` with pasted user token, navigation to `ChannelPage`, and direct navigation to backend spike room `blspike1795251938` via `ChatPage`.
- Resolved Gradle OOM killer by tuning `org.gradle.jvmargs` in `android/gradle.properties` (`-Xmx3G -XX:MaxMetaspaceSize=1G`).
- Enabled core library desugaring in `android/app/build.gradle.kts` for `flutter_local_notifications`.
- Fixed `ai_nexconn_chatui_plugin` Linux file casing bug via rename. Documented in `docs/DECISIONS.md` (D9, D10).
- Installed APK via adb and launched on `motorola edge 50 fusion` (Android 16).
- Ran `flutter test`: all tests pass.

## State of the code
- App builds and installs: `cd app && flutter build apk --debug` OK.
- App tests: `cd app && flutter test` OK (100% passing).
- App is running on connected Android phone with live IM engine waiting for token login.

## Next action
- Paste user tokens issued by the backend (`test1` / `test2`) into the app's DebugScreen on device.
- Connect and open `blspike1795251938` or `ChannelPage` to verify live message exchange across devices.
- Begin P1 backend (`api/`) tasks (T1.1 - T1.9) or app feature screens (T2.1+).

## Gotchas / things I learned
- `AreaCode.sg` is lowercase in the Dart SDK enum.
- `ai_nexconn_chatui_plugin` on pub.dev has a Kotlin filename `AiNexconnChatuiPlugin.kt` that must be renamed to `AiNexconnChatUIPlugin.kt` in the pub cache on case-sensitive Linux filesystems.
- Machine RAM is 11 GB (5.4 GB free); Gradle heap must stay <= 3 GB to prevent OOM termination.
- `flutter_local_notifications` requires `isCoreLibraryDesugaringEnabled = true` and `desugar_jdk_libs`.

## Do NOT touch
- `api/` and `docs/API.md` (owned by opencode).
