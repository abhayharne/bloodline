# App Handoff
**From:** agy (app agent)  **To:** next agent / human  **Time:** 2026-11-22 04:46 IST
**Branch:** main

## Done this iteration
- Task B12 Final pass:
  - Replaced test placeholder in `app/test/widget_test.dart` with `BloodLineApp` root gate widget test (75/75 tests passing, gate clean).
  - Enhanced `app/README.md` with clear instructions for running against real Go backend and Nexconn Singapore Chat SDK using `--dart-define=API_BASE=...` and `--dart-define=NEXCONN_APP_KEY=...`.
  - Documented platform host address mapping (`10.0.2.2:8080` for Android emulator, `localhost:8080` for iOS simulator/desktop, and local Wi-Fi IP `192.168.x.x:8080` for physical devices), offline mock mode (`USE_MOCK=true`), and cleartext HTTP.
  - Recorded decision D-APP-9 in `docs/decisions-app.md`.
  - All tasks B0 through B12 in `docs/tasks-app.md` are completed (B11 marked `[!]` for voice-to-text hardware/platform requirement).

## State of the code
- Gate: `scripts/gate-app.sh` PASS (`flutter analyze` clean, 0 errors/warnings, 75/75 tests passing).
- Complete Flutter app architecture ready: Auth & signup with donor consent, Requester flow, Donor feed & accept, Blood Bank 8-group stock manager, Chat inbox/rooms with summary header, Fulfill & donation recording, 10s notification polling & in-app banner, feature ranks, feature reminders, and large-font accessibility toggle.

## Next action
- All scheduled app tasks (B0–B12) are complete!
- Morning handover: Human or physical device operator should perform physical device verification listed below.

## Blockers / Human notes (Real Device Morning Checklist)
1. **Real Android/iOS builds**: Execute `flutter build apk` / `flutter build ios` to verify vendored `ai_nexconn_chatui_plugin` Kotlin/CocoaPods linking.
2. **Nexconn Live Chat**: Test live WebSocket connection to Singapore DC (`AreaCode.sg`) with real credentials and multi-device real-time message sync.
3. **Hardware GPS Sensor**: Test real GPS location detection (`geolocator`) and runtime location permission dialog on a physical smartphone.
4. **Voice-to-Text Microphone (B11)**: If voice-to-text accessibility is desired, add platform speech permission manifest entries (`RECORD_AUDIO`, `Info.plist`) and test with physical microphone hardware.
5. **LAN Network Connectivity**: Verify physical phone connects to Go backend at `http://192.168.x.x:8080` over Wi-Fi.
