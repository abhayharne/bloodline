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

## D-APP-4 — Fulfill and donated: requester fulfill, closed-room read-only banner, donor I donated
- Context: Task B7 requires requester "Mark fulfilled" button, closed-room read-only banner, and donor "I donated" button (POST /requests/{id}/donated).
- Decision:
  1. Requester "Mark fulfilled" button: Added labeled `FilledButton.icon` to `RequestSummaryHeader` and `BloodRequestChatScreen` AppBar for requester owners of open requests, as well as on active requests in `RequesterScreen`. Prompts a confirmation dialog and invokes `requestsProvider.fulfillRequest(id)`.
  2. Closed-room read-only banner: When a request status is fulfilled or cancelled, displays a read-only notification banner in `BloodRequestChatScreen` and wraps `ChatPage` with `IgnorePointer(ignoring: isClosed)` to prevent further message interactions while preserving history.
  3. Donor "I donated" button: Added "I donated" button for donors in `RequestSummaryHeader`, `BloodRequestChatScreen` AppBar, and `DonorScreen` feed for joined requests. Prompts confirmation dialog and calls `requestsProvider.recordDonation(requestId)` hitting `POST /requests/{id}/donated`, updating UI to show "Donated" status badge.

## D-APP-4 — Fulfill and Donated actions: requester completion, closed-room read-only banner, donor record donation
- Context: Task B7 requires requester 'Mark fulfilled' button, closed-room read-only banner, and donor 'I donated' button (POST /requests/{id}/donated).
- Decision:
  1. Updated `RequestSummaryHeader` and `BloodRequestChatScreen` with requester 'Mark fulfilled' action (triggering confirmation dialog and `RequestsProvider.fulfillRequest(id)`).
  2. Implemented closed-room read-only banner displayed in `RequestSummaryHeader` and `BloodRequestChatScreen` whenever request status is fulfilled/cancelled, disabling chat input.
  3. Added donor 'I donated' action in `RequestSummaryHeader`, `BloodRequestChatScreen`, and `DonorScreen` (for joined requests), invoking `RequestsProvider.recordDonation(id)` (POST /requests/{id}/donated) and updating state to 'Donated'.
  4. Added `donated` field support to `BloodRequest` model and synchronized in-memory mock state in `MockApiClient`.
  5. Added comprehensive widget tests for fulfill and donation flows in `test/core_screens_test.dart` (30/30 tests passing, gate clean).

## D-APP-5 — Notifications: 10s polling, in-app banner, notifications list with server-driven copy
- Context: Task B8 requires polling GET /notifications every 10 s, in-app banner and a notifications list with copy coming strictly from the server (not hardcoded).
- Decision:
  1. Implemented `InAppNotification` model in `lib/core/models/in_app_notification.dart` mapping `id`, `type`, `title`, `body`, `created_at`, `read` while ignoring unknown fields.
  2. Implemented `NotificationsProvider` in `lib/core/providers/notifications_provider.dart` with periodic 10-second polling (`Timer.periodic`), immediate fetch, unread count tracking, active banner management with dismissal, and `markAsRead` / `markAllAsRead` calling `POST /notifications/{id}/read`.
  3. Created `NotificationBanner` in `lib/features/notifications/notification_banner.dart` integrated at the top of `HomeScreen` dashboard, presenting server-provided title and body with "Mark read", "View All", and dismiss actions.
  4. Created `NotificationsScreen` in `lib/features/notifications/notifications_screen.dart` displaying the full notification feed with unread indicators, pull-to-refresh, empty state, and one-tap read actions. Added notification bell icon with dynamic unread badge in `HomeScreen` AppBar.
  5. Added comprehensive widget and unit tests covering polling, banner server copy rendering, dismiss, empty state, and read actions (35/35 tests green, gate clean).

## D-APP-6 — Feature ranks: rank badge section in profile and home card via slots when flag enabled
- Context: Task B9 requires rank badge section in profile and a home card ("{n} donations, {rank}"), registered via slots only when features contains ranks.
- Decision:
  1. Created `UserRank` and `UserDerived` models in `lib/core/models/user_derived.dart` with milestone mapping (1 First Drop, 3 Helper, 5 Silver Lifeline, 10 Gold Lifeline, 25 Lifesaver) and pure functions in `lib/core/rules/ranks.dart`.
  2. Implemented `RanksHomeCard` in `lib/features/ranks/ranks_home_card.dart` displaying `"{n} donations, {rank}"` with gradient styling and medal iconography.
  3. Implemented `RanksProfileSection` in `lib/features/ranks/ranks_profile_section.dart` displaying rank badge chip, lifetime donation count, and unlocked milestone chips in profile.
  4. Implemented `registerRanksFeature({features, config, registry})` in `lib/features/ranks/register.dart` which registers cards into `SlotRegistry.instance.homeCards` and `profileSections` only when the `'ranks'` feature flag is active, ensuring idempotency.
  5. Hooked dynamic configuration triggers in `ConfigProvider.fetchConfig()` and `AuthProvider.fetchMe()`, allowing real-time slot appearance upon config loading and instant rank progression updates when donations are recorded.
  6. Added comprehensive unit and widget tests in `test/ranks_test.dart` and `test/models_test.dart` (45/45 tests passing, gate clean).

## D-APP-7 — Feature reminders: home card via slots and eligibility pure rules
- Context: Task B10 requires feature reminders (flag `reminders`) registering a home card "You may be eligible again" from `/me` derived fields via slots only when enabled.
- Decision:
  1. Implemented pure donor eligibility functions in `lib/core/rules/eligibility.dart` and `lib/core/rules/reminders.dart` matching `docs/API-addendum-v2.md` specifications (age 18..65, weight >= 45 kg, explicit available check, male cooldown 90 days, female cooldown 120 days, permissive defaults for null values).
  2. Implemented `RemindersHomeCard` in `lib/features/reminders/reminders_home_card.dart` reading `derived.eligible` and `derived.nextEligibleAt` from `AuthProvider`, following `docs/COPY.md` tone ("You may be eligible again", recharge days display, soft snooze with "No pressure. We'll check back next month.", and "I'm ready" CTA).
  3. Implemented `registerRemindersFeature({features, config, registry})` in `lib/features/reminders/register.dart`, registering into `SlotRegistry.instance.homeCards` only when `features.hasReminders` or `config.hasFeature('reminders')` is active.
  4. Hooked `registerRemindersFeature` into `ConfigProvider.fetchConfig()` and `main.dart`, dynamically activating reminders slot upon config load.
  5. Added comprehensive unit and widget tests in `test/reminders_test.dart` and `test/eligibility_test.dart` (65/65 tests passing, gate clean).
