# App Decisions

## D-APP-1 — Vendored ai_nexconn_chatui_plugin with Kotlin casing fix
- Context: `ai_nexconn_chatui_plugin` (26.2.11) on pub.dev specifies `pluginClass: AiNexconnChatUIPlugin` in pubspec.yaml but originally shipped with `AiNexconnChatuiPlugin.kt` (lowercase "ui"), causing plugin registration failure on case-sensitive filesystems. Modifying `~/.pub-cache` directly is not reproducible across clean clones, new machines, or CI.
- Decision: Vendored the plugin into `app/packages/ai_nexconn_chatui_plugin` with `AiNexconnChatUIPlugin.kt` properly named and path-referenced in `app/pubspec.yaml`. Excluded `packages/**` from root analyzer in `app/analysis_options.yaml`.
- Note for morning: A human must verify with a real Android build (`flutter build apk`) on a real environment in the morning.

## D-APP-2 — Architecture alignment: abstract ApiClient, MockApiClient/HttpApiClient, features & slots
- Context: Task B1 requires abstract ApiClient with HttpApiClient & MockApiClient chosen via `--dart-define=USE_MOCK`, configurable base URL, models ignoring unknown fields, `lib/core/features.dart` loading `GET /config`, `lib/core/slots.dart` defining SlotRegistry (empty in core).
- Decision:
  1. Defined abstract `ApiClient` with factory constructor switching between `MockApiClient` and `HttpApiClient` based on `USE_MOCK` dart-define or `mockMode` parameter, with configurable base URL (defaulting to `API_BASE` or localhost).
  2. Implemented `lib/core/features.dart` to query and cache features from `GET /config`.
  3. Created `lib/core/slots.dart` with `SlotRegistry` (`homeCards`, `profileSections`, `roomHeaderBadges`) empty in core; aliased `slot_registry.dart` for backwards compatibility.
  4. Confirmed all JSON models (`User`, `AppConfig`, `BloodRequest`, `BloodStockItem`, `BloodRequestResponse`) tolerate and ignore unknown fields.

## D-APP-3 — Auth flow: phone entry, demo mode OTP, signup with donor consent, typed-area fallback & Nexconn connection
- Context: Task B2 requires phone entry, mock OTP screen showing 'demo mode, code 123456' when demo, signup form with role, name, age, weight, height, sex, donated before, optional last donation date, consent checkbox for donors, location permission request with typed-area fallback, and connecting Nexconn via nexconn_service.dart using nexconn_token and AreaCode.sg.
- Decision:
  1. Updated `LoginScreen` to invoke `authProvider.sendOtp(phone)` and display an info banner with 'demo mode, code 123456' when in demo mode.
  2. Implemented `authProvider.verifyOtp(phone, otp)` routing existing users directly to home dashboard and new users to `ProfileScreen`.
  3. Added donor consent checkbox to `ProfileScreen` with validation ensuring donors must consent before registration.
  4. Added typed-area fallback `TextFormField` alongside preset chips and GPS device location request in `ProfileScreen`.
  5. Configured `NexconnService` connection handling with `AreaCode.sg` and `nexconn_token`, gracefully handling mock tokens in tests and real tokens against Nexconn SDK.
