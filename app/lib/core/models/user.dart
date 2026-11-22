import 'json_numbers.dart';
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
  final bool available;
  final bool consent;
  final bool canDonatePlatelets;

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
    this.available = true,
    this.consent = true,
    this.canDonatePlatelets = false,
  });

  /// Factory constructor that safely ignores any unknown/unexpected fields from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final dateRaw = json['last_donated_at'] ?? json['last_donation_date'];
    if (dateRaw != null) {
      try {
        parsedDate = DateTime.parse(dateRaw.toString());
      } catch (_) {}
    }

    final weightVal = json['weight_kg'] ?? json['weight'];
    final heightVal = json['height_cm'] ?? json['height'];

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'donor',
      bloodGroup: json['blood_group']?.toString(),
      lat: jsonDouble(json['lat']) ?? 0.0,
      lng: jsonDouble(json['lng']) ?? 0.0,
      phone: json['phone']?.toString(),
      age: jsonInt(json['age']),
      weight: jsonDouble(weightVal),
      height: jsonDouble(heightVal),
      sex: json['sex']?.toString(),
      donatedBefore: json['donated_before'] == true,
      lastDonationDate: parsedDate,
      areaName: json['area_name']?.toString(),
      available: json['available'] != false,
      consent: json['consent'] != false,
      canDonatePlatelets: (json['apheresis_ok'] ?? json['can_donate_platelets']) == true,
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
    if (weight != null) {
      map['weight'] = weight;
      map['weight_kg'] = weight;
    }
    if (height != null) {
      map['height'] = height;
      map['height_cm'] = height;
    }
    if (sex != null) map['sex'] = sex;
    map['donated_before'] = donatedBefore;
    if (lastDonationDate != null) {
      map['last_donation_date'] = lastDonationDate!.toIso8601String();
      map['last_donated_at'] = lastDonationDate!.toIso8601String();
    }
    if (areaName != null) map['area_name'] = areaName;
    map['available'] = available;
    map['consent'] = consent;
    map['can_donate_platelets'] = canDonatePlatelets;
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
    bool? available,
    bool? consent,
    bool? canDonatePlatelets,
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
      available: available ?? this.available,
      consent: consent ?? this.consent,
      canDonatePlatelets: canDonatePlatelets ?? this.canDonatePlatelets,
    );
  }
}
