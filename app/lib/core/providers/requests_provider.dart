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
    _pollTimer = Timer.periodic(interval, (_) => loadRequests(status: status, silent: true));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadRequests({String status = 'open', bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _requests = await apiClient.getRequests(status: status);
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void reset() {
    stopPolling();
    _requests = [];
    _donatedRequestIds.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    debugPrint('[RequestsProvider] createRequest: group=$bloodGroup, units=$units, hospital=$hospital, urgency=$urgency, lat=$lat, lng=$lng, component=$component, notes=$notes');

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
      debugPrint('[RequestsProvider] createRequest success: id=${resp.request.id}, channel=${resp.request.channelId}, banks=${resp.matches.banks}, donors=${resp.matches.donors}');

      // Refetch GET /requests and show the new request in My Active Requests immediately
      try {
        final fetched = await apiClient.getRequests(status: 'all');
        debugPrint('[RequestsProvider] refetched ${fetched.length} requests');
        if (fetched.any((r) => r.id == resp.request.id)) {
          _requests = fetched;
        } else {
          _requests = [resp.request, ...fetched];
        }
      } catch (e) {
        debugPrint('[RequestsProvider] refetch failed ($e), prepending local instance');
        if (!_requests.any((r) => r.id == resp.request.id)) {
          _requests.insert(0, resp.request);
        }
      }
      _isLoading = false;
      notifyListeners();
      return resp;
    } catch (e) {
      debugPrint('[RequestsProvider] createRequest failed: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<String?> acceptRequest(String requestId) async {
    try {
      final channelId = await apiClient.acceptRequest(requestId);
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx] = _requests[idx].copyWith(joined: true);
        notifyListeners();
      }
      return channelId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> fulfillRequest(String requestId) async {
    try {
      final updated = await apiClient.fulfillRequest(requestId);
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> recordDonation(String requestId) async {
    try {
      final res = await apiClient.recordDonation(requestId);
      _donatedRequestIds.add(requestId);
      final idx = _requests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _requests[idx] = _requests[idx].copyWith(donated: true);
      }
      notifyListeners();
      return res;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
