import 'json_numbers.dart';
class UserRank {
  final String key;
  final String label;

  const UserRank({required this.key, required this.label});

  factory UserRank.fromJson(Map<String, dynamic> json) {
    return UserRank(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
      };

  /// Computes rank by donation count according to docs/API-addendum-v2.md:
  /// 1 "First Drop", 3 "Helper", 5 "Silver Lifeline", 10 "Gold Lifeline", 25 "Lifesaver".
  static UserRank? fromDonationCount(int count) {
    if (count >= 25) {
      return const UserRank(key: 'lifesaver', label: 'Lifesaver');
    } else if (count >= 10) {
      return const UserRank(key: 'gold_lifeline', label: 'Gold Lifeline');
    } else if (count >= 5) {
      return const UserRank(key: 'silver_lifeline', label: 'Silver Lifeline');
    } else if (count >= 3) {
      return const UserRank(key: 'helper', label: 'Helper');
    } else if (count >= 1) {
      return const UserRank(key: 'first_drop', label: 'First Drop');
    }
    return null;
  }
}

class UserDerived {
  final bool eligible;
  final DateTime? nextEligibleAt;
  final int donationCount;
  final UserRank? rank;

  const UserDerived({
    this.eligible = true,
    this.nextEligibleAt,
    this.donationCount = 0,
    this.rank,
  });

  factory UserDerived.fromJson(Map<String, dynamic> json) {
    DateTime? nextDate;
    if (json['next_eligible_at'] != null) {
      try {
        nextDate = DateTime.parse(json['next_eligible_at'].toString());
      } catch (_) {}
    }

    UserRank? rank;
    if (json['rank'] is Map<String, dynamic>) {
      rank = UserRank.fromJson(json['rank'] as Map<String, dynamic>);
    } else if (json['rank'] is Map) {
      rank = UserRank.fromJson(Map<String, dynamic>.from(json['rank'] as Map));
    }

    final count = jsonInt(json['donation_count']) ?? 0;
    rank ??= UserRank.fromDonationCount(count);

    return UserDerived(
      eligible: json['eligible'] != false,
      nextEligibleAt: nextDate,
      donationCount: count,
      rank: rank,
    );
  }

  Map<String, dynamic> toJson() => {
        'eligible': eligible,
        'next_eligible_at': nextEligibleAt?.toIso8601String(),
        'donation_count': donationCount,
        'rank': rank?.toJson(),
      };

  UserDerived copyWith({
    bool? eligible,
    DateTime? nextEligibleAt,
    int? donationCount,
    UserRank? rank,
  }) {
    return UserDerived(
      eligible: eligible ?? this.eligible,
      nextEligibleAt: nextEligibleAt ?? this.nextEligibleAt,
      donationCount: donationCount ?? this.donationCount,
      rank: rank ?? this.rank,
    );
  }
}
