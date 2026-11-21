import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/providers/auth_provider.dart';
import 'package:bloodline/core/providers/requests_provider.dart';
import 'package:bloodline/core/providers/bank_stock_provider.dart';
import 'package:bloodline/features/auth/login_screen.dart';
import 'package:bloodline/features/auth/profile_screen.dart';
import 'package:bloodline/features/requester/requester_screen.dart';
import 'package:bloodline/features/donor/donor_screen.dart';
import 'package:bloodline/features/bank/bank_screen.dart';
import 'package:bloodline/core/models/blood_request.dart';
import 'package:bloodline/features/chat/blood_request_chat_screen.dart';

Widget createTestApp(Widget child) {
  final apiClient = ApiClient(mockMode: true);
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: apiClient),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(apiClient: apiClient),
      ),
      ChangeNotifierProvider<RequestsProvider>(
        create: (_) => RequestsProvider(apiClient: apiClient),
      ),
      ChangeNotifierProvider<BankStockProvider>(
        create: (_) => BankStockProvider(apiClient: apiClient),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
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
    expect(find.text('Verify & Continue'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders physical fields, blood group, and location fallback', (tester) async {
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
    expect(find.text('Request Fulfilled — This room is closed'), findsNothing);

    // Fulfilled request
    final fulfilledReq = openReq.copyWith(status: 'fulfilled');
    await tester.pumpWidget(createTestApp(Scaffold(body: RequestSummaryHeader(request: fulfilledReq))));
    await tester.pumpAndSettle();

    expect(find.text('Request Fulfilled — This room is closed'), findsOneWidget);
  });
}
