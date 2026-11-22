enum RequestUrgency {
  critical,
  high,
  medium,
  low;

  String get label => name[0].toUpperCase() + name.substring(1);

  static RequestUrgency parse(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'critical' => critical,
      'high' || 'urgent' => high,
      'medium' || 'med' => medium,
      _ => low,
    };
  }
}
