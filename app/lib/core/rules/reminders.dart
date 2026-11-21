/// Pure rule functions for donor eligibility and reminders.
/// As defined in docs/API-addendum-v2.md:
/// Eligible(donor, now):
///   - age 18..65
///   - weight_kg >= 45
///   - available != false
///   - now >= last_donated_at + 90 days (male / default) / 120 days (female)
/// Unknown values count as eligible (permissive), except an explicit available=false.

const int kMaleDonationIntervalDays = 90;
const int kFemaleDonationIntervalDays = 120;

/// Checks if a donor is eligible to donate at [now] (defaults to current time).
/// Unknown/null values count as eligible (permissive), except an explicit available=false.
bool isDonorEligible({
  int? age,
  double? weightKg,
  bool? available,
  String? sex,
  DateTime? lastDonatedAt,
  DateTime? now,
}) {
  // Explicit unavailable
  if (available == false) {
    return false;
  }

  // Age 18..65 (unknown permissive)
  if (age != null && (age < 18 || age > 65)) {
    return false;
  }

  // Weight >= 45kg (unknown permissive)
  if (weightKg != null && weightKg < 45.0) {
    return false;
  }

  // Last donated at interval check (unknown permissive)
  if (lastDonatedAt != null) {
    final effectiveNow = now ?? DateTime.now();
    final intervalDays = (sex?.toLowerCase() == 'female')
        ? kFemaleDonationIntervalDays
        : kMaleDonationIntervalDays;
    final nextEligible = lastDonatedAt.add(Duration(days: intervalDays));
    if (effectiveNow.isBefore(nextEligible)) {
      return false;
    }
  }

  return true;
}

/// Calculates the next eligible donation date based on last donation date and donor sex.
/// Returns null if [lastDonatedAt] is null.
DateTime? calculateNextEligibleDate({
  DateTime? lastDonatedAt,
  String? sex,
}) {
  if (lastDonatedAt == null) return null;
  final intervalDays = (sex?.toLowerCase() == 'female')
      ? kFemaleDonationIntervalDays
      : kMaleDonationIntervalDays;
  return lastDonatedAt.add(Duration(days: intervalDays));
}

/// Calculates days elapsed since the donor's last donation date.
/// If [lastDonatedAt] is null, defaults to 90 days.
int calculateDaysSinceDonation({
  DateTime? lastDonatedAt,
  DateTime? now,
}) {
  if (lastDonatedAt == null) return kMaleDonationIntervalDays;
  final effectiveNow = now ?? DateTime.now();
  final diff = effectiveNow.difference(lastDonatedAt).inDays;
  return diff >= 0 ? diff : 0;
}
