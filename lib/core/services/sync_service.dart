import 'dart:convert';
import '../constants/app_constants.dart';
import 'storage_service.dart';

/// Quản lý hàng đợi đồng bộ khi offline → online
class SyncService {
  static final SyncService _i = SyncService._();
  factory SyncService() => _i;
  SyncService._();

  final StorageService _storage = StorageService();

  Future<List<Map<String,dynamic>>> getPendingItems() async {
    final raw = await _storage.getString(AppConstants.pendingKey);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String,dynamic>>.from(jsonDecode(raw));
  }

  Future<void> addPending(Map<String,dynamic> item) async {
    final list = await getPendingItems();
    list.add({...item, 'queuedAt': DateTime.now().toIso8601String()});
    await _storage.setString(AppConstants.pendingKey, jsonEncode(list));
  }

  Future<void> removePending(String id) async {
    final list = await getPendingItems();
    list.removeWhere((e) => e['localId'] == id);
    await _storage.setString(AppConstants.pendingKey, jsonEncode(list));
  }

  Future<int> pendingCount() async => (await getPendingItems()).length;
}
