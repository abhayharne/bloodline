import '../models/user.dart';

/// Pure rule functions for donor eligibility as defined in docs/API-addendum-v2.md:
/// - Eligible(donor, now):
///   - age 18..65
///   - weight_kg >= 45
///   - available (explicit available=false makes ineligible)
///   - now >= last_donated_at + 90 days (male) / 120 days (female)
/// - Unknown values count as eligible (permissive), except an explicit available=false.
class EligibilityResult {
  final bool isEligible;
  final String? reason;
  final DateTime? nextEligibleAt;
  final int? daysRemaining;

  const EligibilityResult({
    required this.isEligible,
    this.reason,
    this.nextEligibleAt,
    this.daysRemaining,
  });
}

/// Checks whether a [user] is eligible to donate blood at [now] (defaults to current time).
EligibilityResult checkEligibility(User user, [DateTime? now]) {
  final current = now ?? DateTime.now();

  // Explicit available=false
  if (!user.available) {
    return const EligibilityResult(
      isEligible: false,
      reason: 'Donor marked as currently unavailable',
    );
  }

  // Age restriction: 18..65
  if (user.age != null) {
    if (user.age! < 18) {
      return const EligibilityResult(
        isEligible: false,
        reason: 'Must be at least 18 years old to donate',
      );
    }
    if (user.age! > 65) {
      return const EligibilityResult(
        isEligible: false,
        reason: 'Maximum eligible age for donation is 65',
      );
    }
  }

  // Weight restriction: >= 45 kg
  if (user.weight != null && user.weight! < 45.0) {
    return const EligibilityResult(
      isEligible: false,
      reason: 'Minimum weight of 45 kg required to donate',
    );
  }

  // Cooldown check: 90 days (male) / 120 days (female)
  if (user.lastDonationDate != null) {
    final isFemale = user.sex?.toLowerCase() == 'female';
    final cooldownDays = isFemale ? 120 : 90;
    final nextEligible = user.lastDonationDate!.add(Duration(days: cooldownDays));

    if (current.isBefore(nextEligible)) {
      final diff = nextEligible.difference(current);
      final daysLeft = diff.inSeconds <= 0 ? 0 : (diff.inSeconds / 86400).ceil();
      return EligibilityResult(
        isEligible: false,
        reason: 'Cooldown period active: $daysLeft days remaining',
        nextEligibleAt: nextEligible,
        daysRemaining: daysLeft,
      );
    }
  }

  return const EligibilityResult(isEligible: true);
}

/// Calculates the next eligible donation date for a user based on their last donation.
DateTime? calculateNextEligibleAt(User user) {
  if (user.lastDonationDate == null) return null;
  final isFemale = user.sex?.toLowerCase() == 'female';
  final cooldownDays = isFemale ? 120 : 90;
  return user.lastDonationDate!.add(Duration(days: cooldownDays));
}
