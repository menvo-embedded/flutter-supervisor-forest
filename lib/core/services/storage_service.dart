// Production: import 'package:shared_preferences/shared_preferences.dart';
// Production: import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  // Singleton
  static final StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  StorageService._();

  final Map<String,String> _store = {}; // mock in-memory store

  Future<void> setString(String key, String value) async {
    // Production: final prefs = await SharedPreferences.getInstance(); prefs.setString(key, value);
    _store[key] = value;
  }
  Future<String?> getString(String key) async {
    return _store[key];
  }
  Future<void> setSecure(String key, String value) async {
    // Production: const FlutterSecureStorage().write(key:key, value:value);
    _store['_sec_$key'] = value;
  }
  Future<String?> getSecure(String key) async {
    return _store['_sec_$key'];
  }
  Future<void> remove(String key) async {
    _store.remove(key); _store.remove('_sec_$key');
  }
  Future<void> clearAll() async { _store.clear(); }
}
