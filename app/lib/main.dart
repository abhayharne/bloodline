import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';

import 'core/config.dart';
import 'core/api_client.dart';
import 'core/features.dart';
import 'core/scaffold_messenger.dart';
import 'core/nexconn_service.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/requests_provider.dart';
import 'core/providers/bank_stock_provider.dart';
import 'core/providers/config_provider.dart';
import 'core/providers/notifications_provider.dart';
import 'core/providers/settings_provider.dart';

import 'features/auth/register.dart';
import 'features/requester/register.dart';
import 'features/donor/register.dart';
import 'features/bank/register.dart';
import 'features/chat/register.dart';
import 'features/home/register.dart';
import 'features/debug/register.dart';
import 'features/notifications/register.dart';
import 'features/ranks/register.dart';
import 'features/reminders/register.dart';
import 'features/settings/register.dart';

import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final features = await Features.load(apiClient);

  // Initialize features (registers extension slots if any)
  registerAuthFeature();
  registerRequesterFeature();
  registerDonorFeature();
  registerBankFeature();
  registerChatFeature();
  registerHomeFeature();
  registerDebugFeature();
  registerNotificationsFeature();
  registerRanksFeature(features: features);
  registerRemindersFeature(features: features);
  registerSettingsFeature();

  // App key from dart-define, with fallback to .env default
  const appKey = String.fromEnvironment(
    'NEXCONN_APP_KEY',
    defaultValue: ConfigConstants.defaultAppKey,
  );

  final initParams = InitParams(
    appKey: appKey,
    areaCode: AreaCode.sg,
  );

  final engineProvider = EngineProvider();
  await engineProvider.initialize(initParams);

  // Initialize NexconnService singleton
  await NexconnService.instance.initialize(
    appKey: appKey,
    areaCode: AreaCode.sg,
  );

  runApp(
    NexconnChatUIProviders(
      engineProvider: engineProvider,
      child: MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: apiClient),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) {
              final auth = AuthProvider(apiClient: apiClient);
              auth.init();
              return auth;
            },
          ),
          ChangeNotifierProvider<RequestsProvider>(
            create: (_) {
              final reqs = RequestsProvider(apiClient: apiClient);
              reqs.startPolling();
              return reqs;
            },
          ),
          ChangeNotifierProvider<BankStockProvider>(
            create: (_) => BankStockProvider(apiClient: apiClient),
          ),
          ChangeNotifierProvider<ConfigProvider>(
            create: (_) {
              final cfg = ConfigProvider(apiClient: apiClient);
              cfg.fetchConfig();
              return cfg;
            },
          ),
          ChangeNotifierProvider<NotificationsProvider>(
            create: (_) {
              final notif = NotificationsProvider(apiClient: apiClient);
              notif.startPolling();
              return notif;
            },
          ),
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) {
              final settings = SettingsProvider();
              settings.load();
              return settings;
            },
          ),
        ],
        child: const BloodLineApp(),
      ),
    ),
  );
}

class BloodLineApp extends StatelessWidget {
  const BloodLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'BloodLine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
        brightness: Brightness.light,
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: settings.textScaler,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const RootGate(),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
