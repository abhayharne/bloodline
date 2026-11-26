import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api_client.dart';

/// Waits for a sleeping demo service without replaying user actions.
class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider({
    required this.apiClient,
    this.maxWait = const Duration(seconds: 90),
    this.retryInterval = const Duration(seconds: 2),
  });

  final ApiClient apiClient;
  final Duration maxWait;
  final Duration retryInterval;
  bool _connecting = false;
  bool _ready = false;
  bool _disposed = false;
  int _attempts = 0;

  bool get connecting => _connecting;
  bool get ready => _ready;
  int get attempts => _attempts;

  Future<void> connect() async {
    if (_disposed || _connecting || _ready) return;
    _connecting = true;
    _attempts = 0;
    notifyListeners();
    final deadline = Stopwatch()..start();
    while (!_disposed && deadline.elapsed < maxWait) {
      _attempts++;
      notifyListeners();
      final remaining = maxWait - deadline.elapsed;
      try {
        if (await apiClient.checkHealth().timeout(remaining)) {
          if (_disposed) return;
          _ready = true;
          break;
        }
      } catch (_) {
        // Only the read-only health endpoint is retried.
      }
      if (_disposed) return;
      final pause = maxWait - deadline.elapsed;
      if (pause <= Duration.zero) break;
      await Future<void>.delayed(pause < retryInterval ? pause : retryInterval);
    }
    if (_disposed) return;
    _connecting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
