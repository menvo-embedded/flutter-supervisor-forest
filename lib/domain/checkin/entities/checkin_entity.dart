// FILE: lib/domain/checkin/entities/checkin_entity.dart
import 'package:equatable/equatable.dart';

class CheckinEntity extends Equatable {
  final String?  id, serverId, projectId;
  final String   userId, userName;
  final double   latitude, longitude;
  final DateTime timestamp;
  final String   type; // check_in | check_out
  final bool     isSynced;
  final String   note;

  const CheckinEntity({
    this.id, this.serverId, this.projectId,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.type,
    this.isSynced = false,
    this.note     = '',
  });

  String get gpsString  =>
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  String get typeLabel  => type == 'check_in' ? 'Check-in' : 'Check-out';

  /// FIX BUG 2: thêm copyWith để checkin_repository_impl có thể dùng
  CheckinEntity copyWith({
    String? id,
    String? serverId,
    bool?   isSynced,
    String? syncStatus,
    String? type,
  }) => CheckinEntity(
    id:         id        ?? this.id,
    serverId:   serverId  ?? this.serverId,
    projectId:  projectId,
    userId:     userId,   userName:  userName,
    latitude:   latitude, longitude: longitude,
    timestamp:  timestamp, type:     type ?? this.type,
    isSynced:   isSynced ?? this.isSynced,
    note:       note,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'serverId': serverId, 'projectId': projectId,
    'userId': userId, 'userName': userName,
    'latitude': latitude, 'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    'type': type, 'isSynced': isSynced, 'note': note,
  };

  factory CheckinEntity.fromJson(Map<String, dynamic> j) => CheckinEntity(
    id:         j['id'],
    serverId:   j['serverId'],
    projectId:  j['projectId'],
    userId:     j['userId']    ?? '',
    userName:   j['userName']  ?? '',
    latitude:   (j['latitude']  ?? 0).toDouble(),
    longitude:  (j['longitude'] ?? 0).toDouble(),
    timestamp:  DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
    type:       j['type']      ?? 'check_in',
    isSynced:   j['isSynced']  ?? false,
    note:       j['note']      ?? '',
  );

  @override
  List<Object?> get props => [id, userId, type, timestamp, isSynced];
}
