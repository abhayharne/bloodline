class AppConfig {
  final String appName;
  final bool enableAiSummary;
  final bool enableInAppBanner;
  final double defaultMatchRadiusKm;
  final Map<String, dynamic> features;

  const AppConfig({
    this.appName = 'BloodLine',
    this.enableAiSummary = false,
    this.enableInAppBanner = true,
    this.defaultMatchRadiusKm = 10.0,
    this.features = const {},
  });

  /// Factory constructor that safely ignores unknown fields
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final featuresMap = json['features'] is Map<String, dynamic>
        ? json['features'] as Map<String, dynamic>
        : <String, dynamic>{};

    return AppConfig(
      appName: json['app_name']?.toString() ?? 'BloodLine',
      enableAiSummary: json['enable_ai_summary'] == true,
      enableInAppBanner: json['enable_in_app_banner'] ?? true,
      defaultMatchRadiusKm: (json['default_match_radius_km'] as num?)?.toDouble() ?? 10.0,
      features: featuresMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'app_name': appName,
        'enable_ai_summary': enableAiSummary,
        'enable_in_app_banner': enableInAppBanner,
        'default_match_radius_km': defaultMatchRadiusKm,
        'features': features,
      };
}
