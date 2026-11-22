import 'package:flutter_test/flutter_test.dart';
import 'package:bloodline/core/models/user.dart';
import 'package:bloodline/core/rules/eligibility.dart';

void main() {
  group('Eligibility Rules (docs/API-addendum-v2.md)', () {
    final now = DateTime(2026, 11, 22, 10, 0);

    test('Permissive default: unknown/null values count as eligible when available=true', () {
      const user = User(
        id: 'u1',
        name: 'Alex',
        role: 'donor',
        available: true,
      );
      final result = checkEligibility(user, now);
      expect(result.isEligible, isTrue);
      expect(result.reason, isNull);
    });

    test('Explicit available=false makes user ineligible', () {
      const user = User(
        id: 'u1',
        name: 'Alex',
        role: 'donor',
        available: false,
      );
      final result = checkEligibility(user, now);
      expect(result.isEligible, isFalse);
      expect(result.reason, contains('unavailable'));
    });

    test('Age restriction: 18..65 boundary checks', () {
      const underage = User(id: 'u1', name: 'Alex', role: 'donor', age: 17);
      expect(checkEligibility(underage, now).isEligible, isFalse);

      const minAge = User(id: 'u1', name: 'Alex', role: 'donor', age: 18);
      expect(checkEligibility(minAge, now).isEligible, isTrue);

      const maxAge = User(id: 'u1', name: 'Alex', role: 'donor', age: 65);
      expect(checkEligibility(maxAge, now).isEligible, isTrue);

      const overAge = User(id: 'u1', name: 'Alex', role: 'donor', age: 66);
      expect(checkEligibility(overAge, now).isEligible, isFalse);
    });

    test('Weight restriction: minimum 45 kg required', () {
      const underweight = User(id: 'u1', name: 'Alex', role: 'donor', weight: 44.9);
      expect(checkEligibility(underweight, now).isEligible, isFalse);

      const minWeight = User(id: 'u1', name: 'Alex', role: 'donor', weight: 45.0);
      expect(checkEligibility(minWeight, now).isEligible, isTrue);

      const goodWeight = User(id: 'u1', name: 'Alex', role: 'donor', weight: 65.0);
      expect(checkEligibility(goodWeight, now).isEligible, isTrue);
    });

    test('Male cooldown: 90 days after last donation', () {
      // 89 days ago -> ineligible
      final male89d = User(
        id: 'u1',
        name: 'Rohan',
        role: 'donor',
        sex: 'male',
        lastDonationDate: now.subtract(const Duration(days: 89)),
      );
      final result89 = checkEligibility(male89d, now);
      expect(result89.isEligible, isFalse);
      expect(result89.daysRemaining, 1);

      // 90 days ago -> eligible
      final male90d = User(
        id: 'u1',
        name: 'Rohan',
        role: 'donor',
        sex: 'male',
        lastDonationDate: now.subtract(const Duration(days: 90)),
      );
      expect(checkEligibility(male90d, now).isEligible, isTrue);
    });

    test('Female cooldown: 120 days after last donation', () {
      // 119 days ago -> ineligible
      final female119d = User(
        id: 'u1',
        name: 'Priya',
        role: 'donor',
        sex: 'female',
        lastDonationDate: now.subtract(const Duration(days: 119)),
      );
      final result119 = checkEligibility(female119d, now);
      expect(result119.isEligible, isFalse);
      expect(result119.daysRemaining, 1);

      // 120 days ago -> eligible
      final female120d = User(
        id: 'u1',
        name: 'Priya',
        role: 'donor',
        sex: 'female',
        lastDonationDate: now.subtract(const Duration(days: 120)),
      );
      expect(checkEligibility(female120d, now).isEligible, isTrue);
    });

    test('calculateNextEligibleAt computes +90d for male and +120d for female', () {
      final donationDate = DateTime(2026, 1, 1);
      final male = User(
        id: 'u1',
        name: 'A',
        role: 'donor',
        sex: 'male',
        lastDonationDate: donationDate,
      );
      final female = User(
        id: 'u2',
        name: 'B',
        role: 'donor',
        sex: 'female',
        lastDonationDate: donationDate,
      );
      final noDate = const User(id: 'u3', name: 'C', role: 'donor');

      expect(calculateNextEligibleAt(male), donationDate.add(const Duration(days: 90)));
      expect(calculateNextEligibleAt(female), donationDate.add(const Duration(days: 120)));
      expect(calculateNextEligibleAt(noDate), isNull);
    });
  });
}
