import 'json_numbers.dart';
import 'request_urgency.dart';
import '../scaffold_messenger.dart';

class BloodRequest {
  final String id;
  final String? requesterId;
  final String bloodGroup;
  final int units;
  final String hospital;
  final String urgency;
  final String status; // 'open' | 'fulfilled' | 'cancelled'
  final String channelId;
  final DateTime? createdAt;
  final double? distanceKm;
  final String? requesterName;
  final bool joined;
  final bool donated;
  final double lat;
  final double lng;
  final String? component; // 'Whole blood' | 'Red cells' | 'Platelets' | 'Plasma' | 'Other'
  final String? notes;

  const BloodRequest({
    required this.id,
    this.requesterId,
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
    this.component,
    this.notes,
  });

  bool get isOpen => status == 'open';
  bool get isFulfilled => status == 'fulfilled';
  bool get isCancelled => status == 'cancelled';

  /// Defensively parse created_at: null or empty must not throw;
  /// surfaces any other parse error in a SnackBar.
  static DateTime? parseCreatedAt(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    if (parsed == null) {
      showParseErrorSnackBar(str);
      return null;
    }
    return parsed;
  }

  /// Factory constructor that safely ignores unknown fields
  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    return BloodRequest(
      id: json['id']?.toString() ?? '',
      requesterId: json['requester_id']?.toString(),
      bloodGroup: json['blood_group']?.toString() ?? 'O+',
      units: jsonInt(json['units']) ?? 1,
      hospital: json['hospital']?.toString() ?? '',
      urgency: RequestUrgency.parse(json['urgency']).name,
      component: json['component']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'open',
      channelId: json['channel_id']?.toString() ?? 'req${json['id'] ?? ''}',
      createdAt: parseCreatedAt(json['created_at']),
      distanceKm: jsonDouble(json['distance_km']),
      requesterName: json['requester_name']?.toString(),
      joined: json['joined'] == true,
      donated: json['donated'] == true,
      lat: jsonDouble(json['lat']) ?? 0.0,
      lng: jsonDouble(json['lng']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (requesterId != null) 'requester_id': requesterId,
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
        if (component != null) 'component': component,
        if (notes != null) 'notes': notes,
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
    String? component,
    String? notes,
  }) {
    return BloodRequest(
      id: id ?? this.id,
      requesterId: requesterId,
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
      component: component ?? this.component,
      notes: notes ?? this.notes,
    );
  }
}
