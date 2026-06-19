// FILE: lib/data/logbook/datasources/logbook_local_data_source.dart
import 'dart:convert';
import '../../../core/services/storage_service.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';
import '../models/logbook_model.dart';

abstract class LogbookLocalDataSource {
  Future<LogbookModel>       saveLogbook(LogbookModel logbook);
  Future<List<LogbookModel>> getAll({String? userId});
  Future<List<LogbookModel>> getUnsynced();
  Future<void>               markSynced(String localId, String serverId);
}

/// Offline Storage cho nhật ký — dùng StorageService (key-value JSON).
///
/// PRODUCTION → thay bằng Isar:
/// @collection
/// class LogbookIsarModel {
///   Id isarId = Isar.autoIncrement;
///   @Index() late String localId;
///   String?  serverId, projectId;
///   late String jobType, description, userId, userName;
///   late List<String> imagePaths;
///   late double latitude, longitude;
///   late DateTime timestamp;
///   late bool isSynced;
///   late String syncStatus;
/// }
class LogbookLocalDataSourceImpl implements LogbookLocalDataSource {
  static const _key = 'qlr_logbooks_v2';
  final StorageService _storage;

  LogbookLocalDataSourceImpl({StorageService? storage})
    : _storage = storage ?? StorageService();

  // ─── helpers ────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await _storage.getString(_key);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> items) =>
    _storage.setString(_key, jsonEncode(items));

  LogbookModel _parse(Map<String, dynamic> j) =>
    LogbookModel.fromEntity(LogbookEntity.fromJson(j));

  // ─── interface impl ──────────────────────────────────────────────────
  @override
  Future<LogbookModel> saveLogbook(LogbookModel logbook) async {
    final items = await _read();
    // Gán localId nếu chưa có
    final id = logbook.id ?? 'local_${DateTime.now().millisecondsSinceEpoch}';
    final saved = LogbookModel.fromEntity(logbook.copyWith(id: id));
    items.insert(0, saved.toJson());
    await _write(items);
    return saved;
  }

  @override
  Future<List<LogbookModel>> getAll({String? userId}) async {
    final items = await _read();
    return items
      .where((e) => userId == null || e['userId'] == userId)
      .map(_parse)
      .toList();
  }

  @override
  Future<List<LogbookModel>> getUnsynced() async {
    final items = await _read();
    return items
      .where((e) => e['isSynced'] == false)
      .map(_parse)
      .toList();
  }

  @override
  Future<void> markSynced(String localId, String serverId) async {
    final items = await _read();
    final idx = items.indexWhere((e) => e['id'] == localId);
    if (idx != -1) {
      items[idx]['isSynced']   = true;
      items[idx]['syncStatus'] = 'synced';
      items[idx]['serverId']   = serverId;
    }
    await _write(items);
  }
}
