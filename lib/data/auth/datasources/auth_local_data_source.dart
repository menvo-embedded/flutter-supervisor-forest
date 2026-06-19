import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getCachedUser();
  Future<void> clearSession();
}

/// Lưu phiên đăng nhập (token + thông tin user) vào SecureStorage
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final StorageService _storage;
  AuthLocalDataSourceImpl({StorageService? storage}) : _storage = storage ?? StorageService();

  @override
  Future<void> cacheUser(UserModel user) async {
    await _storage.setSecure(AppConstants.tokenKey, user.token);
    await _storage.setString(AppConstants.userKey, user.toJsonString());
  }

  @override
  Future<UserModel?> getCachedUser() async {
    final raw = await _storage.getString(AppConstants.userKey);
    if (raw == null) return null;
    return UserModel.fromJsonString(raw);
  }

  @override
  Future<void> clearSession() async {
    await _storage.remove(AppConstants.tokenKey);
    await _storage.remove(AppConstants.userKey);
  }
}
