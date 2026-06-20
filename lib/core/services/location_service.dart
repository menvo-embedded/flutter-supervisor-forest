import 'package:geolocator/geolocator.dart' as geo;

class LocationData {
  final double latitude, longitude;
  final DateTime timestamp;
  final double accuracy;
  const LocationData({required this.latitude,required this.longitude,required this.timestamp,this.accuracy=0});
}

class LocationService {
  Future<LocationData> getCurrentLocation() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ định vị GPS bị tắt trên thiết bị.');
    }

    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        throw Exception('Quyền truy cập vị trí bị từ chối.');
      }
    }
    
    if (permission == geo.LocationPermission.deniedForever) {
      throw Exception('Quyền truy cập vị trí bị từ chối vĩnh viễn, vui lòng cho phép trong Cài đặt.');
    }

    final pos = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );

    return LocationData(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: pos.timestamp,
      accuracy: pos.accuracy,
    );
  }

  Future<bool> isEnabled() async {
    return await geo.Geolocator.isLocationServiceEnabled();
  }
}
