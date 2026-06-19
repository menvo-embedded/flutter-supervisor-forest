class LocationData {
  final double latitude, longitude;
  final DateTime timestamp;
  final double accuracy;
  const LocationData({required this.latitude,required this.longitude,required this.timestamp,this.accuracy=0});
}
class LocationService {
  Future<LocationData> getCurrentLocation() async {
    // Production: Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
    await Future.delayed(const Duration(milliseconds: 800));
    return LocationData(latitude:12.345678, longitude:108.234567, timestamp:DateTime.now(), accuracy:4.5);
  }
  Future<bool> isEnabled() async {
    // Production: Geolocator.isLocationServiceEnabled()
    return true;
  }
}
