import 'package:geolocator/geolocator.dart';

class LocationData {
  final double latitude, longitude;
  final DateTime timestamp;
  final double accuracy;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy = 0,
  });
}

class LocationException implements Exception {
  final String message;

  const LocationException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  static const permissionMessage = 'Vui lòng cấp quyền vị trí để check-in GPS.';

  Future<LocationData> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException(
        'Vui lòng bật dịch vụ vị trí để check-in GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException(permissionMessage);
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        '$permissionMessage Hãy mở Cài đặt ứng dụng để cấp quyền vị trí.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
    );
  }

  Future<bool> isEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }
}
