import 'package:flutter/material.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:bloodline/features/debug/debug_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App key from dart-define, with fallback to .env default
  const appKey = String.fromEnvironment(
    'NEXCONN_APP_KEY',
    defaultValue: 'qf3d5gbjqvm5h',
  );

  if (appKey.isEmpty) {
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Missing NEXCONN_APP_KEY.\n'
            'Run with: flutter run --dart-define=NEXCONN_APP_KEY=<key>',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ));
    return;
  }

  final initParams = InitParams(
    appKey: appKey,
    areaCode: AreaCode.sg,
  );

  final engineProvider = EngineProvider();
  await engineProvider.initialize(initParams);

  runApp(
    NexconnChatUIProviders(
      engineProvider: engineProvider,
      child: const BloodLineApp(),
    ),
  );
}

class BloodLineApp extends StatelessWidget {
  const BloodLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BloodLine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const DebugScreen(),
    );
  }
}
