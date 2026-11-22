import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationSource { gps, preset, typed }

enum LocationErrorType {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  other,
}

class LocationError {
  final LocationErrorType type;
  final String message;
  final String? actionLabel;

  const LocationError({
    required this.type,
    required this.message,
    this.actionLabel,
  });
}

class LocationController extends ChangeNotifier {
  LocationSource? _source;
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  String? _label;
  bool _isFetching = false;
  LocationError? _lastError;

  LocationController({
    LocationSource? initialSource,
    double? initialLat,
    double? initialLng,
    String? initialLabel,
  }) {
    if (initialLat != null && initialLng != null && (initialLat != 0.0 || initialLng != 0.0)) {
      _source = initialSource ?? LocationSource.preset;
      _latitude = initialLat;
      _longitude = initialLng;
      _label = initialLabel;
    }
  }

  LocationSource? get source => _source;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get accuracy => _accuracy;
  String? get label => _label;
  bool get isFetching => _isFetching;
  LocationError? get lastError => _lastError;

  bool get hasLocation => _latitude != null && _longitude != null;

  /// Returns user-facing location text:
  /// - "Location not set" if unset
  /// - "Using GPS (±N m): lat, lng" if from GPS
  /// - "Label (lat, lng)" if preset or typed
  String get displayText {
    if (!hasLocation) {
      return 'Location not set';
    }
    if (_source == LocationSource.gps) {
      final acc = _accuracy != null ? ' (±${_accuracy!.round()} m)' : '';
      return 'Using GPS$acc: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}';
    }
    if (_source == LocationSource.preset || _source == LocationSource.typed) {
      final name = (_label != null && _label!.isNotEmpty) ? _label! : 'Custom';
      return '$name (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})';
    }
    return _label ?? 'Location not set';
  }

  /// Sets a preset area. Last choice wins.
  void setPreset(String name, double lat, double lng) {
    _source = LocationSource.preset;
    _latitude = lat;
    _longitude = lng;
    _label = name;
    _accuracy = null;
    _lastError = null;
    notifyListeners();
  }

  /// Sets a typed area or custom address. Last choice wins.
  void setTyped(String name, [double? lat, double? lng]) {
    _source = LocationSource.typed;
    _label = name;
    if (lat != null && lng != null) {
      _latitude = lat;
      _longitude = lng;
    }
    _accuracy = null;
    _lastError = null;
    notifyListeners();
  }

  /// Clears the location, resetting to "Location not set".
  void clear() {
    _source = null;
    _latitude = null;
    _longitude = null;
    _accuracy = null;
    _label = null;
    _lastError = null;
    notifyListeners();
  }

  /// Clears preset or typed selection when choosing GPS.
  void clearPreset() {
    if (_source == LocationSource.preset || _source == LocationSource.typed) {
      _source = null;
      _label = null;
    }
  }

  /// Requests high-accuracy GPS with 15s timeout, falling back to last known position.
  /// Specific error handling for services off, denied, denied forever, and timeout.
  Future<bool> fetchGpsLocation() async {
    // Choosing GPS clears preset selection
    clearPreset();
    _isFetching = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastError = const LocationError(
          type: LocationErrorType.servicesDisabled,
          message: 'Location services are turned off. Please turn them on in settings.',
          actionLabel: 'Open Location Settings',
        );
        _isFetching = false;
        notifyListeners();
        return false;
      }

      // 2. Check and request precise permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _lastError = const LocationError(
            type: LocationErrorType.permissionDenied,
            message: 'Location permission was denied. Tap to retry.',
            actionLabel: 'Retry',
          );
          _isFetching = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _lastError = const LocationError(
          type: LocationErrorType.permissionDeniedForever,
          message: 'Location permission is permanently denied. Please enable it in app settings.',
          actionLabel: 'Open App Settings',
        );
        _isFetching = false;
        notifyListeners();
        return false;
      }

      // 3. High accuracy with 15-second timeout, falling back to getLastKnownPosition
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } on TimeoutException {
        debugPrint('[LocationController] getCurrentPosition timed out after 15s, trying getLastKnownPosition');
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          _lastError = const LocationError(
            type: LocationErrorType.timeout,
            message: 'Location request timed out after 15 seconds. Please try again or select a preset.',
            actionLabel: 'Retry',
          );
          _isFetching = false;
          notifyListeners();
          return false;
        }
      } catch (e) {
        debugPrint('[LocationController] getCurrentPosition error: $e, trying getLastKnownPosition');
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          _lastError = LocationError(
            type: LocationErrorType.other,
            message: 'Unable to get GPS location: $e',
          );
          _isFetching = false;
          notifyListeners();
          return false;
        }
      }

      // Success
      _source = LocationSource.gps;
      _latitude = position.latitude;
      _longitude = position.longitude;
      _accuracy = position.accuracy;
      _label = 'Using GPS (±${position.accuracy.round()} m)';
      _lastError = null;
      _isFetching = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[LocationController] GPS fetch error: $e');
      _lastError = LocationError(
        type: LocationErrorType.other,
        message: 'Location error: $e',
      );
      _isFetching = false;
      notifyListeners();
      return false;
    }
  }

  /// Handles action for the current error (e.g. opening settings)
  Future<void> handleAction() async {
    if (_lastError == null) return;
    switch (_lastError!.type) {
      case LocationErrorType.servicesDisabled:
        await Geolocator.openLocationSettings();
        break;
      case LocationErrorType.permissionDeniedForever:
        await Geolocator.openAppSettings();
        break;
      case LocationErrorType.permissionDenied:
      case LocationErrorType.timeout:
        await fetchGpsLocation();
        break;
      case LocationErrorType.other:
        break;
    }
  }
}
