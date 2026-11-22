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
import 'package:bloodline/core/models/user.dart';
import 'package:bloodline/core/models/auth_response.dart';
import 'package:bloodline/core/providers/notifications_provider.dart';
import 'package:bloodline/features/chat/blood_request_chat_screen.dart';
import 'package:bloodline/features/home/home_screen.dart';
import 'package:bloodline/features/notifications/notifications_screen.dart';
import 'package:bloodline/core/slot_registry.dart';
import 'package:bloodline/core/scaffold_messenger.dart';
import 'package:bloodline/core/providers/settings_provider.dart';
import 'package:bloodline/features/chat/channel_inbox_screen.dart';
import 'package:bloodline/features/debug/debug_screen.dart';
import 'package:bloodline/features/settings/settings_screen.dart';
import 'package:bloodline/core/location_controller.dart';
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
    child: MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: child,
    ),
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

  testWidgets('LoginScreen shows "Demo mode (offline data)" banner when mock mode is on', (tester) async {
    final client = MockApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const LoginScreen(),
      authProvider: auth,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('demo_mode_banner')), findsOneWidget);
    expect(find.text('Demo mode (offline data)'), findsOneWidget);
  });

  testWidgets('LoginScreen when USE_MOCK is false: does not fall back to mock data on error, stays on login with SnackBar', (tester) async {
    final client = _FailingApiClient();
    final auth = AuthProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const LoginScreen(),
      authProvider: auth,
    ));
    await tester.pumpAndSettle();

    // Mock banner must NOT be visible when mockMode is false
    expect(find.byKey(const Key('demo_mode_banner')), findsNothing);

    // Tap Get Mock OTP with failing backend
    await tester.tap(find.text('Get Mock OTP'));
    await tester.pumpAndSettle();

    // Verify error SnackBar is displayed and stays on initial phone screen
    expect(find.textContaining('Failed to send OTP'), findsOneWidget);
    expect(find.text('Enter 6-digit Mock OTP'), findsNothing);

    // Tap quick login chip with failing backend
    await tester.ensureVisible(find.text('Asha (Donor O+)'));
    await tester.tap(find.text('Asha (Donor O+)'));
    await tester.pumpAndSettle();

    // Verify error SnackBar is displayed and stays on LoginScreen
    expect(find.textContaining('Backend unreachable'), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);
    expect(find.text('BloodLine'), findsOneWidget);
  });

  testWidgets('created_at defensive parsing surfaces parse error in a SnackBar on invalid date', (tester) async {
    await tester.pumpWidget(createTestApp(
      const Scaffold(body: Text('Container')),
    ));
    await tester.pumpAndSettle();

    // Parsing null or empty must NOT throw or show SnackBar
    final reqNull = BloodRequest.fromJson({'id': 'r_null', 'created_at': null});
    expect(reqNull.createdAt, isNull);
    final reqEmpty = BloodRequest.fromJson({'id': 'r_empty', 'created_at': ''});
    expect(reqEmpty.createdAt, isNull);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);

    // Parsing invalid non-empty string must surface in a SnackBar
    BloodRequest.fromJson({'id': 'r_bad', 'created_at': 'corrupted-timestamp-12345'});
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Failed to parse date: corrupted-timestamp-12345'), findsOneWidget);
  });

  testWidgets('RequesterScreen broadcasts and immediately updates My Active Requests with refetched requests', (tester) async {
    final client = ApiClient(mockMode: true);
    final requests = RequestsProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const RequesterScreen(),
      requestsProvider: requests,
    ));
    await tester.pumpAndSettle();

    // Enter hospital name
    final hospitalField = find.widgetWithText(TextFormField, 'Hospital / Delivery Location');
    await tester.enterText(hospitalField, 'City Care Clinic');

    // Broadcast request
    await tester.ensureVisible(find.text('Broadcast Blood Request'));
    await tester.tap(find.text('Broadcast Blood Request'));
    await tester.pumpAndSettle();

    // Dialog appears with success message
    expect(find.text('Emergency Request Broadcasted!'), findsOneWidget);

    // Tap View Requests to dismiss dialog
    await tester.tap(find.text('View Requests'));
    await tester.pumpAndSettle();

    // Verify new request is shown immediately in My Active Requests list
    expect(find.widgetWithText(ListTile, 'City Care Clinic'), findsOneWidget);
  });

  testWidgets('RequesterScreen urgency options support and send critical, urgent, and planned per docs/API.md', (tester) async {
    final client = ApiClient(mockMode: true);
    final requests = RequestsProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const RequesterScreen(),
      requestsProvider: requests,
    ));
    await tester.pumpAndSettle();

    // Verify all 3 urgency segment options exist per API contract
    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);

    // Select Planned and broadcast
    await tester.ensureVisible(find.text('Planned'));
    await tester.tap(find.text('Planned'));
    await tester.pumpAndSettle();
    final hospitalField = find.widgetWithText(TextFormField, 'Hospital / Delivery Location');
    await tester.enterText(hospitalField, 'Urgency Planned Hospital');
    await tester.ensureVisible(find.text('Broadcast Blood Request'));
    await tester.tap(find.text('Broadcast Blood Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Requests'));
    await tester.pumpAndSettle();

    expect(requests.requests.first.urgency, 'planned');
  });

  testWidgets('HomeScreen logout button displays confirm dialog, disconnects Nexconn, and clears session', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);
    auth.setCurrentUserForTesting(
      const User(id: 'u1', name: 'Ravi', role: 'requester', bloodGroup: 'O-'),
      token: 'jwt_ravi',
    );
    await NexconnService.instance.connect('mock_token');

    expect(auth.isAuthenticated, isTrue);
    expect(NexconnService.instance.isConnected, isTrue);

    await tester.pumpWidget(createTestApp(
      const HomeScreen(),
      authProvider: auth,
    ));
    await tester.pumpAndSettle();

    // Tap home logout button
    await tester.tap(find.byKey(const Key('home_logout_button')));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Confirm Logout'), findsOneWidget);
    expect(find.text('Are you sure you want to log out? This will disconnect chat and return to the login screen.'), findsOneWidget);

    // Tap Cancel -> stays logged in
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.isAuthenticated, isTrue);

    // Tap logout again and confirm
    await tester.tap(find.byKey(const Key('home_logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // Stored token, user cleared and Nexconn disconnected
    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);
    expect(auth.token, isNull);
    expect(NexconnService.instance.isConnected, isFalse);
  });

  testWidgets('ProfileScreen logout button displays confirm dialog and clears session', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);
    auth.setCurrentUserForTesting(
      const User(id: 'u2', name: 'Asha', role: 'donor', bloodGroup: 'O+'),
      token: 'jwt_asha',
    );

    await tester.pumpWidget(createTestApp(
      const ProfileScreen(isNewUser: false),
      authProvider: auth,
    ));
    await tester.pumpAndSettle();

    // Find profile logout button
    final logoutBtn = find.byKey(const Key('profile_logout_button'));
    await tester.ensureVisible(logoutBtn);
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Logout'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Log Out'),
    ));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);
  });

  testWidgets('SettingsScreen logout button displays confirm dialog, resets providers, and returns to login', (tester) async {
    final client = ApiClient(mockMode: true);
    final auth = AuthProvider(apiClient: client);
    final requests = RequestsProvider(apiClient: client);
    auth.setCurrentUserForTesting(
      const User(id: 'u3', name: 'Dr. Sunita', role: 'bank'),
      token: 'jwt_sunita',
    );
    await NexconnService.instance.connect('mock_token_sunita');

    expect(auth.isAuthenticated, isTrue);

    await tester.pumpWidget(createTestApp(
      const SettingsScreen(),
      authProvider: auth,
      requestsProvider: requests,
    ));
    await tester.pumpAndSettle();

    final logoutBtn = find.byKey(const Key('settings_logout_button'));
    await tester.scrollUntilVisible(logoutBtn, 200);
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Logout'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Log Out'),
    ));
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.currentUser, isNull);
    expect(requests.requests, isEmpty);
  });

  testWidgets('LoginScreen normalizes 10-digit phone to +91 before sending OTP', (tester) async {
    String? capturedPhone;
    final client = _RecordingApiClient(onSendOtp: (p) => capturedPhone = p);
    final auth = AuthProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const LoginScreen(),
      authProvider: auth,
    ));
    await tester.pumpAndSettle();

    // Enter a 10-digit number without country code
    final phoneField = find.widgetWithText(TextField, 'Phone Number');
    await tester.enterText(phoneField, '9876543210');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get Mock OTP'));
    await tester.pumpAndSettle();

    expect(capturedPhone, '+919876543210');
    expect(find.text('demo mode, code 123456'), findsOneWidget);
  });

  test('LocationController defaults to "Location not set", last choice wins, and GPS clears preset', () {
    final controller = LocationController();
    expect(controller.displayText, 'Location not set');
    expect(controller.hasLocation, isFalse);

    // Set preset
    controller.setPreset('Sitabuldi', 21.1458, 79.0882);
    expect(controller.source, LocationSource.preset);
    expect(controller.displayText, 'Sitabuldi (21.1458, 79.0882)');

    // Last choice wins: typed overrides preset
    controller.setTyped('Custom Clinic', 21.1500, 79.0900);
    expect(controller.source, LocationSource.typed);
    expect(controller.displayText, 'Custom Clinic (21.1500, 79.0900)');

    // Choosing GPS clears preset selection
    controller.clearPreset();
    expect(controller.source, isNull);
    expect(controller.label, isNull);

    // Clear resets to Location not set
    controller.clear();
    expect(controller.displayText, 'Location not set');
  });

  testWidgets('RequesterScreen renders Component dropdown, Hospital picker with "Other" option, and notes field', (tester) async {
    final client = ApiClient(mockMode: true);
    final requests = RequestsProvider(apiClient: client);

    await tester.pumpWidget(createTestApp(
      const RequesterScreen(),
      requestsProvider: requests,
    ));
    await tester.pumpAndSettle();

    // Component dropdown
    expect(find.text('Blood Component'), findsOneWidget);
    expect(find.text('Whole blood'), findsOneWidget);

    // Notes field
    expect(find.byKey(const Key('notes_field')), findsOneWidget);

    // Hospital picker
    expect(find.text('Select Hospital (nearest first)'), findsOneWidget);

    // Open hospital picker and select "Other (type a name)"
    await tester.tap(find.byKey(const Key('hospital_picker_dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Other (type a name)').last, findsOneWidget);
    await tester.tap(find.text('Other (type a name)').last);
    await tester.pumpAndSettle();

    // Now user types custom hospital
    final hospitalField = find.widgetWithText(TextFormField, 'Hospital / Delivery Location');
    await tester.enterText(hospitalField, 'St. John Trauma Care');
    await tester.pumpAndSettle();

    // Broadcast request
    await tester.ensureVisible(find.text('Broadcast Blood Request'));
    await tester.tap(find.text('Broadcast Blood Request'));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Request Broadcasted!'), findsOneWidget);
    expect(find.textContaining('Matched 2 blood bank(s) and 5 donor(s)'), findsOneWidget);
    expect(find.text('Enter Room'), findsOneWidget);
  });

  testWidgets('RequestSummaryHeader shows component chip in room header', (tester) async {
    final reqWithComponent = BloodRequest(
      id: 'r_comp',
      bloodGroup: 'B+',
      units: 3,
      hospital: 'Apollo Reach',
      urgency: 'urgent',
      status: 'open',
      channelId: 'reqr_comp',
      component: 'Platelets',
    );

    await tester.pumpWidget(createTestApp(
      Scaffold(body: RequestSummaryHeader(request: reqWithComponent)),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room_header_component_chip')), findsOneWidget);
    expect(find.text('Platelets'), findsOneWidget);
    expect(find.text('URGENT'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders "I can donate platelets/plasma" switch for donor role', (tester) async {
    await tester.pumpWidget(createTestApp(
      const ProfileScreen(isNewUser: true, initialRole: 'donor'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('I can donate platelets/plasma'), findsOneWidget);
    expect(find.byKey(const Key('can_donate_platelets_tile')), findsOneWidget);
  });

  testWidgets('HomeScreen debug icon is hidden unless demo mode', (tester) async {
    // When mockMode is false, debug icon must be hidden
    final liveClient = _FailingApiClient();
    final authLive = AuthProvider(apiClient: liveClient);

    await tester.pumpWidget(createTestApp(
      const HomeScreen(),
      authProvider: authLive,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_debug_button')), findsNothing);

    // When mockMode is true, debug icon is visible
    final mockClient = ApiClient(mockMode: true);
    final authMock = AuthProvider(apiClient: mockClient);

    await tester.pumpWidget(createTestApp(
      const HomeScreen(),
      authProvider: authMock,
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_debug_button')), findsOneWidget);
  });

  test('RequestsProvider startPolling periodically refreshes requests and stopPolling cancels timer', () async {
    final apiClient = MockApiClient();
    final provider = RequestsProvider(apiClient: apiClient);

    expect(provider.isPolling, isFalse);

    provider.startPolling(status: 'open', interval: const Duration(milliseconds: 50));
    expect(provider.isPolling, isTrue);

    await Future.delayed(const Duration(milliseconds: 120));
    expect(provider.requests.isNotEmpty, isTrue);

    provider.stopPolling();
    expect(provider.isPolling, isFalse);

    provider.reset();
    expect(provider.requests.isEmpty, isTrue);
    expect(provider.isPolling, isFalse);
  });

  testWidgets('BloodRequestChatScreen provides location pin sharing button and sends hospital pin', (tester) async {
    final apiClient = MockApiClient();
    final auth = AuthProvider(apiClient: apiClient);
    final requestsProvider = RequestsProvider(apiClient: apiClient);

    await auth.login(name: 'Asha Donor', role: 'donor');

    final testRequest = BloodRequest(
      id: 'req_loc_test',
      bloodGroup: 'O-',
      units: 2,
      hospital: 'Orange City Hospital',
      urgency: 'critical',
      status: 'open',
      channelId: 'req_loc_test',
      lat: 21.1458,
      lng: 79.0882,
      requesterName: 'Ravi Requester',
      component: 'Whole blood',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: requestsProvider),
        ],
        child: MaterialApp(
          home: BloodRequestChatScreen(request: testRequest),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shareBtn = find.byKey(const Key('chat_share_location_button'));
    expect(shareBtn, findsOneWidget);

    await tester.tap(shareBtn);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('share_hospital_location_tile')), findsOneWidget);
    expect(find.byKey(const Key('share_gps_location_tile')), findsOneWidget);

    await tester.tap(find.byKey(const Key('share_hospital_location_tile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location_pin_shared_snackbar')), findsOneWidget);
    expect(find.textContaining('Location pin shared: Orange City Hospital'), findsOneWidget);
  });

  testWidgets('BloodRequestChatScreen provides location pin sharing for GPS location', (tester) async {
    final apiClient = MockApiClient();
    final auth = AuthProvider(apiClient: apiClient);
    final requestsProvider = RequestsProvider(apiClient: apiClient);

    await auth.login(name: 'Asha Donor', role: 'donor');

    final testRequest = BloodRequest(
      id: 'req_loc_gps',
      bloodGroup: 'A+',
      units: 1,
      hospital: 'Apex Trauma Center',
      urgency: 'urgent',
      status: 'open',
      channelId: 'req_loc_gps',
      lat: 21.1500,
      lng: 79.0900,
      requesterName: 'Suresh',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: requestsProvider),
        ],
        child: MaterialApp(
          home: BloodRequestChatScreen(request: testRequest),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_share_location_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share_gps_location_tile')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location_pin_shared_snackbar')), findsOneWidget);
    expect(find.textContaining('Location pin shared: Current Location'), findsOneWidget);
  });
}

class _RecordingApiClient extends MockApiClient {
  final Function(String phone) onSendOtp;

  _RecordingApiClient({required this.onSendOtp}) : super(mockMode: true);

  @override
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    onSendOtp(phone);
    return {'sent': true, 'demo': true};
  }
}

class _FailingApiClient extends MockApiClient {
  _FailingApiClient() : super(mockMode: false);

  @override
  bool mockMode = false;

  @override
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    throw ApiException(503, 'Backend unreachable');
  }

  @override
  Future<AuthResponse> login({
    required String name,
    required String role,
    String? phone,
  }) async {
    throw ApiException(503, 'Backend unreachable');
  }
}
