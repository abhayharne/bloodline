import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/features.dart';
import 'package:bloodline/core/rules/reminders.dart';
import 'package:bloodline/core/providers/auth_provider.dart';
import 'package:bloodline/core/providers/config_provider.dart';
import 'package:bloodline/core/providers/requests_provider.dart';
import 'package:bloodline/core/providers/bank_stock_provider.dart';
import 'package:bloodline/core/providers/notifications_provider.dart';
import 'package:bloodline/core/slots.dart';
import 'package:bloodline/features/reminders/register.dart';
import 'package:bloodline/features/home/home_screen.dart';

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

  group('Donor Eligibility & Reminders Rules', () {
    final now = DateTime(2026, 11, 22, 12, 0);

    test('isDonorEligible evaluates age correctly (18..65, unknown permissive)', () {
      expect(isDonorEligible(age: 17, now: now), isFalse);
      expect(isDonorEligible(age: 18, now: now), isTrue);
      expect(isDonorEligible(age: 30, now: now), isTrue);
      expect(isDonorEligible(age: 65, now: now), isTrue);
      expect(isDonorEligible(age: 66, now: now), isFalse);
      expect(isDonorEligible(age: null, now: now), isTrue);
    });

    test('isDonorEligible evaluates weight correctly (>= 45kg, unknown permissive)', () {
      expect(isDonorEligible(weightKg: 44.9, now: now), isFalse);
      expect(isDonorEligible(weightKg: 45.0, now: now), isTrue);
      expect(isDonorEligible(weightKg: 60.0, now: now), isTrue);
      expect(isDonorEligible(weightKg: null, now: now), isTrue);
    });

    test('isDonorEligible evaluates availability correctly (false is false, unknown permissive)', () {
      expect(isDonorEligible(available: false, now: now), isFalse);
      expect(isDonorEligible(available: true, now: now), isTrue);
      expect(isDonorEligible(available: null, now: now), isTrue);
    });

    test('isDonorEligible evaluates donation intervals (male 90 days, female 120 days)', () {
      // Male interval (90 days)
      final male89DaysAgo = now.subtract(const Duration(days: 89));
      final male90DaysAgo = now.subtract(const Duration(days: 90));
      expect(
        isDonorEligible(sex: 'male', lastDonatedAt: male89DaysAgo, now: now),
        isFalse,
      );
      expect(
        isDonorEligible(sex: 'male', lastDonatedAt: male90DaysAgo, now: now),
        isTrue,
      );

      // Female interval (120 days)
      final female119DaysAgo = now.subtract(const Duration(days: 119));
      final female120DaysAgo = now.subtract(const Duration(days: 120));
      expect(
        isDonorEligible(sex: 'female', lastDonatedAt: female119DaysAgo, now: now),
        isFalse,
      );
      expect(
        isDonorEligible(sex: 'female', lastDonatedAt: female120DaysAgo, now: now),
        isTrue,
      );
    });

    test('calculateNextEligibleDate returns correct date for male/female', () {
      final lastDonated = DateTime(2026, 1, 1);
      expect(
        calculateNextEligibleDate(lastDonatedAt: lastDonated, sex: 'male'),
        DateTime(2026, 1, 1).add(const Duration(days: 90)),
      );
      expect(
        calculateNextEligibleDate(lastDonatedAt: lastDonated, sex: 'female'),
        DateTime(2026, 1, 1).add(const Duration(days: 120)),
      );
      expect(calculateNextEligibleDate(lastDonatedAt: null), isNull);
    });

    test('calculateDaysSinceDonation calculates elapsed recharge days', () {
      final lastDonated = now.subtract(const Duration(days: 45));
      expect(
        calculateDaysSinceDonation(lastDonatedAt: lastDonated, now: now),
        45,
      );
      expect(calculateDaysSinceDonation(lastDonatedAt: null), 90);
    });
  });

  group('Reminders Feature Slot Registration', () {
    test('Does NOT register slots when features does NOT contain reminders', () {
      expect(SlotRegistry.instance.homeCards, isEmpty);

      registerRemindersFeature(features: const Features(features: ['ranks']));
      expect(SlotRegistry.instance.homeCards, isEmpty);

      registerRemindersFeature(config: const AppConfig(features: []));
      expect(SlotRegistry.instance.homeCards, isEmpty);
    });

    test('Registers homeCard when features contains reminders', () {
      expect(SlotRegistry.instance.homeCards, isEmpty);

      registerRemindersFeature(features: const Features(features: ['reminders']));
      expect(SlotRegistry.instance.homeCards.length, 1);

      // Verify idempotency (no duplicate registration)
      registerRemindersFeature(features: const Features(features: ['reminders']));
      expect(SlotRegistry.instance.homeCards.length, 1);
    });
  });

  group('Reminders Widgets', () {
    testWidgets('RemindersHomeCard renders "You may be eligible again" when eligible',
        (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          const Scaffold(
            body: RemindersHomeCard(
              eligible: true,
              rechargeDays: 95,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminders_home_card')), findsOneWidget);
      expect(find.text('You may be eligible again'), findsOneWidget);
      expect(
        find.text(
          'Your blood has had 95 days to recharge. Ready to be somebody\'s hero again?',
        ),
        findsOneWidget,
      );
      expect(find.text("I'm ready"), findsOneWidget);
      expect(find.text('Remind me later'), findsOneWidget);
    });

    testWidgets('RemindersHomeCard renders recharging pause state when eligible is false',
        (tester) async {
      final nextDate = DateTime(2026, 12, 15);
      await tester.pumpWidget(
        _createTestApp(
          Scaffold(
            body: RemindersHomeCard(
              eligible: false,
              nextEligibleAt: nextDate,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminders_home_card')), findsOneWidget);
      expect(find.text('Resting & recharging'), findsOneWidget);
      expect(find.textContaining('Next eligible on 15 Dec 2026'), findsOneWidget);
    });

    testWidgets('RemindersHomeCard snooze button hides card and displays warm SnackBar',
        (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          const Scaffold(
            body: RemindersHomeCard(
              eligible: true,
              rechargeDays: 90,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminders_home_card')), findsOneWidget);

      // Tap "Remind me later"
      await tester.tap(find.byKey(const Key('reminders_home_card_snooze')));
      await tester.pumpAndSettle();

      // Card should be snoozed (hidden)
      expect(find.byKey(const Key('reminders_home_card')), findsNothing);
      expect(
        find.text("No pressure. We'll check back next month."),
        findsOneWidget,
      );
    });

    testWidgets('HomeScreen renders RemindersHomeCard via slots when feature reminders is enabled',
        (tester) async {
      final client = ApiClient(mockMode: true);
      final auth = AuthProvider(apiClient: client);
      await auth.login(name: 'Rahul', role: 'donor');
      await auth.fetchMe();

      registerRemindersFeature(features: const Features(features: ['reminders']));

      await tester.pumpWidget(
        _createTestApp(
          const HomeScreen(),
          apiClient: client,
          authProvider: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminders_home_card')), findsOneWidget);
      expect(find.text('You may be eligible again'), findsOneWidget);
    });

    testWidgets('HomeScreen does NOT render RemindersHomeCard when feature reminders is disabled',
        (tester) async {
      final client = ApiClient(mockMode: true);
      final auth = AuthProvider(apiClient: client);
      await auth.login(name: 'Rahul', role: 'donor');
      await auth.fetchMe();

      // No reminders registration
      await tester.pumpWidget(
        _createTestApp(
          const HomeScreen(),
          apiClient: client,
          authProvider: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminders_home_card')), findsNothing);
    });
  });
}
