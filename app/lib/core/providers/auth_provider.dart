import 'dart:async';
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
  bool _isRestoring = false;
  String? _sessionNotice;

  User? get currentUser => _currentUser;
  UserDerived? get derived => _derived;
  String? get token => _token;
  String? get nexconnToken => _nexconnToken;
  bool get isAuthenticated => _currentUser != null && _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isRestoring => _isRestoring;
  String? get sessionNotice => _sessionNotice;

  AuthProvider({required this.apiClient});

  void setCurrentUserForTesting(User user, {String token = 'test_token'}) {
    _currentUser = user;
    _token = token;
    notifyListeners();
  }

  static const _kUserPrefKey = 'bloodline_user_v1';
  static const _kTokenPrefKey = 'bloodline_jwt_token_v1';
  static const _kNexconnTokenPrefKey = 'bloodline_nexconn_token_v1';

  Future<void> init() async {
    _isRestoring = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_kUserPrefKey);
      final token = prefs.getString(_kTokenPrefKey);
      final nexconnToken = prefs.getString(_kNexconnTokenPrefKey);

      if (userJson != null && token != null) {
        _currentUser = User.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        _token = token;
        _nexconnToken = nexconnToken;
        apiClient.authToken = token;

        // Fetch derived profile & rank
        await fetchMe();
        if (_token == token &&
            nexconnToken != null &&
            nexconnToken.isNotEmpty) {
          _connectChat(nexconnToken);
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] init session restoration error: $e');
    } finally {
      _isRestoring = false;
      notifyListeners();
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
      if (res['user'] != null && res['is_new'] != true) {
        await _saveSession(AuthResponse.fromJson(res));
      }
      return res;
    } on ApiException catch (e) {
      if (e.statusCode == 404 && e.message == 'user not found') {
        return {'is_new': true};
      }
      _error = e.message;
      rethrow;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile(User updatedUser) async {
    final response = await apiClient.updateMe({
      'lat': updatedUser.lat,
      'lng': updatedUser.lng,
      if (updatedUser.weight != null) 'weight_kg': updatedUser.weight,
      if (updatedUser.height != null) 'height_cm': updatedUser.height,
      'last_donated_at':
          updatedUser.lastDonationDate?.toIso8601String().split('T').first ??
          '',
      'apheresis_ok': updatedUser.canDonatePlatelets,
    });
    final derived = response['derived'];
    if (derived is Map<String, dynamic>) {
      _derived = UserDerived.fromJson(derived);
    }
    await updateProfile(updatedUser);
  }

  Future<void> updateProfile(User updatedUser) async {
    _currentUser = updatedUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserPrefKey, jsonEncode(updatedUser.toJson()));
    notifyListeners();
  }

  Future<void> fetchMe() async {
    final token = _token;
    try {
      final res = await apiClient.getMe();
      if (token != _token) return;
      final data = res['user'];
      if (data is Map<String, dynamic>) {
        final serverUser = User.fromJson(data);
        final current = _currentUser;
        if (current == null) {
          _currentUser = serverUser;
        } else if (!apiClient.mockMode &&
            current.id == serverUser.id &&
            current.role != serverUser.role) {
          await updateProfile(current.copyWith(role: serverUser.role));
        }
      }
      if (res['derived'] != null && res['derived'] is Map) {
        _derived = UserDerived.fromJson(
          Map<String, dynamic>.from(res['derived'] as Map),
        );
      }
      notifyListeners();
    } on ApiException catch (e) {
      if (token != _token) return;
      if (e.statusCode == 401 || e.statusCode == 404) {
        await logout();
        _sessionNotice = e.statusCode == 404
            ? 'The demo has reset. Please register again using fictional details.'
            : 'Your session has expired. Please sign in again.';
        notifyListeners();
      } else {
        debugPrint('[AuthProvider] fetchMe error: $e');
      }
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
    _sessionNotice = null;
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
    _sessionNotice = null;
    _currentUser = resp.user;
    _token = resp.token;
    _nexconnToken = resp.nexconnToken;
    apiClient.authToken = resp.token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserPrefKey, jsonEncode(resp.user.toJson()));
    await prefs.setString(_kTokenPrefKey, resp.token);
    await prefs.setString(_kNexconnTokenPrefKey, resp.nexconnToken);

    // The API session is usable before the native chat connection finishes.
    if (resp.nexconnToken.isNotEmpty) _connectChat(resp.nexconnToken);
    unawaited(fetchMe());
  }

  void _connectChat(String token) {
    unawaited(
      NexconnService.instance
          .connect(token)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              debugPrint(
                '[AuthProvider] Chat connection failed: ${error.runtimeType}',
              );
            },
          ),
    );
  }
}
