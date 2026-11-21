import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models/user.dart';
import 'models/auth_response.dart';
import 'models/blood_request.dart';
import 'models/blood_request_response.dart';
import 'models/blood_stock.dart';
import 'config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// ApiClient interacts with the BloodLine Go backend.
/// Automatically falls back to in-memory mock responses if the backend is unreachable
/// or when mockMode is explicitly enabled.
class ApiClient {
  String baseUrl;
  bool mockMode;
  String? authToken;

  ApiClient({
    this.baseUrl = ConfigConstants.localHostBaseUrl,
    this.mockMode = false,
    this.authToken,
  });

  // ==========================================
  // Mock In-Memory Store
  // ==========================================
  static final List<BloodRequest> _mockRequests = [
    BloodRequest(
      id: 'r1',
      bloodGroup: 'O-',
      units: 2,
      hospital: 'City Hospital, Nagpur',
      urgency: 'critical',
      status: 'open',
      channelId: 'reqr1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      distanceKm: 3.2,
      requesterName: 'Ravi Verma',
      joined: false,
      lat: 21.1500,
      lng: 79.0900,
    ),
    BloodRequest(
      id: 'r2',
      bloodGroup: 'A+',
      units: 3,
      hospital: 'AIIMS Nagpur',
      urgency: 'high',
      status: 'open',
      channelId: 'reqr2',
      createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      distanceKm: 7.5,
      requesterName: 'Dr. Sunita',
      joined: false,
      lat: 21.0900,
      lng: 79.0600,
    ),
    BloodRequest(
      id: 'r3',
      bloodGroup: 'B+',
      units: 1,
      hospital: 'Orange City Hospital',
      urgency: 'medium',
      status: 'fulfilled',
      channelId: 'reqr3',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      distanceKm: 4.8,
      requesterName: 'Anil Kumar',
      joined: true,
      lat: 21.1200,
      lng: 79.0800,
    ),
  ];

  static final Map<String, int> _mockStock = {
    'O+': 8,
    'O-': 2,
    'A+': 12,
    'A-': 3,
    'B+': 15,
    'B-': 1,
    'AB+': 6,
    'AB-': 0,
  };

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  // ==========================================
  // Health & Config
  // ==========================================
  Future<bool> checkHealth() async {
    if (mockMode) return true;
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AppConfig> getConfig() async {
    if (mockMode) {
      return const AppConfig();
    }
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/config'), headers: _headers())
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AppConfig.fromJson(data);
      }
    } catch (e) {
      debugPrint('[ApiClient] GET /config fallback: $e');
    }
    return const AppConfig();
  }

  // ==========================================
  // Auth
  // ==========================================
  Future<AuthResponse> signup({
    required String name,
    required String role,
    String? bloodGroup,
    double lat = 0.0,
    double lng = 0.0,
    String? phone,
    int? age,
    double? weight,
    double? height,
    String? sex,
    bool donatedBefore = false,
    DateTime? lastDonationDate,
    String? areaName,
  }) async {
    final body = {
      'name': name,
      'role': role,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      'lat': lat,
      'lng': lng,
    };

    if (!mockMode) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/auth/signup'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final parsed = AuthResponse.fromJson(data);
          authToken = parsed.token;
          // Enrich with local client-side profile fields
          final user = parsed.user.copyWith(
            phone: phone,
            age: age,
            weight: weight,
            height: height,
            sex: sex,
            donatedBefore: donatedBefore,
            lastDonationDate: lastDonationDate,
            areaName: areaName,
          );
          return AuthResponse(
            user: user,
            token: parsed.token,
            nexconnToken: parsed.nexconnToken,
          );
        }
      } catch (e) {
        debugPrint('[ApiClient] signup network error, falling back to mock: $e');
      }
    }

    // Mock fallback
    final mockId = 'u_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final mockUser = User(
      id: mockId,
      name: name,
      role: role,
      bloodGroup: bloodGroup,
      lat: lat,
      lng: lng,
      phone: phone,
      age: age,
      weight: weight,
      height: height,
      sex: sex,
      donatedBefore: donatedBefore,
      lastDonationDate: lastDonationDate,
      areaName: areaName,
    );
    final mockToken = 'mock_jwt_$mockId';
    authToken = mockToken;
    return AuthResponse(
      user: mockUser,
      token: mockToken,
      nexconnToken: 'mock_chat_token_$mockId',
    );
  }

  Future<AuthResponse> login({
    required String name,
    required String role,
    String? phone,
  }) async {
    final body = {'name': name, 'role': role};

    if (!mockMode) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/auth/login'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final parsed = AuthResponse.fromJson(data);
          authToken = parsed.token;
          return parsed;
        }
      } catch (e) {
        debugPrint('[ApiClient] login network error, falling back to mock: $e');
      }
    }

    // Mock fallback
    final mockId = 'u_${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
    final mockUser = User(
      id: mockId,
      name: name,
      role: role,
      bloodGroup: role == 'bank' ? null : 'O+',
      lat: ConfigConstants.defaultLatitude,
      lng: ConfigConstants.defaultLongitude,
      phone: phone,
      age: 28,
      weight: 68.0,
      height: 172.0,
      sex: 'male',
      donatedBefore: true,
      lastDonationDate: DateTime.now().subtract(const Duration(days: 120)),
      areaName: 'Nagpur Central, MH',
    );
    final mockToken = 'mock_jwt_$mockId';
    authToken = mockToken;
    return AuthResponse(
      user: mockUser,
      token: mockToken,
      nexconnToken: 'mock_chat_token_$mockId',
    );
  }

  // ==========================================
  // Blood Bank Stock
  // ==========================================
  Future<List<BloodStockItem>> getStock() async {
    if (!mockMode) {
      try {
        final res = await http
            .get(Uri.parse('$baseUrl/banks/me/stock'), headers: _headers())
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final stockList = data['stock'] as List<dynamic>? ?? [];
          return stockList
              .map((item) => BloodStockItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('[ApiClient] getStock error, using mock: $e');
      }
    }

    // Mock stock
    return _mockStock.entries
        .map((e) => BloodStockItem(
              bloodGroup: e.key,
              units: e.value,
              updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
            ))
        .toList();
  }

  Future<List<BloodStockItem>> updateStock(List<BloodStockItem> stock) async {
    final body = {
      'stock': stock
          .map((item) => {'blood_group': item.bloodGroup, 'units': item.units})
          .toList()
    };

    if (!mockMode) {
      try {
        final res = await http
            .put(
              Uri.parse('$baseUrl/banks/me/stock'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final stockList = data['stock'] as List<dynamic>? ?? [];
          return stockList
              .map((item) => BloodStockItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('[ApiClient] updateStock error, using mock: $e');
      }
    }

    // Update in-memory mock stock
    for (final item in stock) {
      _mockStock[item.bloodGroup] = item.units;
    }
    return getStock();
  }

  // ==========================================
  // Requests Flow
  // ==========================================
  Future<BloodRequestResponse> createRequest({
    required String bloodGroup,
    required int units,
    required String hospital,
    required String urgency,
    required double lat,
    required double lng,
  }) async {
    final body = {
      'blood_group': bloodGroup,
      'units': units,
      'hospital': hospital,
      'urgency': urgency,
      'lat': lat,
      'lng': lng,
    };

    if (!mockMode) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/requests'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return BloodRequestResponse.fromJson(data);
        }
      } catch (e) {
        debugPrint('[ApiClient] createRequest error, using mock: $e');
      }
    }

    // Mock create request
    final newId = 'r${DateTime.now().millisecondsSinceEpoch % 100000}';
    final newReq = BloodRequest(
      id: newId,
      bloodGroup: bloodGroup,
      units: units,
      hospital: hospital,
      urgency: urgency,
      status: 'open',
      channelId: 'req$newId',
      createdAt: DateTime.now(),
      distanceKm: 0.1,
      requesterName: 'Me',
      joined: true,
      lat: lat,
      lng: lng,
    );
    _mockRequests.insert(0, newReq);

    return BloodRequestResponse(
      request: newReq,
      matches: const BloodRequestMatches(banks: 2, donors: 5),
    );
  }

  Future<List<BloodRequest>> getRequests({String status = 'open'}) async {
    if (!mockMode) {
      try {
        final res = await http
            .get(
              Uri.parse('$baseUrl/requests?status=$status'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final list = data['requests'] as List<dynamic>? ?? [];
          return list
              .map((item) => BloodRequest.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('[ApiClient] getRequests error, using mock: $e');
      }
    }

    // Filter mock requests
    if (status == 'all') {
      return List.unmodifiable(_mockRequests);
    }
    return _mockRequests.where((r) => r.status == status).toList();
  }

  Future<String> acceptRequest(String requestId) async {
    if (!mockMode) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/requests/$requestId/accept'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return data['channel_id']?.toString() ?? 'req$requestId';
        }
      } catch (e) {
        debugPrint('[ApiClient] acceptRequest error, using mock: $e');
      }
    }

    // Mock accept
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _mockRequests[index];
      _mockRequests[index] = req.copyWith(joined: true);
      return req.channelId;
    }
    return 'req$requestId';
  }

  Future<BloodRequest> fulfillRequest(String requestId) async {
    if (!mockMode) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/requests/$requestId/fulfill'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final reqJson = data['request'] is Map<String, dynamic>
              ? data['request'] as Map<String, dynamic>
              : data;
          return BloodRequest.fromJson(reqJson);
        }
      } catch (e) {
        debugPrint('[ApiClient] fulfillRequest error, using mock: $e');
      }
    }

    // Mock fulfill
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final updated = _mockRequests[index].copyWith(status: 'fulfilled');
      _mockRequests[index] = updated;
      return updated;
    }
    throw ApiException(404, 'Request not found');
  }

  Future<BloodRequest> cancelRequest(String requestId) async {
    if (!mockMode) {
      try {
        final res = await http
            .post(
              Uri.parse('$baseUrl/requests/$requestId/cancel'),
              headers: _headers(),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final reqJson = data['request'] is Map<String, dynamic>
              ? data['request'] as Map<String, dynamic>
              : data;
          return BloodRequest.fromJson(reqJson);
        }
      } catch (e) {
        debugPrint('[ApiClient] cancelRequest error, using mock: $e');
      }
    }

    // Mock cancel
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final updated = _mockRequests[index].copyWith(status: 'cancelled');
      _mockRequests[index] = updated;
      return updated;
    }
    throw ApiException(404, 'Request not found');
  }
}
