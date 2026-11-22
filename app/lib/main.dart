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
            create: (_) => RequestsProvider(apiClient: apiClient),
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
            create: (_) => NotificationsProvider(apiClient: apiClient),
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

class BloodLineApp extends StatefulWidget {
  const BloodLineApp({super.key});

  @override
  State<BloodLineApp> createState() => _BloodLineAppState();
}

class _BloodLineAppState extends State<BloodLineApp> {
  String? _pollingToken;

  void _syncPolling(AuthProvider auth) {
    final token = auth.token;
    if (token == _pollingToken) return;
    _pollingToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || auth.token != token) return;
      final requests = context.read<RequestsProvider>();
      final notifications = context.read<NotificationsProvider>();
      requests.reset();
      notifications.reset();
      if (token != null) {
        requests.startPolling(
          status: auth.currentUser?.role == 'requester' ? 'all' : 'open',
        );
        notifications.startPolling();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncPolling(context.watch<AuthProvider>());
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
      // Fallback home routes so stray navigation/pop never produces a blank screen
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const RootGate(),
        );
      },
      onUnknownRoute: (routeSettings) {
        return MaterialPageRoute(
          settings: routeSettings,
          builder: (_) => const RootGate(),
        );
      },
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final child = auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
    return PopScope(
      canPop: false,
      child: child,
    );
  }
}
