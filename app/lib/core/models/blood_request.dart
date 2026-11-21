class BloodRequest {
  final String id;
  final String bloodGroup;
  final int units;
  final String hospital;
  final String urgency; // 'low' | 'medium' | 'high' | 'critical'
  final String status; // 'open' | 'fulfilled' | 'cancelled'
  final String channelId;
  final DateTime? createdAt;
  final double? distanceKm;
  final String? requesterName;
  final bool joined;
  final bool donated;
  final double lat;
  final double lng;

  const BloodRequest({
    required this.id,
    required this.bloodGroup,
    required this.units,
    required this.hospital,
    required this.urgency,
    required this.status,
    required this.channelId,
    this.createdAt,
    this.distanceKm,
    this.requesterName,
    this.joined = false,
    this.donated = false,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  bool get isOpen => status == 'open';
  bool get isFulfilled => status == 'fulfilled';
  bool get isCancelled => status == 'cancelled';

  /// Factory constructor that safely ignores unknown fields
  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    if (json['created_at'] != null) {
      try {
        created = DateTime.parse(json['created_at'].toString());
      } catch (_) {}
    }

    return BloodRequest(
      id: json['id']?.toString() ?? '',
      bloodGroup: json['blood_group']?.toString() ?? 'O+',
      units: (json['units'] as num?)?.toInt() ?? 1,
      hospital: json['hospital']?.toString() ?? '',
      urgency: json['urgency']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'open',
      channelId: json['channel_id']?.toString() ?? 'req${json['id'] ?? ''}',
      createdAt: created,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      requesterName: json['requester_name']?.toString(),
      joined: json['joined'] == true,
      donated: json['donated'] == true,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'blood_group': bloodGroup,
        'units': units,
        'hospital': hospital,
        'urgency': urgency,
        'status': status,
        'channel_id': channelId,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (distanceKm != null) 'distance_km': distanceKm,
        if (requesterName != null) 'requester_name': requesterName,
        'joined': joined,
        'donated': donated,
        'lat': lat,
        'lng': lng,
      };

  BloodRequest copyWith({
    String? id,
    String? bloodGroup,
    int? units,
    String? hospital,
    String? urgency,
    String? status,
    String? channelId,
    DateTime? createdAt,
    double? distanceKm,
    String? requesterName,
    bool? joined,
    bool? donated,
    double? lat,
    double? lng,
  }) {
    return BloodRequest(
      id: id ?? this.id,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      units: units ?? this.units,
      hospital: hospital ?? this.hospital,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      channelId: channelId ?? this.channelId,
      createdAt: createdAt ?? this.createdAt,
      distanceKm: distanceKm ?? this.distanceKm,
      requesterName: requesterName ?? this.requesterName,
      joined: joined ?? this.joined,
      donated: donated ?? this.donated,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }
}
