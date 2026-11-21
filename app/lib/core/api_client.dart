import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models/user.dart';
import 'models/auth_response.dart';
import 'models/blood_request.dart';
import 'models/blood_request_response.dart';
import 'models/blood_stock.dart';
import 'models/app_config.dart';
import 'config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Abstract API client contract for the BloodLine backend.
/// Allows swapping between real HTTP implementation and in-memory mock client.
abstract class ApiClient {
  String get baseUrl;
  set baseUrl(String url);

  bool get mockMode;
  set mockMode(bool enabled);

  String? get authToken;
  set authToken(String? token);

  Future<bool> checkHealth();
  Future<AppConfig> getConfig();

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
    bool consent = true,
    String? otp,
  });

  Future<AuthResponse> login({
    required String name,
    required String role,
    String? phone,
  });

  Future<List<BloodStockItem>> getStock();
  Future<List<BloodStockItem>> updateStock(List<BloodStockItem> stock);

  Future<BloodRequestResponse> createRequest({
    required String bloodGroup,
    required int units,
    required String hospital,
    required String urgency,
    required double lat,
    required double lng,
  });

  Future<List<BloodRequest>> getRequests({String status = 'open'});
  Future<String> acceptRequest(String requestId);
  Future<BloodRequest> fulfillRequest(String requestId);
  Future<BloodRequest> cancelRequest(String requestId);

  // V2 Addendum endpoints
  Future<Map<String, dynamic>> sendOtp(String phone);
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp);
  Future<Map<String, dynamic>> getMe();
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> getNotifications();
  Future<void> markNotificationRead(String id);
  Future<Map<String, dynamic>> recordDonation(String requestId);

  /// Factory constructor that returns either [MockApiClient] or [HttpApiClient]
  /// based on `--dart-define=USE_MOCK=true` or the explicit [mockMode] argument.
  factory ApiClient({
    String? baseUrl,
    bool? mockMode,
    String? authToken,
  }) {
    const useMockEnv = bool.fromEnvironment('USE_MOCK', defaultValue: false);
    final isMock = mockMode ?? useMockEnv;

    if (isMock) {
      return MockApiClient(
        baseUrl: baseUrl ?? ConfigConstants.localHostBaseUrl,
        authToken: authToken,
      );
    }

    return HttpApiClient(
      baseUrl: baseUrl ??
          const String.fromEnvironment('API_BASE',
              defaultValue: ConfigConstants.localHostBaseUrl),
      authToken: authToken,
      mockMode: false,
    );
  }
}

/// Real HTTP implementation of [ApiClient] that connects to the BloodLine REST API.
/// If [mockMode] is toggled to true at runtime, it falls back to an in-memory mock.
class HttpApiClient implements ApiClient {
  @override
  String baseUrl;

  @override
  bool mockMode;

  @override
  String? authToken;

  final http.Client _httpClient;
  late final MockApiClient _fallbackMock;

  HttpApiClient({
    this.baseUrl = ConfigConstants.localHostBaseUrl,
    this.authToken,
    this.mockMode = false,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _fallbackMock = MockApiClient(baseUrl: baseUrl, authToken: authToken);

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  @override
  Future<bool> checkHealth() async {
    if (mockMode) return true;
    try {
      final res = await _httpClient
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AppConfig> getConfig() async {
    if (mockMode) return _fallbackMock.getConfig();
    try {
      final res = await _httpClient
          .get(Uri.parse('$baseUrl/config'), headers: _headers())
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AppConfig.fromJson(data);
      }
    } catch (e) {
      debugPrint('[HttpApiClient] GET /config error: $e');
    }
    return const AppConfig();
  }

  @override
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
    bool consent = true,
    String? otp,
  }) async {
    if (mockMode) {
      final resp = await _fallbackMock.signup(
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
        consent: consent,
        otp: otp,
      );
      authToken = resp.token;
      return resp;
    }

    final body = <String, dynamic>{
      'name': name,
      'role': role,
      if (bloodGroup != null) 'blood_group': bloodGroup,
      'lat': lat,
      'lng': lng,
      if (phone != null) 'phone': phone,
      if (otp != null) 'otp': otp,
      if (age != null) 'age': age,
      if (weight != null) 'weight_kg': weight,
      if (height != null) 'height_cm': height,
      if (sex != null) 'sex': sex,
      'donated_before': donatedBefore,
      if (lastDonationDate != null)
        'last_donated_at': lastDonationDate.toIso8601String(),
      'consent': consent,
    };

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/auth/signup'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final parsed = AuthResponse.fromJson(data);
      authToken = parsed.token;
      return parsed;
    }
    throw ApiException(res.statusCode, 'Signup failed: ${res.body}');
  }

  @override
  Future<AuthResponse> login({
    required String name,
    required String role,
    String? phone,
  }) async {
    if (mockMode) {
      final resp = await _fallbackMock.login(name: name, role: role, phone: phone);
      authToken = resp.token;
      return resp;
    }

    final body = <String, dynamic>{
      'name': name,
      'role': role,
      if (phone != null) 'phone': phone,
    };

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final parsed = AuthResponse.fromJson(data);
      authToken = parsed.token;
      return parsed;
    }
    throw ApiException(res.statusCode, 'Login failed: ${res.body}');
  }

  @override
  Future<List<BloodStockItem>> getStock() async {
    if (mockMode) return _fallbackMock.getStock();

    final res = await _httpClient
        .get(Uri.parse('$baseUrl/banks/me/stock'), headers: _headers())
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final stockList = data['stock'] as List<dynamic>? ?? [];
      return stockList
          .map((item) => BloodStockItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(res.statusCode, 'Failed to fetch stock: ${res.body}');
  }

  @override
  Future<List<BloodStockItem>> updateStock(List<BloodStockItem> stock) async {
    if (mockMode) return _fallbackMock.updateStock(stock);

    final body = {
      'stock': stock
          .map((item) => {'blood_group': item.bloodGroup, 'units': item.units})
          .toList()
    };

    final res = await _httpClient
        .put(
          Uri.parse('$baseUrl/banks/me/stock'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final stockList = data['stock'] as List<dynamic>? ?? [];
      return stockList
          .map((item) => BloodStockItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(res.statusCode, 'Failed to update stock: ${res.body}');
  }

  @override
  Future<BloodRequestResponse> createRequest({
    required String bloodGroup,
    required int units,
    required String hospital,
    required String urgency,
    required double lat,
    required double lng,
  }) async {
    if (mockMode) {
      return _fallbackMock.createRequest(
        bloodGroup: bloodGroup,
        units: units,
        hospital: hospital,
        urgency: urgency,
        lat: lat,
        lng: lng,
      );
    }

    final body = {
      'blood_group': bloodGroup,
      'units': units,
      'hospital': hospital,
      'urgency': urgency,
      'lat': lat,
      'lng': lng,
    };

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/requests'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return BloodRequestResponse.fromJson(data);
    }
    throw ApiException(res.statusCode, 'Failed to create request: ${res.body}');
  }

  @override
  Future<List<BloodRequest>> getRequests({String status = 'open'}) async {
    if (mockMode) return _fallbackMock.getRequests(status: status);

    final res = await _httpClient
        .get(
          Uri.parse('$baseUrl/requests?status=$status'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = data['requests'] as List<dynamic>? ?? [];
      return list
          .map((item) => BloodRequest.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(res.statusCode, 'Failed to get requests: ${res.body}');
  }

  @override
  Future<String> acceptRequest(String requestId) async {
    if (mockMode) return _fallbackMock.acceptRequest(requestId);

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/requests/$requestId/accept'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['channel_id']?.toString() ?? 'req$requestId';
    }
    throw ApiException(res.statusCode, 'Failed to accept request: ${res.body}');
  }

  @override
  Future<BloodRequest> fulfillRequest(String requestId) async {
    if (mockMode) return _fallbackMock.fulfillRequest(requestId);

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/requests/$requestId/fulfill'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reqJson = data['request'] is Map<String, dynamic>
          ? data['request'] as Map<String, dynamic>
          : data;
      return BloodRequest.fromJson(reqJson);
    }
    throw ApiException(res.statusCode, 'Failed to fulfill request: ${res.body}');
  }

  @override
  Future<BloodRequest> cancelRequest(String requestId) async {
    if (mockMode) return _fallbackMock.cancelRequest(requestId);

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/requests/$requestId/cancel'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reqJson = data['request'] is Map<String, dynamic>
          ? data['request'] as Map<String, dynamic>
          : data;
      return BloodRequest.fromJson(reqJson);
    }
    throw ApiException(res.statusCode, 'Failed to cancel request: ${res.body}');
  }

  @override
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    if (mockMode) return _fallbackMock.sendOtp(phone);

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/auth/otp/send'),
          headers: _headers(),
          body: jsonEncode({'phone': phone}),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, 'Failed to send OTP: ${res.body}');
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    if (mockMode) return _fallbackMock.verifyOtp(phone, otp);

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/auth/verify'),
          headers: _headers(),
          body: jsonEncode({'phone': phone, 'otp': otp}),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['token'] != null) {
        authToken = data['token'].toString();
      }
      return data;
    }
    throw ApiException(res.statusCode, 'Failed to verify OTP: ${res.body}');
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    if (mockMode) return _fallbackMock.getMe();

    final res = await _httpClient
        .get(Uri.parse('$baseUrl/me'), headers: _headers())
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, 'Failed to fetch /me: ${res.body}');
  }

  @override
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    if (mockMode) return _fallbackMock.updateMe(data);

    final res = await _httpClient
        .put(
          Uri.parse('$baseUrl/me'),
          headers: _headers(),
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, 'Failed to update /me: ${res.body}');
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    if (mockMode) return _fallbackMock.getNotifications();

    final res = await _httpClient
        .get(Uri.parse('$baseUrl/notifications'), headers: _headers())
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = data['notifications'] as List<dynamic>? ?? [];
      return list.cast<Map<String, dynamic>>();
    }
    throw ApiException(
        res.statusCode, 'Failed to get notifications: ${res.body}');
  }

  @override
  Future<void> markNotificationRead(String id) async {
    if (mockMode) return _fallbackMock.markNotificationRead(id);

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/notifications/$id/read'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw ApiException(
          res.statusCode, 'Failed to mark notification read: ${res.body}');
    }
  }

  @override
  Future<Map<String, dynamic>> recordDonation(String requestId) async {
    if (mockMode) return _fallbackMock.recordDonation(requestId);

    final res = await _httpClient
        .post(
          Uri.parse('$baseUrl/requests/$requestId/donated'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(
        res.statusCode, 'Failed to record donation: ${res.body}');
  }
}

/// In-memory mock implementation of [ApiClient] for offline demo & tests.
class MockApiClient implements ApiClient {
  @override
  String baseUrl;

  @override
  bool mockMode;

  @override
  String? authToken;

  MockApiClient({
    this.baseUrl = ConfigConstants.localHostBaseUrl,
    this.mockMode = true,
    this.authToken,
  });

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

  static final List<Map<String, dynamic>> _mockNotifications = [
    {
      'id': 'n1',
      'type': 'eligible_again',
      'title': 'Ready to save lives again?',
      'body':
          'Your blood has had 90 days to recharge. Ready to be somebody\'s hero again?',
      'created_at': DateTime.now().toIso8601String(),
      'read': false,
    },
  ];

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<AppConfig> getConfig() async {
    return const AppConfig(
      features: ['ranks', 'reminders'],
      demoMode: true,
    );
  }

  @override
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
    bool consent = true,
    String? otp,
  }) async {
    final mockId = 'u${DateTime.now().millisecondsSinceEpoch % 100000}';
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
      consent: consent,
    );
    final mockToken = 'mock_jwt_$mockId';
    authToken = mockToken;
    return AuthResponse(
      user: mockUser,
      token: mockToken,
      nexconnToken: 'mock_chat_token_$mockId',
    );
  }

  @override
  Future<AuthResponse> login({
    required String name,
    required String role,
    String? phone,
  }) async {
    final mockId =
        'u${name.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
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

  @override
  Future<List<BloodStockItem>> getStock() async {
    return _mockStock.entries
        .map((e) => BloodStockItem(
              bloodGroup: e.key,
              units: e.value,
              updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
            ))
        .toList();
  }

  @override
  Future<List<BloodStockItem>> updateStock(List<BloodStockItem> stock) async {
    for (final item in stock) {
      _mockStock[item.bloodGroup] = item.units;
    }
    return getStock();
  }

  @override
  Future<BloodRequestResponse> createRequest({
    required String bloodGroup,
    required int units,
    required String hospital,
    required String urgency,
    required double lat,
    required double lng,
  }) async {
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

  @override
  Future<List<BloodRequest>> getRequests({String status = 'open'}) async {
    if (status == 'all') {
      return List.unmodifiable(_mockRequests);
    }
    return _mockRequests.where((r) => r.status == status).toList();
  }

  @override
  Future<String> acceptRequest(String requestId) async {
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final req = _mockRequests[index];
      _mockRequests[index] = req.copyWith(joined: true);
      return req.channelId;
    }
    return 'req$requestId';
  }

  @override
  Future<BloodRequest> fulfillRequest(String requestId) async {
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final updated = _mockRequests[index].copyWith(status: 'fulfilled');
      _mockRequests[index] = updated;
      return updated;
    }
    throw ApiException(404, 'Request not found');
  }

  @override
  Future<BloodRequest> cancelRequest(String requestId) async {
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final updated = _mockRequests[index].copyWith(status: 'cancelled');
      _mockRequests[index] = updated;
      return updated;
    }
    throw ApiException(404, 'Request not found');
  }

  @override
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    return {'sent': true, 'demo': true};
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    if (otp != '123456' && !otp.startsWith('123')) {
      throw ApiException(401, 'Invalid OTP');
    }
    final isNew = phone.contains('new') || phone.endsWith('999') || phone.endsWith('000');
    if (isNew) {
      return {'is_new': true, 'demo': true};
    }
    return {
      'is_new': false,
      'demo': true,
      'token': 'mock_token_$phone',
      'nexconn_token': 'mock_nexconn_token_$phone',
      'user': {
        'id': 'u1',
        'name': 'Demo User',
        'role': 'donor',
        'blood_group': 'O+',
        'lat': ConfigConstants.defaultLatitude,
        'lng': ConfigConstants.defaultLongitude,
      }
    };
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    return {
      'user': {
        'id': 'u1',
        'name': 'Demo User',
        'role': 'donor',
        'blood_group': 'O+',
        'lat': ConfigConstants.defaultLatitude,
        'lng': ConfigConstants.defaultLongitude,
      },
      'derived': {
        'eligible': true,
        'next_eligible_at': null,
        'donation_count': 3,
        'rank': {'key': 'helper', 'label': 'Helper'}
      }
    };
  }

  @override
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    return getMe();
  }

  @override
  Future<List<Map<String, dynamic>>> getNotifications() async {
    return List.unmodifiable(_mockNotifications);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final index = _mockNotifications.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      _mockNotifications[index]['read'] = true;
    }
  }

  @override
  Future<Map<String, dynamic>> recordDonation(String requestId) async {
    final index = _mockRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _mockRequests[index] = _mockRequests[index].copyWith(donated: true);
    }
    return {
      'donation': {
        'id': 'd1',
        'request_id': requestId,
        'donated_at': DateTime.now().toIso8601String(),
      },
      'donation_count': 4,
    };
  }
}
