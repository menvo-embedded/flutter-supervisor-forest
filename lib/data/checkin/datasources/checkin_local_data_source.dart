import 'dart:convert';
import '../../../core/services/storage_service.dart';
import '../../../domain/checkin/entities/checkin_entity.dart';
import '../models/checkin_model.dart';

abstract class CheckinLocalDataSource {
  Future<CheckinModel> save(CheckinModel item);
  Future<List<CheckinModel>> getAll({String? userId});
  Future<List<CheckinModel>> getUnsynced();
  Future<void> markSynced(String localId, String serverId);
  Future<void> saveAll(List<CheckinModel> checkins);
}

/// Local DB cho Check-in (PRODUCTION: Isar collection riêng `CheckinModelIsar`)
class CheckinLocalDataSourceImpl implements CheckinLocalDataSource {
  static const _key = 'qlr_checkins_db';
  final StorageService _storage;
  CheckinLocalDataSourceImpl({StorageService? storage}) : _storage = storage ?? StorageService();

  Future<List<Map<String,dynamic>>> _readAll() async {
    final raw = await _storage.getString(_key);
    return raw==null ? [] : List<Map<String,dynamic>>.from(jsonDecode(raw));
  }
  Future<void> _writeAll(List<Map<String,dynamic>> items) async =>
    _storage.setString(_key, jsonEncode(items));

  @override
  Future<CheckinModel> save(CheckinModel item) async {
    final items = await _readAll();
    final id = item.id ?? 'local_chk_${DateTime.now().millisecondsSinceEpoch}';
    final saved = CheckinModel.fromEntity(CheckinEntity(
      id:id, userId:item.userId, userName:item.userName,
      latitude:item.latitude, longitude:item.longitude,
      timestamp:item.timestamp, type:item.type,
      isSynced:item.isSynced, note:item.note, projectId:item.projectId));
    items.insert(0, saved.toJson());
    await _writeAll(items);
    return saved;
  }

  @override
  Future<List<CheckinModel>> getAll({String? userId}) async {
    final items = await _readAll();
    return items.where((e)=>userId==null || e['userId']==userId)
      .map((e)=>CheckinModel.fromEntity(CheckinEntity.fromJson(e))).toList();
  }

  @override
  Future<List<CheckinModel>> getUnsynced() async {
    final items = await _readAll();
    return items.where((e)=>e['isSynced']==false)
      .map((e)=>CheckinModel.fromEntity(CheckinEntity.fromJson(e))).toList();
  }

  @override
  Future<void> markSynced(String localId, String serverId) async {
    final items = await _readAll();
    final idx = items.indexWhere((e)=>e['id']==localId);
    if (idx!=-1) { items[idx]['isSynced']=true; items[idx]['serverId']=serverId; }
    await _writeAll(items);
  }

  @override
  Future<void> saveAll(List<CheckinModel> checkins) async {
    final items = await _readAll();
    for (final checkin in checkins) {
      final idx = items.indexWhere((e) =>
          (e['serverId'] != null && e['serverId'] == checkin.serverId) ||
          (e['id'] != null && e['id'] == checkin.serverId) ||
          (e['serverId'] != null && e['serverId'] == checkin.id) ||
          (e['id'] != null && e['id'] == checkin.id));
      if (idx != -1) {
        final localId = items[idx]['id'];
        final updatedJson = checkin.toJson();
        updatedJson['id'] = localId; // Giữ nguyên local ID
        items[idx] = updatedJson;
      } else {
        items.insert(0, checkin.toJson());
      }
    }
    await _writeAll(items);
  }
}
