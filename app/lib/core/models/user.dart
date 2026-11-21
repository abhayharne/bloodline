class User {
  final String id;
  final String name;
  final String role; // 'requester' | 'donor' | 'bank'
  final String? bloodGroup; // 'O+', 'O-', 'A+', etc. (requester & donor)
  final double lat;
  final double lng;
  final String? phone;
  final int? age;
  final double? weight;
  final double? height;
  final String? sex; // 'male' | 'female' | 'other'
  final bool donatedBefore;
  final DateTime? lastDonationDate;
  final String? areaName;

  const User({
    required this.id,
    required this.name,
    required this.role,
    this.bloodGroup,
    this.lat = 0.0,
    this.lng = 0.0,
    this.phone,
    this.age,
    this.weight,
    this.height,
    this.sex,
    this.donatedBefore = false,
    this.lastDonationDate,
    this.areaName,
  });

  /// Factory constructor that safely ignores any unknown/unexpected fields from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['last_donation_date'] != null) {
      try {
        parsedDate = DateTime.parse(json['last_donation_date'].toString());
      } catch (_) {}
    }

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'donor',
      bloodGroup: json['blood_group']?.toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      phone: json['phone']?.toString(),
      age: (json['age'] as num?)?.toInt(),
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      sex: json['sex']?.toString(),
      donatedBefore: json['donated_before'] == true,
      lastDonationDate: parsedDate,
      areaName: json['area_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'role': role,
      'lat': lat,
      'lng': lng,
    };
    if (bloodGroup != null) map['blood_group'] = bloodGroup;
    if (phone != null) map['phone'] = phone;
    if (age != null) map['age'] = age;
    if (weight != null) map['weight'] = weight;
    if (height != null) map['height'] = height;
    if (sex != null) map['sex'] = sex;
    map['donated_before'] = donatedBefore;
    if (lastDonationDate != null) {
      map['last_donation_date'] = lastDonationDate!.toIso8601String();
    }
    if (areaName != null) map['area_name'] = areaName;
    return map;
  }

  User copyWith({
    String? id,
    String? name,
    String? role,
    String? bloodGroup,
    double? lat,
    double? lng,
    String? phone,
    int? age,
    double? weight,
    double? height,
    String? sex,
    bool? donatedBefore,
    DateTime? lastDonationDate,
    String? areaName,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      sex: sex ?? this.sex,
      donatedBefore: donatedBefore ?? this.donatedBefore,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      areaName: areaName ?? this.areaName,
    );
  }
}
