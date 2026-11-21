class BloodStockItem {
  final String bloodGroup;
  final int units;
  final DateTime? updatedAt;

  const BloodStockItem({
    required this.bloodGroup,
    required this.units,
    this.updatedAt,
  });

  /// Factory constructor that safely ignores unknown fields
  factory BloodStockItem.fromJson(Map<String, dynamic> json) {
    DateTime? updated;
    if (json['updated_at'] != null) {
      try {
        updated = DateTime.parse(json['updated_at'].toString());
      } catch (_) {}
    }

    return BloodStockItem(
      bloodGroup: json['blood_group']?.toString() ?? '',
      units: (json['units'] as num?)?.toInt() ?? 0,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() => {
        'blood_group': bloodGroup,
        'units': units,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  BloodStockItem copyWith({
    String? bloodGroup,
    int? units,
    DateTime? updatedAt,
  }) {
    return BloodStockItem(
      bloodGroup: bloodGroup ?? this.bloodGroup,
      units: units ?? this.units,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
