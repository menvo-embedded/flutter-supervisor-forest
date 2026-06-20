// FILE: lib/domain/logbook/entities/logbook_entity.dart
import 'package:equatable/equatable.dart';

enum JobType {
  plantingTrees   ('Trồng cây',             'planting',          '🌱'),
  treeCare        ('Chăm sóc cây',           'care',              '🌿'),
  fertilizing     ('Bón phân',               'fertilizing',       '💧'),
  growthInspection('Kiểm tra sinh trưởng',   'growth_inspection', '🔍'),
  patrol          ('Tuần tra',               'patrol',            '🚶'),
  firePrevention  ('Phòng cháy chữa cháy',   'fire_prevention',   '🔥');

  final String displayName, apiValue, emoji;
  const JobType(this.displayName, this.apiValue, this.emoji);

  static JobType fromApi(String v) => JobType.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => JobType.treeCare,
  );
}

class LogbookEntity extends Equatable {
  final String?      id, serverId, projectId;
  final JobType      jobType;
  final String       description, userId, userName;
  final List<String> imagePaths;
  final double       latitude, longitude;
  final DateTime     timestamp;
  final bool         isSynced;
  final String       syncStatus; // pending | synced | failed

  const LogbookEntity({
    this.id, this.serverId, this.projectId,
    required this.jobType,
    required this.description,
    required this.userId,
    required this.userName,
    required this.imagePaths,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isSynced   = false,
    this.syncStatus = 'pending',
  });

  bool   get isImageFull => imagePaths.length >= 10;
  String get gpsString   =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  LogbookEntity copyWith({
    String? id,
    String? serverId,
    bool?   isSynced,
    String? syncStatus,
  }) => LogbookEntity(
    id:         id         ?? this.id,
    serverId:   serverId   ?? this.serverId,
    projectId:  projectId,
    jobType:    jobType,
    description: description,
    userId:     userId,
    userName:   userName,
    imagePaths: imagePaths,
    latitude:   latitude,
    longitude:  longitude,
    timestamp:  timestamp,
    isSynced:   isSynced   ?? this.isSynced,
    syncStatus: syncStatus ?? this.syncStatus,
  );

  Map<String, dynamic> toJson() => {
    'id':          id,
    'serverId':    serverId,
    'projectId':   projectId,
    'jobType':     jobType.apiValue,
    'description': description,
    'userId':      userId,
    'userName':    userName,
    'imagePaths':  imagePaths,
    'latitude':    latitude,
    'longitude':   longitude,
    'timestamp':   timestamp.toIso8601String(),
    'isSynced':    isSynced,
    'syncStatus':  syncStatus,
  };

  factory LogbookEntity.fromJson(Map<String, dynamic> j) => LogbookEntity(
    id:          j['id'],
    serverId:    j['serverId'],
    projectId:   j['projectId'],
    jobType:     JobType.fromApi(j['jobType'] ?? j['job_type'] ?? 'care'),
    description: j['description'] ?? '',
    userId:      j['userId']      ?? j['user_id']   ?? '',
    userName:    j['userName']    ?? j['user_name']  ?? '',
    imagePaths:  List<String>.from(j['imagePaths'] ?? j['images'] ?? []),
    latitude:    (j['latitude']  ?? 0).toDouble(),
    longitude:   (j['longitude'] ?? 0).toDouble(),
    timestamp:   DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
    isSynced:    j['isSynced']   ?? false,
    syncStatus:  j['syncStatus'] ?? 'pending',
  );

  @override
  List<Object?> get props =>
    [id, jobType, description, timestamp, isSynced, syncStatus];
}
