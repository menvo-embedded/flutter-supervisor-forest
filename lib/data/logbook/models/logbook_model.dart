// FILE: lib/data/logbook/models/logbook_model.dart
import '../../../domain/logbook/entities/logbook_entity.dart';

/// Model tầng Data — kế thừa LogbookEntity, thêm phương thức API
class LogbookModel extends LogbookEntity {
  const LogbookModel({
    super.id, super.serverId, super.projectId,
    required super.jobType,
    required super.description,
    required super.userId,
    required super.userName,
    required super.imagePaths,
    required super.latitude,
    required super.longitude,
    required super.timestamp,
    super.isSynced   = false,
    super.syncStatus = 'pending',
  });

  factory LogbookModel.fromEntity(LogbookEntity e) => LogbookModel(
    id:          e.id,         serverId:  e.serverId,
    projectId:   e.projectId,  jobType:   e.jobType,
    description: e.description, userId:   e.userId,
    userName:    e.userName,   imagePaths: e.imagePaths,
    latitude:    e.latitude,   longitude:  e.longitude,
    timestamp:   e.timestamp,  isSynced:   e.isSynced,
    syncStatus:  e.syncStatus,
  );

  /// Parse từ API response (snake_case)
  factory LogbookModel.fromApiJson(Map<String, dynamic> j) => LogbookModel(
    id:          j['id']?.toString(),
    serverId:    (j['server_id'] ?? j['id'])?.toString(),
    projectId:   j['project_id'],
    jobType:     JobType.fromApi(j['job_type'] ?? 'care'),
    description: j['description'] ?? '',
    userId:      j['user_id']   ?? '',
    userName:    j['user_name'] ?? '',
    imagePaths:  List<String>.from(j['images'] ?? j['image_urls'] ?? []),
    latitude:    (j['latitude']  ?? 0).toDouble(),
    longitude:   (j['longitude'] ?? 0).toDouble(),
    timestamp:   DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
    isSynced:    true,
    syncStatus:  'synced',
  );

  /// Payload gửi lên REST API (snake_case, không gửi ảnh — multipart riêng)
  Map<String, dynamic> toApiJson() => {
    'job_type':    jobType.apiValue,
    'description': description,
    'latitude':    latitude,
    'longitude':   longitude,
    'timestamp':   timestamp.toUtc().toIso8601String(),
    'user_id':     userId,
    'user_name':   userName,
    if (projectId != null) 'project_id': projectId,
  };
}
