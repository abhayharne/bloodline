import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloodline/core/slot_registry.dart';

void main() {
  group('SlotRegistry', () {
    setUp(() {
      SlotRegistry.instance.clear();
    });

    tearDown(() {
      SlotRegistry.instance.clear();
    });

    test('Registry is empty in the core build by default', () {
      expect(SlotRegistry.instance.homeCards, isEmpty);
      expect(SlotRegistry.instance.profileSections, isEmpty);
      expect(SlotRegistry.instance.roomHeaderBadges, isEmpty);
    });

    test('Allows extensions to register homeCards, profileSections, and roomHeaderBadges', () {
      SlotRegistry.instance.registerHomeCard(
        (context) => const Text('Custom Extension Card'),
      );
      SlotRegistry.instance.registerProfileSection(
        (context) => const Text('Custom Medical History Section'),
      );
      SlotRegistry.instance.registerRoomHeaderBadge(
        (context, req) => Text('Badge for ${req.bloodGroup}'),
      );

      expect(SlotRegistry.instance.homeCards.length, 1);
      expect(SlotRegistry.instance.profileSections.length, 1);
      expect(SlotRegistry.instance.roomHeaderBadges.length, 1);

      // Verify clear works
      SlotRegistry.instance.clear();
      expect(SlotRegistry.instance.homeCards, isEmpty);
      expect(SlotRegistry.instance.profileSections, isEmpty);
      expect(SlotRegistry.instance.roomHeaderBadges, isEmpty);
    });
  });
}
