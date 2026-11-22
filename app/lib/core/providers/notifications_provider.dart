import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/in_app_notification.dart';
import '../api_client.dart';

class NotificationsProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<InAppNotification> _notifications = [];
  final Set<String> _dismissedBannerIds = {};
  InAppNotification? _activeBanner;
  bool _isLoading = false;
  bool _isFetching = false;
  String? _error;
  Timer? _pollTimer;

  bool _isDisposed = false;
  int _session = 0;

  NotificationsProvider({required this.apiClient});

  List<InAppNotification> get notifications => List.unmodifiable(_notifications);
  InAppNotification? get activeBanner => _activeBanner;
  bool get isLoading => _isLoading;
  bool get isPolling => _pollTimer != null && _pollTimer!.isActive;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.read).length;
  bool get hasUnread => unreadCount > 0;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    _pollTimer?.cancel();
    fetchNotifications();
    _pollTimer = Timer.periodic(interval, (_) => fetchNotifications(silent: true));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    if (_isDisposed) return;
    // If running against real API without auth, skip polling until authenticated
    if (!apiClient.mockMode && (apiClient.authToken == null || apiClient.authToken!.isEmpty)) {
      return;
    }
    if (_isFetching) return;
    final session = _session;
    _isFetching = true;

    if (!silent && _notifications.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final rawList = await apiClient.getNotifications();
      if (_isDisposed || session != _session) return;
      _notifications = rawList.map((m) => InAppNotification.fromJson(m)).toList();

      // Check if there is an unread notification to show as banner
      final unreadNotifs = _notifications.where((n) => !n.read).toList();
      if (unreadNotifs.isNotEmpty) {
        // Find first unread notification that hasn't been dismissed yet
        final candidate = unreadNotifs.firstWhere(
          (n) => !_dismissedBannerIds.contains(n.id),
          orElse: () => unreadNotifs.first,
        );
        if (!_dismissedBannerIds.contains(candidate.id)) {
          _activeBanner = candidate;
        } else {
          _activeBanner = null;
        }
      } else {
        _activeBanner = null;
      }
    } catch (e) {
      if (session == _session && !_isDisposed) _error = e.toString();
    } finally {
      if (session == _session && !_isDisposed) {
        _isFetching = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void dismissBanner() {
    if (_activeBanner != null) {
      _dismissedBannerIds.add(_activeBanner!.id);
      _activeBanner = null;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    if (_isDisposed) return;
    final session = _session;
    try {
      await apiClient.markNotificationRead(id);
      if (_isDisposed || session != _session) return;
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(read: true);
      }
      if (_activeBanner?.id == id) {
        _dismissedBannerIds.add(id);
        final remaining = _notifications.where((n) => !n.read && !_dismissedBannerIds.contains(n.id)).toList();
        _activeBanner = remaining.isNotEmpty ? remaining.first : null;
      }
      notifyListeners();
    } catch (e) {
      if (session == _session && !_isDisposed) _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final session = _session;
    final unreads = _notifications.where((n) => !n.read).toList();
    for (final notif in unreads) {
      if (session != _session || _isDisposed) return;
      await markAsRead(notif.id);
    }
  }

  void reset() {
    _session++;
    stopPolling();
    _notifications = [];
    _dismissedBannerIds.clear();
    _activeBanner = null;
    _isLoading = false;
    _isFetching = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopPolling();
    super.dispose();
  }
}
