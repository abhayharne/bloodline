import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:bloodline/main.dart';
import 'package:bloodline/core/api_client.dart';
import 'package:bloodline/core/providers/auth_provider.dart';
import 'package:bloodline/core/providers/settings_provider.dart';
import 'package:bloodline/features/auth/login_screen.dart';

void main() {
  testWidgets('BloodLineApp root gate renders LoginScreen when unauthenticated',
      (tester) async {
    final mockClient = ApiClient(mockMode: true);
    final authProvider = AuthProvider(apiClient: mockClient);
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: mockClient),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<SettingsProvider>.value(
              value: settingsProvider),
        ],
        child: const BloodLineApp(),
      ),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('BloodLine'), findsWidgets);
  });
}
