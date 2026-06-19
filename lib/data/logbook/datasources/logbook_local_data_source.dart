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
  Future<void>               saveAll(List<LogbookModel> logbooks);
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
  List<Map<String, dynamic>> _getSeedLogs() {
    final now = DateTime.now();
    return [
      {
        'id': 'mock_1',
        'serverId': 'srv_mock_1',
        'projectId': 'DAK01',
        'jobType': 'planting',
        'description': 'Tiến hành trồng 150 cây sao đen tại phân khu A1 của dự án Dak Lak. Thời tiết mát mẻ thuận lợi.',
        'userId': 'worker_01',
        'userName': 'Nguyễn Văn Hùng',
        'imagePaths': <String>[],
        'latitude': 12.6667,
        'longitude': 108.0500,
        'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'isSynced': true,
        'syncStatus': 'synced',
      },
      {
        'id': 'mock_2',
        'serverId': 'srv_mock_2',
        'projectId': 'VDB01',
        'jobType': 'patrol',
        'description': 'Tuần tra bảo vệ rừng khu vực giáp ranh Tây Nguyên. Phát hiện một số điểm nguy cơ cháy cao đã xử lý phát dọn.',
        'userId': 'worker_02',
        'userName': 'Trần Thanh Sơn',
        'imagePaths': <String>[],
        'latitude': 12.7100,
        'longitude': 108.1200,
        'timestamp': now.subtract(const Duration(hours: 5)).toIso8601String(),
        'isSynced': true,
        'syncStatus': 'synced',
      },
      {
        'id': 'mock_3',
        'serverId': 'srv_mock_3',
        'projectId': 'KEO01',
        'jobType': 'growth_inspection',
        'description': 'Kiểm tra đo đạc chiều cao và đường kính thân cây keo lai 2 năm tuổi tại ô mẫu số 4. Sinh trưởng tốt.',
        'userId': 'worker_01',
        'userName': 'Nguyễn Văn Hùng',
        'imagePaths': <String>[],
        'latitude': 12.6200,
        'longitude': 107.9800,
        'timestamp': now.subtract(const Duration(days: 1)).toIso8601String(),
        'isSynced': true,
        'syncStatus': 'synced',
      },
      {
        'id': 'mock_4',
        'serverId': 'srv_mock_4',
        'projectId': 'TTR04',
        'jobType': 'fertilizing',
        'description': 'Bón phân hữu cơ sinh học đợt 2 cho diện tích rừng mới trồng. Hoàn thành 100% kế hoạch trong ngày.',
        'userId': 'worker_03',
        'userName': 'Lê Minh Tuấn',
        'imagePaths': <String>[],
        'latitude': 12.7400,
        'longitude': 108.0900,
        'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
        'isSynced': true,
        'syncStatus': 'synced',
      },
    ];
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await _storage.getString(_key);
    if (raw == null) {
      final seedData = _getSeedLogs();
      await _write(seedData);
      return seedData;
    }
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

  @override
  Future<void> saveAll(List<LogbookModel> logbooks) async {
    final items = await _read();
    for (final logbook in logbooks) {
      final idx = items.indexWhere((e) =>
          (e['serverId'] != null && e['serverId'] == logbook.serverId) ||
          (e['id'] != null && e['id'] == logbook.serverId) ||
          (e['serverId'] != null && e['serverId'] == logbook.id) ||
          (e['id'] != null && e['id'] == logbook.id));
      if (idx != -1) {
        final localId = items[idx]['id'];
        final updatedJson = logbook.toJson();
        updatedJson['id'] = localId; // Giữ nguyên local ID
        items[idx] = updatedJson;
      } else {
        items.insert(0, logbook.toJson());
      }
    }
    await _write(items);
  }
}
