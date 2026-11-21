import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';

/// Service wrapping Nexconn Chat SDK operations (init, connect, disconnect, state)
class NexconnService {
  NexconnService._();
  static final NexconnService instance = NexconnService._();

  bool _initialized = false;
  bool _connected = false;
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
    final completer = Completer<bool>();

    try {
      await NCEngine.connect(
        ConnectParams(token: token),
        (String? userId, NCError? error) {
          if (error?.isSuccess == true) {
            _connected = true;
            _connectedUserId = userId;
            _connectionController.add(true);
            debugPrint('[NexconnService] Connected successfully as $userId');
            if (!completer.isCompleted) completer.complete(true);
          } else {
            debugPrint('[NexconnService] Connect error: ${error?.code} - ${error?.message}');
            // For mock/dev tokens, record connection state gracefully
            if (token.startsWith('mock_')) {
              _connected = true;
              _connectedUserId = 'mock_user';
              _connectionController.add(true);
              if (!completer.isCompleted) completer.complete(true);
            } else {
              _connected = false;
              _connectionController.add(false);
              if (!completer.isCompleted) completer.complete(false);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[NexconnService] Connect exception: $e');
      if (token.startsWith('mock_')) {
        _connected = true;
        _connectedUserId = 'mock_user';
        _connectionController.add(true);
        if (!completer.isCompleted) completer.complete(true);
      } else {
        if (!completer.isCompleted) completer.complete(false);
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        if (token.startsWith('mock_')) {
          _connected = true;
          _connectionController.add(true);
          return true;
        }
        return false;
      },
    );
  }

  Future<void> disconnect() async {
    try {
      await NCEngine.disconnect();
    } catch (e) {
      debugPrint('[NexconnService] Disconnect error: $e');
    } finally {
      _connected = false;
      _connectedUserId = null;
      _connectionController.add(false);
    }
  }
}
