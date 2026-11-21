# App Decisions

## D-APP-1 — Vendored ai_nexconn_chatui_plugin with Kotlin casing fix
- Context: `ai_nexconn_chatui_plugin` (26.2.11) on pub.dev specifies `pluginClass: AiNexconnChatUIPlugin` in pubspec.yaml but originally shipped with `AiNexconnChatuiPlugin.kt` (lowercase "ui"), causing plugin registration failure on case-sensitive filesystems. Modifying `~/.pub-cache` directly is not reproducible across clean clones, new machines, or CI.
- Decision: Vendored the plugin into `app/packages/ai_nexconn_chatui_plugin` with `AiNexconnChatUIPlugin.kt` properly named and path-referenced in `app/pubspec.yaml`. Excluded `packages/**` from root analyzer in `app/analysis_options.yaml`.
- Note for morning: A human must verify with a real Android build (`flutter build apk`) on a real environment in the morning.
