import 'json_numbers.dart';
class AppConfig {
  final String appName;
  final bool enableAiSummary;
  final bool enableInAppBanner;
  final double defaultMatchRadiusKm;
  final List<String> features;
  final bool demoMode;

  const AppConfig({
    this.appName = 'BloodLine',
    this.enableAiSummary = false,
    this.enableInAppBanner = true,
    this.defaultMatchRadiusKm = 10.0,
    this.features = const [],
    this.demoMode = true,
  });

  bool hasFeature(String feature) => features.contains(feature);

  List<String> get featuresList => features;

  /// Factory constructor that safely ignores unknown fields
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    List<String> featList = const [];

    if (json['features'] is List) {
      featList = (json['features'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['features'] is Map) {
      featList = (json['features'] as Map)
          .entries
          .where((e) => e.value == true)
          .map((e) => e.key.toString())
          .toList();
    }

    return AppConfig(
      appName: json['app_name']?.toString() ?? 'BloodLine',
      enableAiSummary: json['enable_ai_summary'] == true,
      enableInAppBanner: json['enable_in_app_banner'] ?? true,
      defaultMatchRadiusKm:
          jsonDouble(json['default_match_radius_km']) ?? 10.0,
      features: featList,
      demoMode: json['demo_mode'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'app_name': appName,
        'enable_ai_summary': enableAiSummary,
        'enable_in_app_banner': enableInAppBanner,
        'default_match_radius_km': defaultMatchRadiusKm,
        'features': features,
        'demo_mode': demoMode,
      };
}
