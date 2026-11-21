import 'package:flutter/foundation.dart';
import 'api_client.dart';

export 'models/app_config.dart';

/// Features manager that loads feature flags from GET /config.
class Features {
  static const String ranks = 'ranks';
  static const String reminders = 'reminders';

  final List<String> _features;
  final bool demoMode;

  const Features({
    List<String> features = const [],
    this.demoMode = true,
  }) : _features = features;

  List<String> get features => List.unmodifiable(_features);
  bool isEnabled(String feature) => _features.contains(feature);
  bool get hasRanks => isEnabled(ranks);
  bool get hasReminders => isEnabled(reminders);

  /// Loads configuration via GET /config using the provided ApiClient.
  static Future<Features> load(ApiClient client) async {
    try {
      final config = await client.getConfig();
      return Features(
        features: config.features,
        demoMode: config.demoMode,
      );
    } catch (e) {
      debugPrint('[Features] Failed to load features from /config: $e');
      return const Features();
    }
  }
}
