# Overnight tasks: App (Antigravity, folder app/, handoff docs/handoff/app.md)
Done = scripts/gate-app.sh passes (flutter analyze + flutter test; no phone, no APK builds). Box states: [ ] todo, [x] done, [!] blocked (add "BLOCKED: reason").
Contract: docs/API.md plus docs/API-addendum-v2.md (the addendum wins). Backend is built in parallel, so talk to it ONLY through lib/core/api_client.dart.
Every screen gets at least one widget test using the mock client.

- [x] B0 Make the plugin fix reproducible: pin ai_nexconn_chatui_plugin to an exact version, check whether the Kotlin redeclaration is gone without touching ~/.pub-cache; if not, vendor the patched plugin into app/packages/ and use a path dependency. Do NOT run flutter build; note in docs/decisions-app.md that a human must verify with a real build in the morning.
- [x] B1 Architecture: lib/core/api_client.dart (abstract ApiClient + HttpApiClient + MockApiClient chosen by --dart-define=USE_MOCK, base URL configurable, JSON models ignore unknown fields), lib/core/features.dart (loads GET /config), lib/core/slots.dart (SlotRegistry: homeCards, profileSections, roomHeaderBadges, empty in core), lib/features/<name>/register.dart convention, provider-based state, simple routing.
- [x] B2 Auth: phone entry, mock OTP screen (shows "demo mode, code 123456" when demo), signup form (role, name, age, weight, height, sex, donated before, optional last donation date, consent checkbox for donors), location permission request with a typed-area fallback. Connects Nexconn via nexconn_service.dart using nexconn_token and AreaCode.sg.
- [x] B3 Requester: new-request form (blood group, units, hospital, urgency, location defaulting to current), my requests list with status chips.
- [x] B4 Donor: feed of matching open requests, "I can help" -> accept -> opens the chat, availability toggle (PUT /me).
- [x] B5 Bank: stock editor for the 8 groups (PUT /banks/me/stock), open requests list, open chat.
- [x] B6 Chat: ChannelPage inbox and ChatPage wrapper with a request-summary header (group, units, hospital, status) and room header slot. Keep the Nexconn SDK calls isolated in nexconn_service.dart so the rest is testable with fakes.
- [x] B7 Fulfill and donated: requester "Mark fulfilled" button, closed-room read-only banner, donor "I donated" button (POST /requests/{id}/donated).
- [ ] B8 Notifications: poll GET /notifications every 10 s, in-app banner and a notifications list; copy comes from the server, do not hardcode.
- [ ] B9 Feature ranks (flag ranks): rank badge section in profile and a home card ("{n} donations, {rank}"), registered via slots only when features contains ranks.
- [ ] B10 Feature reminders (flag reminders): home card "You may be eligible again" from /me derived fields, registered via slots only when enabled.
- [ ] B11 Accessibility: large-font toggle (textScaler) in settings. Voice-to-text only if a package works without extra platform setup; otherwise mark [!].
- [ ] B12 Final pass: widget tests green, README section for running the app against the real API (flutter run --dart-define=API_BASE=... --dart-define=NEXCONN_APP_KEY=...), tidy handoff, list everything that needs a real device in docs/handoff/app.md.
