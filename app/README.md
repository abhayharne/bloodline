# BloodLine Flutter app

## Create the project (once)
```
cd app
flutter create . --org com.bloodline --project-name bloodline
```

## Dependencies (add to pubspec.yaml, then `flutter pub get`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  ai_nexconn_chat_plugin: ^26.2.6
  ai_nexconn_chatui_plugin: ^26.2.8
  provider: ^6.1.2
  http: ^1.2.2
  geolocator: ^13.0.1
  shared_preferences: ^2.3.2
```
Check pub.dev for the latest compatible versions. Follow the Nexconn Flutter guide for
Android/iOS platform setup (minSdk, permissions) and use the `nexconn-chat` skill if available.

## Suggested structure
```
lib/
  main.dart                      # app + providers + routing
  core/api_client.dart           # REST client, base URL setting, JWT header
  core/nexconn_service.dart      # init SDK, connect with nexconn_token
  features/auth/                 # signup/login, role picker
  features/requests/             # request form, my requests, donor/bank feed
  features/bank/                 # stock editor
  features/chat/                 # ChannelPage inbox, ChatPage wrapper + summary chip
```

## Chat wiring (from Chat UI docs)
```dart
ChannelPage(
  onItemTap: (channel, index, context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => ChatPage(channel: channel))),
);
```

## Android networking
Use the laptop LAN IP (e.g. http://192.168.x.x:8080). For http (non-TLS) add
`android:usesCleartextTraffic="true"` in AndroidManifest during dev.

## Permissions
Location (geolocator), notifications (optional), camera/photos for chat attachments.
