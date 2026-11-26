import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/providers/connection_provider.dart';

class ConnectionGate extends StatefulWidget {
  const ConnectionGate({
    super.key,
    required this.apiClient,
    required this.prepareApp,
    this.connection,
  });

  final ApiClient apiClient;
  final Future<Widget> Function() prepareApp;
  final ConnectionProvider? connection;

  @override
  State<ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends State<ConnectionGate> {
  late final ConnectionProvider _connection;
  Widget? _app;
  bool _preparing = false;
  bool _preparationFailed = false;

  @override
  void initState() {
    super.initState();
    _connection =
        widget.connection ?? ConnectionProvider(apiClient: widget.apiClient);
    _connection.addListener(_changed);
    unawaited(_connect());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    if (_preparing || _connection.connecting) return;
    setState(() => _preparationFailed = false);
    await _connection.connect();
    if (!mounted || !_connection.ready) return;
    setState(() => _preparing = true);
    try {
      final app = await widget.prepareApp();
      if (mounted) setState(() => _app = app);
    } catch (_) {
      if (mounted) setState(() => _preparationFailed = true);
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  void dispose() {
    _connection.removeListener(_changed);
    if (widget.connection == null) _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_app != null) return _app!;
    final waiting = _connection.connecting || _preparing;
    return MaterialApp(
      title: 'BloodLine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.bloodtype, size: 56, color: Colors.red),
                    const SizedBox(height: 24),
                    Text(
                      waiting ? 'Connecting to BloodLine' : 'Unable to connect',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _preparationFailed
                            ? 'BloodLine could not finish starting. Please try again.'
                            : waiting
                            ? 'The demo may take up to 90 seconds to wake up. Please keep the app open.'
                            : 'Check your internet connection and try again. The demo service may be temporarily unavailable.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (waiting)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Connecting',
                      )
                    else
                      FilledButton(
                        onPressed: _connect,
                        child: const Text('Try again'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
