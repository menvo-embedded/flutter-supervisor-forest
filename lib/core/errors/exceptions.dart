/// Exception ném ra từ Data Layer (datasource) - được Repository bắt và
/// chuyển đổi sang Failure tương ứng để trả về Either<Failure, T>
class ServerException implements Exception {
  final String message; final int? code;
  ServerException(this.message, [this.code]);
}
class CacheException implements Exception {
  final String message; CacheException(this.message);
}
class AuthException implements Exception {
  final String message; AuthException(this.message);
}
class GpsException implements Exception {
  final String message; GpsException([this.message='Không thể lấy vị trí GPS']);
}
