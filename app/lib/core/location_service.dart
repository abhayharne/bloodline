import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'config.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String label;
  final bool isGps;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.isGps,
  });

  static const LocationData defaultNagpur = LocationData(
    latitude: ConfigConstants.defaultLatitude,
    longitude: ConfigConstants.defaultLongitude,
    label: 'Nagpur Central, MH',
    isGps: false,
  );
}

class TypedArea {
  final String name;
  final double lat;
  final double lng;

  const TypedArea(this.name, this.lat, this.lng);
}

/// Fallback presets for typed-area selection
const List<TypedArea> kPopularAreas = [
  TypedArea('Nagpur Central (Sitabuldi)', 21.1458, 79.0882),
  TypedArea('Civil Lines, Nagpur', 21.1550, 79.0720),
  TypedArea('Dharampeth, Nagpur', 21.1400, 79.0600),
  TypedArea('Ramdaspeth, Nagpur', 21.1320, 79.0760),
  TypedArea('Medical Square / GMC', 21.1270, 79.0980),
  TypedArea('Dhantoli, Nagpur', 21.1310, 79.0840),
  TypedArea('Wardha Road, Nagpur', 21.0900, 79.0650),
  TypedArea('Custom Location', 0.0, 0.0),
];

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Attempt to fetch device GPS coordinates. Returns null if permission denied or unavailable.
  Future<LocationData?> getDeviceLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
        isGps: true,
      );
    } catch (e) {
      debugPrint('[LocationService] Location query failed: $e');
      return null;
    }
  }
}
