import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/nexconn_service.dart';
import 'package:bloodline/core/providers/auth_provider.dart';
import 'package:bloodline/core/providers/requests_provider.dart';
import 'package:bloodline/core/providers/bank_stock_provider.dart';
import 'package:bloodline/features/auth/login_screen.dart';
import 'package:bloodline/features/auth/profile_screen.dart';
import 'package:bloodline/features/requester/requester_screen.dart';
import 'package:bloodline/features/donor/donor_screen.dart';
import 'package:bloodline/features/bank/bank_screen.dart';
import 'package:bloodline/core/models/blood_request.dart';
import 'package:bloodline/core/providers/notifications_provider.dart';
import 'package:bloodline/features/chat/blood_request_chat_screen.dart';
import 'package:bloodline/features/home/home_screen.dart';
import 'package:bloodline/features/notifications/notifications_screen.dart';
import 'package:bloodline/core/slot_registry.dart';
import 'package:bloodline/core/providers/settings_provider.dart';
import 'package:bloodline/features/chat/channel_inbox_screen.dart';
import 'package:bloodline/features/debug/debug_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(
  Widget child, {
  AuthProvider? authProvider,
  RequestsProvider? requestsProvider,
  NotificationsProvider? notificationsProvider,
  SettingsProvider? settingsProvider,
}) {
  final apiClient = ApiClient(mockMode: true);
  final auth = authProvider ?? AuthProvider(apiClient: apiClient);
  final requests = requestsProvider ?? RequestsProvider(apiClient: apiClient);
  final notif = notificationsProvider ?? NotificationsProvider(apiClient: apiClient);
  final settings = settingsProvider ?? SettingsProvider();
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<RequestsProvider>.value(value: requests),
      ChangeNotifierProvider<BankStockProvider>(
        create: (_) => BankStockProvider(apiClient: apiClient),
      ),
      ChangeNotifierProvider<NotificationsProvider>.value(value: notif),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MockApiClient.resetMockNotifications();
    SlotRegistry.instance.clear();
  });

  tearDown(() {
    SlotRegistry.instance.clear();
  });
  testWidgets('LoginScreen renders phone input, role selector, and mock OTP trigger', (tester) async {
    await tester.pumpWidget(createTestApp(const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('BloodLine'), findsOneWidget);
    expect(find.text('Donor'), findsOneWidget);
    expect(find.text('Requester'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Get Mock OTP'), findsOneWidget);

    // Tap Get Mock OTP
    await tester.tap(find.text('Get Mock OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter 6-digit Mock OTP'), findsOneWidget);
    expect(find.text('demo mode, code 123456'), findsOneWidget);
    expect(find.text('Verify & Continue'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders physical fields, blood group, consent, and location fallback', (tester) async {
    await tester.pumpWidget(createTestApp(const ProfileScreen(isNewUser: true)));
    await tester.pumpAndSettle();

    expect(find.text('Full Name / Organization *'), findsOneWidget);
    expect(find.text('Blood Group *'), findsOneWidget);
    expect(find.text('Age (yrs)'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
    expect(find.text('Height (cm)'), findsOneWidget);
    expect(find.text('Sex'), findsOneWidget);
    expect(find.text('Donated blood before?'), findsOneWidget);
    expect(find.text('Location Settings'), findsOneWidget);
    expect(find.text('Use Device GPS Location'), findsOneWidget);
    expect(find.text('Typed Area / Neighborhood (fallback)'), findsOneWidget);
    expect(find.text('Donor Consent *'), findsOneWidget);
    expect(find.text('Nagpur Central'), findsWidgets);
  });

  testWidgets('RequesterScreen renders new request form and active requests', (tester) async {
    await tester.pumpWidget(createTestApp(const RequesterScreen()));
    await tester.pumpAndSettle();

    expect(find.text('New Blood Request'), findsOneWidget);
    expect(find.text('Hospital / Delivery Location'), findsOneWidget);
    expect(find.text('Broadcast Blood Request'), findsOneWidget);
    expect(find.text('My Active Requests'), findsOneWidget);
  });

  testWidgets('DonorScreen renders emergency feed with accept button', (tester) async {
    await tester.pumpWidget(createTestApp(const DonorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Requests Feed'), findsOneWidget);
    expect(find.text('City Hospital, Nagpur'), findsOneWidget);
    expect(find.text('I Can Help (Accept & Join Room)'), findsWidgets);
  });

  testWidgets('BankScreen renders 8 blood group stock editors and save button', (tester) async {
    await tester.pumpWidget(createTestApp(const BankScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Blood Inventory Stock'), findsOneWidget);
    expect(find.text('Save Stock'), findsOneWidget);
    expect(find.text('O+'), findsWidgets);
    expect(find.text('O-'), findsWidgets);
    expect(find.text('A+'), findsWidgets);
    expect(find.text('B+'), findsWidgets);
  });

  testWidgets('RequestSummaryHeader renders summary details and closed room banner when fulfilled', (tester) async {
    final openReq = BloodRequest(
      id: 'r1',
      bloodGroup: 'O-',
      units: 2,
      hospital: 'Emergency Care Center',
      urgency: 'critical',
      status: 'open',
      channelId: 'reqr1',
    );

    await tester.pumpWidget(createTestApp(Scaffold(body: RequestSummaryHeader(request: openReq))));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Care Center'), findsOneWidget);
    expect(find.text('O-'), findsOneWidget);
    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.textContaining('Request Fulfilled — This room is closed'), findsNothing);

    // Fulfilled request
    final fulfilledReq = openReq.copyWith(status: 'fulfilled');
    await tester.pumpWidget(createTestApp(Scaffold(body: RequestSummaryHeader(request: fulfilledReq))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Request Fulfilled — This room is closed'), findsOneWidget);
  });

  testWidgets('LoginScreen OTP verify authenticates existing user and connects Nexconn', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(const LoginScreen(), authProvider: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Mock OTP'));
    await tester.pumpAndSettle();

    // Verify existing user
    await tester.ensureVisible(find.text('Verify & Continue'));
    await tester.tap(find.text('Verify & Continue'));
    await tester.pump();

    expect(auth.isAuthenticated, isTrue);
    expect(auth.token, isNotNull);
    expect(auth.currentUser?.role, 'donor');
    expect(NexconnService.instance.isConnected, isTrue);
  });

  testWidgets('ProfileScreen enforces donor consent validation before submitting', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const ProfileScreen(isNewUser: true, initialRole: 'donor'),
      authProvider: auth,
    ));
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(find.byType(TextFormField).first, 'Vikram');
    await tester.pumpAndSettle();

    // Uncheck consent checkbox
    final consentFinder = find.byType(CheckboxListTile);
    expect(consentFinder, findsOneWidget);
    await tester.ensureVisible(consentFinder);
    await tester.tap(consentFinder);
    await tester.pumpAndSettle();

    // Tap Complete Registration
    await tester.ensureVisible(find.text('Complete Registration'));
    await tester.tap(find.text('Complete Registration'));
    await tester.pump();

    // Should show validation snackbar and remain on ProfileScreen without registering
    expect(find.text('Donors must provide consent to be registered.'), findsOneWidget);
    expect(find.text('Complete Registration'), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);
  });

  testWidgets('LoginScreen new user navigates to ProfileScreen upon OTP verification', (tester) async {
    await tester.pumpWidget(createTestApp(const LoginScreen()));
    await tester.pumpAndSettle();

    // Enter a new user phone number (ends in 999 to trigger is_new in mock)
    final phoneFinder = find.byType(TextField).at(1);
    await tester.enterText(phoneFinder, '+91 99999 00999');
    await tester.pumpAndSettle();

    // Tap Get Mock OTP
    await tester.tap(find.text('Get Mock OTP'));
    await tester.pumpAndSettle();

    // Verify OTP -> navigates to Complete Profile screen
    await tester.ensureVisible(find.text('Verify & Continue'));
    await tester.tap(find.text('Verify & Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Complete Profile'), findsOneWidget);
    expect(find.text('Donor Consent *'), findsOneWidget);
    expect(find.text('Typed Area / Neighborhood (fallback)'), findsOneWidget);
  });

  testWidgets('Requester Mark fulfilled button marks request as fulfilled and shows closed banner', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);
    await auth.login(name: 'Asha', role: 'requester');
    final requests = RequestsProvider(apiClient: client);

    final req = BloodRequest(
      id: 'r1',
      bloodGroup: 'O-',
      units: 2,
      hospital: 'Nagpur General Hospital',
      urgency: 'critical',
      status: 'open',
      channelId: 'reqr1',
      requesterName: 'Asha',
    );

    await tester.pumpWidget(createTestApp(
      BloodRequestChatScreen(request: req),
      authProvider: auth,
      requestsProvider: requests,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mark fulfilled'), findsWidgets);
    expect(find.byKey(const ValueKey('closed_room_readonly_banner')), findsNothing);

    // Tap Mark fulfilled button
    await tester.tap(find.text('Mark fulfilled').first);
    await tester.pumpAndSettle();

    expect(find.text('Mark Request Fulfilled?'), findsOneWidget);
    await tester.tap(find.text('Yes, Mark Fulfilled'));
    await tester.pumpAndSettle();

    // Verify closed-room read-only banner is displayed
    expect(find.byKey(const ValueKey('closed_room_readonly_banner')), findsOneWidget);
    expect(find.textContaining('Request Fulfilled — This room is closed'), findsOneWidget);
    expect(find.text('This request is fulfilled. Room is closed and read-only.'), findsOneWidget);
  });

  testWidgets('Donor I donated button confirms and records donation', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);
    await auth.login(name: 'Ravi', role: 'donor');
    final requests = RequestsProvider(apiClient: client);

    final req = BloodRequest(
      id: 'r1',
      bloodGroup: 'O-',
      units: 2,
      hospital: 'City Hospital',
      urgency: 'high',
      status: 'open',
      channelId: 'reqr1',
      requesterName: 'Asha',
    );

    await tester.pumpWidget(createTestApp(
      BloodRequestChatScreen(request: req),
      authProvider: auth,
      requestsProvider: requests,
    ));
    await tester.pumpAndSettle();

    expect(find.text('I donated'), findsWidgets);
    expect(find.text('Donated'), findsNothing);

    // Tap I donated
    await tester.tap(find.text('I donated').first);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Donation'), findsOneWidget);
    await tester.tap(find.text('Yes, I donated'));
    await tester.pumpAndSettle();

    expect(requests.isDonated('r1'), isTrue);
    expect(find.text('Donated'), findsOneWidget);
  });

  testWidgets('RequesterScreen active request displays Mark fulfilled button and fulfills request', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);
    await auth.login(name: 'Asha', role: 'requester');
    final requests = RequestsProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const Scaffold(body: RequesterScreen()),
      authProvider: auth,
      requestsProvider: requests,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mark fulfilled'), findsWidgets);
    await tester.ensureVisible(find.text('Mark fulfilled').first);
    await tester.tap(find.text('Mark fulfilled').first);
    await tester.pumpAndSettle();

    expect(find.text('Mark Request Fulfilled?'), findsOneWidget);
    await tester.tap(find.text('Yes, Mark Fulfilled'));
    await tester.pumpAndSettle();
  });

  testWidgets('HomeScreen renders NotificationBanner with server copy, dismisses, and bell opens NotificationsScreen', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);
    await auth.login(name: 'Asha', role: 'donor');
    final notif = NotificationsProvider(apiClient: client);
    await notif.fetchNotifications();

    await tester.pumpWidget(createTestApp(
      const HomeScreen(),
      authProvider: auth,
      notificationsProvider: notif,
    ));
    await tester.pumpAndSettle();

    // Verify copy is displayed directly from server response (not hardcoded)
    expect(find.text('Ready to save lives again?'), findsOneWidget);
    expect(
      find.text('Your blood has had 90 days to recharge. Ready to be somebody\'s hero again?'),
      findsOneWidget,
    );
    expect(find.text('Mark read'), findsOneWidget);
    expect(find.text('View All'), findsOneWidget);

    // Verify bell icon has unread count badge (2 unread: n1 and n2)
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tapping View All navigates to NotificationsScreen
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    // Go back to HomeScreen
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Dismiss banner
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    // Banner is dismissed
    expect(find.text('Ready to save lives again?'), findsNothing);
  });

  testWidgets('NotificationsScreen displays list of notifications, marks individual read, and marks all read', (tester) async {
    final client = ApiClient(mockMode: true);
    final notif = NotificationsProvider(apiClient: client);
    await notif.fetchNotifications();

    expect(notif.unreadCount, 2);

    await tester.pumpWidget(createTestApp(
      const NotificationsScreen(),
      notificationsProvider: notif,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Ready to save lives again?'), findsOneWidget);
    expect(find.text('Urgent: O- needed nearby'), findsOneWidget);
    expect(find.text('Thank you from Anil\'s family'), findsOneWidget);
    expect(find.byTooltip('Mark as read'), findsNWidgets(2));

    // Tap first Mark as read
    await tester.tap(find.byTooltip('Mark as read').first);
    await tester.pumpAndSettle();

    expect(notif.unreadCount, 1);
    expect(find.byTooltip('Mark as read'), findsOneWidget);

    // Tap Mark all read
    expect(find.text('Mark all read'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(notif.unreadCount, 0);
    expect(find.byTooltip('Mark as read'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('NotificationsProvider polling every 10s starts and stops timer', (tester) async {
    final client = ApiClient(mockMode: true);
    final notif = NotificationsProvider(apiClient: client);
    expect(notif.isPolling, false);

    notif.startPolling(interval: const Duration(seconds: 10));
    expect(notif.isPolling, true);

    await tester.pumpAndSettle();

    notif.stopPolling();
    expect(notif.isPolling, false);
    notif.dispose();
  });

  testWidgets('NotificationsScreen displays empty state when no notifications exist', (tester) async {
    final client = ApiClient(mockMode: true);
    final notif = NotificationsProvider(apiClient: client);
    // Provider starts empty before fetch or with empty list
    await tester.pumpWidget(createTestApp(
      const NotificationsScreen(),
      notificationsProvider: notif,
    ));
    await tester.pump();

    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('ChannelInboxScreen renders emergency chat rooms with offline fallback when uninitialized', (tester) async {
    await tester.pumpWidget(createTestApp(
      const ChannelInboxScreen(),
    ));
    await tester.pump();

    expect(find.text('Emergency Chat Rooms'), findsOneWidget);
    expect(find.textContaining('Chat offline'), findsOneWidget);
  });

  testWidgets('DebugScreen renders developer tools, URL field, and mock mode switch', (tester) async {
    await tester.pumpWidget(createTestApp(
      const DebugScreen(),
    ));
    await tester.pump();

    expect(find.text('Developer & Debug Tools'), findsOneWidget);
    expect(find.text('Backend Base URL'), findsOneWidget);
    expect(find.text('Force In-Memory Mock Mode'), findsOneWidget);
    expect(find.text('Connect Token'), findsOneWidget);
  });
}
