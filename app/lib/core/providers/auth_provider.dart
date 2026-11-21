import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/user_derived.dart';
import '../models/auth_response.dart';
import '../api_client.dart';
import '../nexconn_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient apiClient;
  User? _currentUser;
  UserDerived? _derived;
  String? _token;
  String? _nexconnToken;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  UserDerived? get derived => _derived;
  String? get token => _token;
  String? get nexconnToken => _nexconnToken;
  bool get isAuthenticated => _currentUser != null && _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider({required this.apiClient});

  static const _kUserPrefKey = 'bloodline_user_v1';
  static const _kTokenPrefKey = 'bloodline_jwt_token_v1';
  static const _kNexconnTokenPrefKey = 'bloodline_nexconn_token_v1';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_kUserPrefKey);
      final token = prefs.getString(_kTokenPrefKey);
      final nexconnToken = prefs.getString(_kNexconnTokenPrefKey);

      if (userJson != null && token != null) {
        _currentUser = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        _token = token;
        _nexconnToken = nexconnToken;
        apiClient.authToken = token;

        if (nexconnToken != null && nexconnToken.isNotEmpty) {
          NexconnService.instance.connect(nexconnToken);
        }
        notifyListeners();
        // Fetch derived profile & rank
        await fetchMe();
      }
    } catch (e) {
      debugPrint('[AuthProvider] init session restoration error: $e');
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await apiClient.sendOtp(phone);
      _isLoading = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await apiClient.verifyOtp(phone, otp);
      if (res['is_new'] == false && res['user'] != null) {
        final authResp = AuthResponse.fromJson(res);
        await _saveSession(authResp);
      }
      _isLoading = false;
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> login({
    required String name,
    required String role,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await apiClient.login(name: name, role: role, phone: phone);
      await _saveSession(resp);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await apiClient.signup(
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
      await _saveSession(resp);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(User updatedUser) async {
    _currentUser = updatedUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserPrefKey, jsonEncode(updatedUser.toJson()));
    notifyListeners();
  }

  Future<void> fetchMe() async {
    try {
      final res = await apiClient.getMe();
      if (_currentUser == null && res['user'] != null && res['user'] is Map) {
        _currentUser = User.fromJson(Map<String, dynamic>.from(res['user'] as Map));
      }
      if (res['derived'] != null && res['derived'] is Map) {
        _derived = UserDerived.fromJson(Map<String, dynamic>.from(res['derived'] as Map));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] fetchMe error: $e');
    }
  }

  void updateDonationCount(int count) {
    final current = _derived ?? const UserDerived();
    _derived = current.copyWith(
      donationCount: count,
      rank: UserRank.fromDonationCount(count) ?? current.rank,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _derived = null;
    _token = null;
    _nexconnToken = null;
    apiClient.authToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserPrefKey);
    await prefs.remove(_kTokenPrefKey);
    await prefs.remove(_kNexconnTokenPrefKey);

    await NexconnService.instance.disconnect();
    notifyListeners();
  }

  Future<void> _saveSession(AuthResponse resp) async {
    _currentUser = resp.user;
    _token = resp.token;
    _nexconnToken = resp.nexconnToken;
    apiClient.authToken = resp.token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserPrefKey, jsonEncode(resp.user.toJson()));
    await prefs.setString(_kTokenPrefKey, resp.token);
    await prefs.setString(_kNexconnTokenPrefKey, resp.nexconnToken);

    // Auto connect chat SDK
    if (resp.nexconnToken.isNotEmpty) {
      await NexconnService.instance.connect(resp.nexconnToken);
    }

    await fetchMe();
  }
}
