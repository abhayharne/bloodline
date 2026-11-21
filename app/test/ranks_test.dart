import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/features.dart';
import 'package:bloodline/core/models/user_derived.dart';
import 'package:bloodline/core/rules/ranks.dart';
import 'package:bloodline/core/providers/auth_provider.dart';
import 'package:bloodline/core/providers/config_provider.dart';
import 'package:bloodline/core/providers/requests_provider.dart';
import 'package:bloodline/core/providers/bank_stock_provider.dart';
import 'package:bloodline/core/providers/notifications_provider.dart';
import 'package:bloodline/core/slots.dart';
import 'package:bloodline/features/ranks/register.dart';
import 'package:bloodline/features/home/home_screen.dart';
import 'package:bloodline/features/auth/profile_screen.dart';

Widget _createTestApp(
  Widget child, {
  ApiClient? apiClient,
  AuthProvider? authProvider,
  ConfigProvider? configProvider,
}) {
  final client = apiClient ?? ApiClient(mockMode: true);
  final auth = authProvider ?? AuthProvider(apiClient: client);
  final config = configProvider ?? ConfigProvider(apiClient: client);

  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: client),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<ConfigProvider>.value(value: config),
      ChangeNotifierProvider<RequestsProvider>(
        create: (_) => RequestsProvider(apiClient: client),
      ),
      ChangeNotifierProvider<BankStockProvider>(
        create: (_) => BankStockProvider(apiClient: client),
      ),
      ChangeNotifierProvider<NotificationsProvider>(
        create: (_) => NotificationsProvider(apiClient: client),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SlotRegistry.instance.clear();
  });

  tearDown(() {
    SlotRegistry.instance.clear();
  });

  group('UserRank & Rules', () {
    test('calculateRank and UserRank.fromDonationCount map milestones correctly', () {
      expect(calculateRank(0), isNull);
      expect(UserRank.fromDonationCount(0), isNull);

      expect(calculateRank(1)?.label, 'First Drop');
      expect(calculateRank(1)?.key, 'first_drop');
      expect(UserRank.fromDonationCount(1)?.label, 'First Drop');

      expect(calculateRank(2)?.label, 'First Drop');
      expect(UserRank.fromDonationCount(2)?.label, 'First Drop');

      expect(calculateRank(3)?.label, 'Helper');
      expect(calculateRank(3)?.key, 'helper');
      expect(UserRank.fromDonationCount(3)?.label, 'Helper');

      expect(calculateRank(4)?.label, 'Helper');
      expect(UserRank.fromDonationCount(4)?.label, 'Helper');

      expect(calculateRank(5)?.label, 'Silver Lifeline');
      expect(calculateRank(5)?.key, 'silver_lifeline');
      expect(UserRank.fromDonationCount(5)?.label, 'Silver Lifeline');

      expect(calculateRank(9)?.label, 'Silver Lifeline');
      expect(UserRank.fromDonationCount(9)?.label, 'Silver Lifeline');

      expect(calculateRank(10)?.label, 'Gold Lifeline');
      expect(calculateRank(10)?.key, 'gold_lifeline');
      expect(UserRank.fromDonationCount(10)?.label, 'Gold Lifeline');

      expect(calculateRank(24)?.label, 'Gold Lifeline');
      expect(UserRank.fromDonationCount(24)?.label, 'Gold Lifeline');

      expect(calculateRank(25)?.label, 'Lifesaver');
      expect(calculateRank(25)?.key, 'lifesaver');
      expect(UserRank.fromDonationCount(25)?.label, 'Lifesaver');

      expect(calculateRank(100)?.label, 'Lifesaver');
      expect(UserRank.fromDonationCount(100)?.label, 'Lifesaver');
    });

    test('getNextRank calculates next milestones accurately', () {
      expect(getNextRank(0)?.label, 'First Drop');
      expect(getNextRank(1)?.label, 'Helper');
      expect(getNextRank(2)?.label, 'Helper');
      expect(getNextRank(3)?.label, 'Silver Lifeline');
      expect(getNextRank(5)?.label, 'Gold Lifeline');
      expect(getNextRank(10)?.label, 'Lifesaver');
      expect(getNextRank(25), isNull);
    });
  });

  group('Ranks Feature Slot Registration', () {
    test('Does NOT register slots when features does NOT contain ranks', () {
      expect(SlotRegistry.instance.homeCards, isEmpty);
      expect(SlotRegistry.instance.profileSections, isEmpty);

      registerRanksFeature(features: const Features(features: ['reminders']));
      expect(SlotRegistry.instance.homeCards, isEmpty);
      expect(SlotRegistry.instance.profileSections, isEmpty);

      registerRanksFeature(config: const AppConfig(features: []));
      expect(SlotRegistry.instance.homeCards, isEmpty);
      expect(SlotRegistry.instance.profileSections, isEmpty);
    });

    test('Registers slots when features contains ranks', () {
      expect(SlotRegistry.instance.homeCards, isEmpty);
      expect(SlotRegistry.instance.profileSections, isEmpty);

      registerRanksFeature(features: const Features(features: ['ranks']));
      expect(SlotRegistry.instance.homeCards.length, 1);
      expect(SlotRegistry.instance.profileSections.length, 1);

      // Verify idempotency (no duplicates on repeat call)
      registerRanksFeature(features: const Features(features: ['ranks']));
      expect(SlotRegistry.instance.homeCards.length, 1);
      expect(SlotRegistry.instance.profileSections.length, 1);
    });
  });

  group('Ranks Widgets', () {
    testWidgets('RanksHomeCard renders "{n} donations, {rank}" text correctly',
        (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          const Scaffold(
            body: RanksHomeCard(
              donationCount: 3,
              rankLabel: 'Helper',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranks_home_card')), findsOneWidget);
      expect(find.text('3 donations, Helper'), findsOneWidget);
    });

    testWidgets('RanksProfileSection renders rank badge and milestone list',
        (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          const Scaffold(
            body: RanksProfileSection(
              donationCount: 5,
              rankLabel: 'Silver Lifeline',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranks_profile_section')), findsOneWidget);
      expect(find.text('Donor Rank & Badges'), findsOneWidget);
      expect(find.text('Silver Lifeline'), findsOneWidget);
      expect(find.text('5 lifetime donations completed'), findsOneWidget);
      expect(find.text('First Drop (1)'), findsOneWidget);
      expect(find.text('Helper (3)'), findsOneWidget);
      expect(find.text('Silver Lifeline (5)'), findsOneWidget);
      expect(find.text('Gold Lifeline (10)'), findsOneWidget);
      expect(find.text('Lifesaver (25)'), findsOneWidget);
    });

    testWidgets('HomeScreen renders RanksHomeCard via slots when feature ranks is enabled',
        (tester) async {
      final client = ApiClient(mockMode: true);
      final auth = AuthProvider(apiClient: client);
      await auth.login(name: 'Asha', role: 'donor');
      await auth.fetchMe();

      registerRanksFeature(features: const Features(features: ['ranks']));

      await tester.pumpWidget(
        _createTestApp(
          const HomeScreen(),
          apiClient: client,
          authProvider: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranks_home_card')), findsOneWidget);
      expect(find.text('3 donations, Helper'), findsOneWidget);
    });

    testWidgets('HomeScreen does NOT render RanksHomeCard when feature ranks is disabled',
        (tester) async {
      final client = ApiClient(mockMode: true);
      final auth = AuthProvider(apiClient: client);
      await auth.login(name: 'Asha', role: 'donor');
      await auth.fetchMe();

      // No ranks registration (SlotRegistry empty)
      await tester.pumpWidget(
        _createTestApp(
          const HomeScreen(),
          apiClient: client,
          authProvider: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranks_home_card')), findsNothing);
    });

    testWidgets('ProfileScreen renders RanksProfileSection via slots when feature ranks is enabled',
        (tester) async {
      final client = ApiClient(mockMode: true);
      final auth = AuthProvider(apiClient: client);
      await auth.login(name: 'Asha', role: 'donor');
      await auth.fetchMe();

      registerRanksFeature(features: const Features(features: ['ranks']));

      await tester.pumpWidget(
        _createTestApp(
          const ProfileScreen(),
          apiClient: client,
          authProvider: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ranks_profile_section')), findsOneWidget);
      expect(find.text('Donor Rank & Badges'), findsOneWidget);
    });
  });
}
