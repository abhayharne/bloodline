import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';

/// Service wrapping Nexconn Chat SDK operations (init, connect, disconnect, state)
class NexconnService {
  NexconnService._();
  static final NexconnService instance = NexconnService._();

  bool _initialized = false;
  bool _connected = false;
  int _connectionAttempt = 0;
  String? _connectedUserId;
  final _connectionController = StreamController<bool>.broadcast();

  bool get isInitialized => _initialized;
  bool get isConnected => _connected;
  String? get connectedUserId => _connectedUserId;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> initialize({
    required String appKey,
    AreaCode areaCode = AreaCode.sg,
  }) async {
    if (_initialized) return;
    try {
      final initParams = InitParams(
        appKey: appKey,
        areaCode: areaCode,
      );
      if (!NCEngine.isInitialized) {
        await NCEngine.initialize(initParams);
      }
      _initialized = true;
      debugPrint('[NexconnService] Initialized with appKey: $appKey');
    } catch (e) {
      debugPrint('[NexconnService] Init error: $e');
    }
  }

  /// Connects to Nexconn Chat SDK using the user's accessToken.
  /// If using mock tokens (offline or spike), safely catches errors without crashing.
  Future<bool> connect(String token) async {
    if (token.isEmpty) return false;
    final attempt = ++_connectionAttempt;

    // For mock tokens or test environments, record connection state immediately
    if (token.startsWith('mock_')) {
      _connected = true;
      _connectedUserId = 'mock_user';
      _connectionController.add(true);
      return true;
    }

    final completer = Completer<bool>();

    try {
      if (!_initialized) {
        await initialize(
          appKey: const String.fromEnvironment('NEXCONN_APP_KEY',
              defaultValue: 'mock_app_key'),
          areaCode: AreaCode.sg,
        );
      }

      if (attempt != _connectionAttempt) return false;
      await NCEngine.connect(
        ConnectParams(token: token),
        (String? userId, NCError? error) {
          if (attempt != _connectionAttempt) {
            if (!completer.isCompleted) completer.complete(false);
            return;
          }
          if (error?.isSuccess == true) {
            _connected = true;
            _connectedUserId = userId;
            _connectionController.add(true);
            debugPrint('[NexconnService] Connected successfully as $userId');
            if (!completer.isCompleted) completer.complete(true);
          } else {
            debugPrint('[NexconnService] Connect error: ${error?.code}');
            _connected = false;
            _connectionController.add(false);
            if (!completer.isCompleted) completer.complete(false);
          }
        },
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[NexconnService] Connect exception: ${e.runtimeType}');
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => false,
    );
  }

  Future<void> disconnect() async {
    final attempt = ++_connectionAttempt;
    try {
      await NCEngine.disconnect();
    } catch (e) {
      debugPrint('[NexconnService] Disconnect error: $e');
    } finally {
      if (attempt == _connectionAttempt) {
        _connected = false;
        _connectedUserId = null;
        _connectionController.add(false);
      }
    }
  }
}
