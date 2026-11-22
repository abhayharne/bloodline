# BloodLine Flutter App

Emergency blood request coordination mobile app built with Flutter, Provider, and the Nexconn Chat SDK.
Each emergency request establishes a live group chat room connecting the requester, blood bank(s), and matched nearby donors. The room closes once the request is fulfilled.

---

## Running the App Against the Real API

The app connects to the Go backend and the Nexconn Singapore Chat infrastructure using compile-time Dart configuration flags (`--dart-define`).

### Command

```bash
flutter run \
  --dart-define=API_BASE=http://<API_HOST>:8080 \
  --dart-define=NEXCONN_APP_KEY=<NEXCONN_APP_KEY>
```

### Host Configuration by Platform

| Environment | `API_BASE` Value | Notes |
|-------------|------------------|-------|
| **Android Emulator** | `http://10.0.2.2:8080` | `10.0.2.2` routes directly to the host machine's `localhost:8080`. |
| **iOS Simulator** | `http://localhost:8080` | Shares localhost networking with macOS host. |
| **Desktop (Linux/macOS)** | `http://localhost:8080` | Localhost networking. |
| **Physical Android / iOS Device** | `http://192.168.x.x:8080` | Use your development machine's local Wi-Fi IP address. Ensure both phone and laptop are on the same Wi-Fi network. |

### Cleartext HTTP on Android
For local development against non-TLS `http://` endpoints, `android:usesCleartextTraffic="true"` is enabled in `android/app/src/main/AndroidManifest.xml`.

---

## Offline / Demo Mode (No Server Needed)

You can run and test the complete app UI, auth flows, request submissions, bank stock adjustments, and chat screens offline without running the Go backend or Nexconn:

```bash
flutter run --dart-define=USE_MOCK=true
```

In mock mode:
- API client switches to in-memory `MockApiClient`.
- Demo OTP is `123456`.
- Nexconn service accepts mock tokens seamlessly.

---

## Testing & Quality Gates

Run the verification gate locally:

```bash
# From repository root:
./scripts/gate-app.sh

# Or from app directory:
flutter analyze --no-fatal-infos
flutter test
```

All 75+ widget and unit tests run against mock providers and models without requiring an active device or network connection.

---

## Architecture & Code Structure

```
app/
├── lib/
│   ├── main.dart                      # App entry point, multi-providers, textScaler
│   ├── core/                          # Infrastructure & shared abstractions
│   │   ├── api_client.dart            # Abstract ApiClient, HttpApiClient, MockApiClient
│   │   ├── nexconn_service.dart       # Nexconn Chat SDK singleton (AreaCode.sg)
│   │   ├── features.dart              # Feature flag loading from GET /config
│   │   ├── slots.dart                 # Extension slot registry (homeCards, profileSections)
│   │   ├── rules/                     # Pure business rules (eligibility, ranks, reminders)
│   │   └── providers/                 # State management (Auth, Requests, Stock, Notifs, Settings)
│   └── features/                      # Feature modules
│       ├── auth/                      # Phone login, mock OTP banner, donor consent signup
│       ├── requests/                  # Requester form, donor matching feed, "I donated"
│       ├── bank/                      # Blood bank 8-group stock manager
│       ├── chat/                      # ChannelPage inbox, ChatPage with summary header
│       ├── notifications/             # 10s polling, in-app banner, notification screen
│       ├── ranks/                     # Feature flag: milestone cards and profile badge
│       ├── reminders/                 # Feature flag: eligibility reminder home card
│       └── settings/                  # Accessibility: large-font toggle (1.3x textScaler)
└── packages/
    └── ai_nexconn_chatui_plugin/      # Vendored plugin with case-sensitivity fix
```

---

## Physical Device Verification Checklist

The following items cannot be fully verified in headless/unattended test runs and require a physical device or real emulator in the morning:

1. **Android & iOS Builds**: Execute `flutter build apk` and `flutter build ios --no-codesign` to verify Gradle and CocoaPods plugin linking.
2. **Real Nexconn Chat**: Verify real WebSocket connection to Singapore DC (`AreaCode.sg`) with real credentials and multi-user message receipt.
3. **GPS Sensor**: Test real GPS location detection via `geolocator` and OS permission dialogs on physical hardware.
4. **Microphone & Speech-to-Text**: If voice-to-text accessibility is enabled, verify physical microphone input and audio permissions.
