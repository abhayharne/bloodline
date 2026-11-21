import 'package:flutter/foundation.dart';
import '../models/blood_request.dart';
import '../models/blood_request_response.dart';
import '../api_client.dart';

class RequestsProvider extends ChangeNotifier {
  final ApiClient apiClient;
  List<BloodRequest> _requests = [];
  bool _isLoading = false;
  String? _error;

  List<BloodRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get error => _error;

  RequestsProvider({required this.apiClient});

  Future<void> loadRequests({String status = 'open'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _requests = await apiClient.getRequests(status: status);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<BloodRequestResponse?> createRequest({
    required String bloodGroup,
    required int units,
    required String hospital,
    required String urgency,
    required double lat,
    required double lng,
  }) async {
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
      );
      // Prepend to current list
      _requests.insert(0, resp.request);
      _isLoading = false;
      notifyListeners();
      return resp;
    } catch (e) {
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
}
