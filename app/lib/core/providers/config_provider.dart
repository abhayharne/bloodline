import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import '../api_client.dart';
import '../../features/ranks/register.dart';

class ConfigProvider extends ChangeNotifier {
  final ApiClient apiClient;
  AppConfig _config = const AppConfig();
  bool _isLoading = false;

  AppConfig get config => _config;
  bool get isLoading => _isLoading;

  ConfigProvider({required this.apiClient});

  Future<void> fetchConfig() async {
    _isLoading = true;
    notifyListeners();

    try {
      _config = await apiClient.getConfig();
      registerRanksFeature(config: _config);
    } catch (e) {
      debugPrint('[ConfigProvider] fetchConfig error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
