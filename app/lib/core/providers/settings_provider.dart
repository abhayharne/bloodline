import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for app-wide settings including accessibility font scaling.
class SettingsProvider extends ChangeNotifier {
  static const String _prefLargeFontKey = 'bloodline_large_font';

  bool _isLargeFont = false;
  bool _isLoaded = false;

  bool get isLargeFont => _isLargeFont;
  bool get isLoaded => _isLoaded;

  /// Returns the TextScaler configured for accessibility.
  /// Flutter 3.16+ uses TextScaler rather than double textScaleFactor.
  TextScaler get textScaler =>
      _isLargeFont ? const TextScaler.linear(1.3) : const TextScaler.linear(1.0);

  /// Double scale factor representation for display purposes.
  double get textScaleFactor => _isLargeFont ? 1.3 : 1.0;

  /// Voice-to-text requires platform-specific audio recording permissions
  /// (RECORD_AUDIO on Android, NSSpeechRecognition on iOS) and native speech
  /// recognition services which require real device/hardware setup.
  bool get isVoiceToTextSupported => false;
  String get voiceToTextStatus =>
      'Requires platform-specific speech engine permissions and audio input hardware.';

  SettingsProvider({bool initialLargeFont = false}) : _isLargeFont = initialLargeFont;

  /// Loads saved user settings from SharedPreferences.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLargeFont = prefs.getBool(_prefLargeFontKey) ?? _isLargeFont;
    } catch (_) {}
    _isLoaded = true;
    notifyListeners();
  }

  /// Updates large font setting and persists preference.
  Future<void> setLargeFont(bool value) async {
    if (_isLargeFont == value) return;
    _isLargeFont = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefLargeFontKey, value);
    } catch (_) {}
  }

  /// Toggles large font state.
  Future<void> toggleLargeFont() => setLargeFont(!_isLargeFont);
}
