import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/providers/auth_provider.dart';
import 'package:bloodline/core/providers/requests_provider.dart';
import 'package:bloodline/core/providers/bank_stock_provider.dart';
import 'package:bloodline/core/providers/notifications_provider.dart';
import 'package:bloodline/core/providers/settings_provider.dart';
import 'package:bloodline/features/settings/settings_screen.dart';
import 'package:bloodline/features/home/home_screen.dart';
import 'package:bloodline/features/auth/profile_screen.dart';
import 'package:bloodline/core/models/user.dart';

Widget createSettingsTestApp({
  required Widget child,
  SettingsProvider? settingsProvider,
  AuthProvider? authProvider,
}) {
  final apiClient = ApiClient(mockMode: true);
  final auth = authProvider ?? AuthProvider(apiClient: apiClient);
  final settings = settingsProvider ?? SettingsProvider();
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<RequestsProvider>(
        create: (_) => RequestsProvider(apiClient: apiClient),
      ),
      ChangeNotifierProvider<BankStockProvider>(
        create: (_) => BankStockProvider(apiClient: apiClient),
      ),
      ChangeNotifierProvider<NotificationsProvider>(
        create: (_) => NotificationsProvider(apiClient: apiClient),
      ),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: Consumer<SettingsProvider>(
      builder: (context, s, _) {
        return MaterialApp(
          builder: (context, c) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: s.textScaler,
              ),
              child: c ?? const SizedBox.shrink(),
            );
          },
          home: child,
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider Unit Tests', () {
    test('Default values: standard scale 1.0, isLargeFont is false', () {
      final provider = SettingsProvider();
      expect(provider.isLargeFont, isFalse);
      expect(provider.textScaleFactor, 1.0);
      expect(provider.textScaler, const TextScaler.linear(1.0));
      expect(provider.isVoiceToTextSupported, isFalse);
      expect(provider.voiceToTextStatus, contains('platform-specific'));
    });

    test('setLargeFont(true) updates textScaler to linear(1.3)', () async {
      final provider = SettingsProvider();
      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.setLargeFont(true);
      expect(provider.isLargeFont, isTrue);
      expect(provider.textScaleFactor, 1.3);
      expect(provider.textScaler, const TextScaler.linear(1.3));
      expect(notified, isTrue);
    });

    test('toggleLargeFont flips between standard and large font', () async {
      final provider = SettingsProvider();
      expect(provider.isLargeFont, isFalse);

      await provider.toggleLargeFont();
      expect(provider.isLargeFont, isTrue);
      expect(provider.textScaler, const TextScaler.linear(1.3));

      await provider.toggleLargeFont();
      expect(provider.isLargeFont, isFalse);
      expect(provider.textScaler, const TextScaler.linear(1.0));
    });

    test('SharedPreferences persistence loads saved value', () async {
      SharedPreferences.setMockInitialValues({'bloodline_large_font': true});
      final provider = SettingsProvider();
      await provider.load();

      expect(provider.isLargeFont, isTrue);
      expect(provider.textScaleFactor, 1.3);
      expect(provider.textScaler, const TextScaler.linear(1.3));
    });
  });

  group('SettingsScreen Widget Tests', () {
    testWidgets('Renders Settings & Accessibility screen elements', (tester) async {
      final provider = SettingsProvider();
      await tester.pumpWidget(createSettingsTestApp(
        child: const SettingsScreen(),
        settingsProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Settings & Accessibility'), findsOneWidget);
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('Large Text (1.3x)'), findsOneWidget);
      expect(find.byKey(const Key('large_font_switch')), findsOneWidget);
      expect(find.byKey(const Key('voice_to_text_tile')), findsOneWidget);
      expect(find.text('Setup Required'), findsOneWidget);
      expect(find.text('Legibility Preview (1.0x)'), findsOneWidget);
    });

    testWidgets('Toggling switch updates SettingsProvider and preview text', (tester) async {
      final provider = SettingsProvider();
      await tester.pumpWidget(createSettingsTestApp(
        child: const SettingsScreen(),
        settingsProvider: provider,
      ));
      await tester.pumpAndSettle();

      expect(provider.isLargeFont, isFalse);
      expect(find.text('Legibility Preview (1.0x)'), findsOneWidget);

      // Tap the switch
      await tester.tap(find.byKey(const Key('large_font_switch')));
      await tester.pumpAndSettle();

      expect(provider.isLargeFont, isTrue);
      expect(find.text('Legibility Preview (1.3x)'), findsOneWidget);
      expect(find.textContaining('Large text mode is active.'), findsOneWidget);
    });

    testWidgets('Voice to Text tap shows explanatory SnackBar', (tester) async {
      final provider = SettingsProvider();
      await tester.pumpWidget(createSettingsTestApp(
        child: const SettingsScreen(),
        settingsProvider: provider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('voice_to_text_tile')));
      await tester.pumpAndSettle();

      expect(
        find.text('Voice-to-text requires microphone permissions and native platform speech services.'),
        findsOneWidget,
      );
    });
  });

  group('Accessibility textScaler App Tree Integration', () {
    testWidgets('TextScaler propagates to widget tree MediaQuery', (tester) async {
      late BuildContext capturedContext;
      final provider = SettingsProvider(initialLargeFont: false);

      await tester.pumpWidget(createSettingsTestApp(
        settingsProvider: provider,
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const Text('Test Scale');
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(MediaQuery.textScalerOf(capturedContext), const TextScaler.linear(1.0));

      // Enable large font
      await provider.setLargeFont(true);
      await tester.pumpAndSettle();

      expect(MediaQuery.textScalerOf(capturedContext), const TextScaler.linear(1.3));
    });

    testWidgets('HomeScreen settings action button navigates to SettingsScreen', (tester) async {
      final apiClient = ApiClient(mockMode: true);
      final auth = AuthProvider(apiClient: apiClient);
      auth.setCurrentUserForTesting(
        const User(id: 'u1', name: 'Test Donor', phone: '+919876543210', role: 'donor'),
      );

      await tester.pumpWidget(createSettingsTestApp(
        child: const HomeScreen(),
        authProvider: auth,
      ));
      await tester.pumpAndSettle();

      // Find Settings icon button in AppBar
      final settingsBtn = find.byTooltip('Settings & Accessibility');
      expect(settingsBtn, findsOneWidget);

      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Settings & Accessibility'), findsOneWidget);
      expect(find.byKey(const Key('large_font_switch')), findsOneWidget);
    });

    testWidgets('ProfileScreen Settings & Accessibility button navigates to SettingsScreen', (tester) async {
      final apiClient = ApiClient(mockMode: true);
      final auth = AuthProvider(apiClient: apiClient);
      auth.setCurrentUserForTesting(
        const User(id: 'u1', name: 'Test User', phone: '+919876543210', role: 'donor'),
      );

      await tester.pumpWidget(createSettingsTestApp(
        child: const ProfileScreen(isNewUser: false),
        authProvider: auth,
      ));
      await tester.pumpAndSettle();

      final settingsBtn = find.widgetWithText(OutlinedButton, 'Settings & Accessibility');
      expect(settingsBtn, findsOneWidget);

      await tester.ensureVisible(settingsBtn);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      expect(find.text('Settings & Accessibility'), findsOneWidget);
      expect(find.byKey(const Key('large_font_switch')), findsOneWidget);
    });
  });
}
