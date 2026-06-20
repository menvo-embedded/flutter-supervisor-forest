import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  // Singleton
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> setSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> getSecure(String key) async {
    return _secureStorage.read(key: key);
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await _secureStorage.delete(key: key);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
  }
}
