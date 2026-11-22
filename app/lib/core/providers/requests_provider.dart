import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/blood_request.dart';
import '../models/blood_request_response.dart';
import '../api_client.dart';

class RequestsProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<BloodRequest> _requests = [];
  final Set<String> _donatedRequestIds = {};
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;
  int _session = 0;
  int _latestLoad = 0;

  List<BloodRequest> get requests => _requests;
  Set<String> get donatedRequestIds => _donatedRequestIds;
  bool isDonated(String requestId) => _donatedRequestIds.contains(requestId);
  bool get isLoading => _isLoading;
  bool get isPolling => _pollTimer != null && _pollTimer!.isActive;
  String? get error => _error;

  RequestsProvider({required this.apiClient});

  void startPolling({String status = 'open', Duration interval = const Duration(seconds: 10)}) {
    _pollTimer?.cancel();
    loadRequests(status: status, silent: true);
    _pollTimer = Timer.periodic(interval, (_) {
      if (!_isLoading) loadRequests(status: status, silent: true);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadRequests({String status = 'open', bool silent = false}) async {
    final load = ++_latestLoad;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final requests = await apiClient.getRequests(status: status);
      if (load != _latestLoad) return;
      _requests = requests;
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      if (load != _latestLoad) return;
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void reset() {
    _session++;
    _latestLoad++;
    stopPolling();
    _requests = [];
    _donatedRequestIds.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _session++;
    _latestLoad++;
    stopPolling();
    super.dispose();
  }

  Future<BloodRequestResponse?> createRequest({
    required String bloodGroup,
    required int units,
    required String hospital,
    required String urgency,
    required double lat,
    required double lng,
    String? component,
    String? notes,
  }) async {
    final session = _session;
    _latestLoad++;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await apiClient.createRequest(
        bloodGroup: bloodGroup,
        units: units,
        hospital: hospital,
        urgency: urgency,
        lat: lat,
        lng: lng,
        component: component,
        notes: notes,
      );

      if (session != _session) return null;
      // Refetch GET /requests and show the new request in My Active Requests immediately
      try {
        final fetched = await apiClient.getRequests(status: 'all');
        if (session != _session) return null;
        if (fetched.any((r) => r.id == resp.request.id)) {
          _requests = fetched;
        } else {
          _requests = [resp.request, ...fetched];
        }
      } catch (_) {
        if (session != _session) return null;
        if (!_requests.any((r) => r.id == resp.request.id)) {
          _requests.insert(0, resp.request);
        }
      }
      _isLoading = false;
      notifyListeners();
      return resp;
    } catch (e) {
      if (session != _session) return null;
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> acceptRequest(String requestId) async {
    final session = _session;
    try {
      final channelId = await apiClient.acceptRequest(requestId);
      if (session != _session) return null;
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx] = _requests[idx].copyWith(joined: true);
        notifyListeners();
      }
      return channelId;
    } catch (e) {
      if (session != _session) return null;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> fulfillRequest(String requestId) async {
    final session = _session;
    try {
      final updated = await apiClient.fulfillRequest(requestId);
      if (session != _session) return false;
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (session != _session) return false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> recordDonation(String requestId) async {
    final session = _session;
    try {
      final res = await apiClient.recordDonation(requestId);
      if (session != _session) return null;
      _donatedRequestIds.add(requestId);
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx] = _requests[idx].copyWith(donated: true);
      }
      notifyListeners();
      return res;
    } catch (e) {
      if (session != _session) return null;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
