import '../../../domain/checkin/entities/checkin_entity.dart';

class CheckinModel extends CheckinEntity {
  const CheckinModel(
      {super.id,
      super.serverId,
      super.projectId,
      required super.userId,
      required super.userName,
      required super.latitude,
      required super.longitude,
      required super.timestamp,
      required super.type,
      super.isSynced = false,
      super.note = ''});

  factory CheckinModel.fromEntity(CheckinEntity e) => CheckinModel(
      id: e.id,
      serverId: e.serverId,
      projectId: e.projectId,
      userId: e.userId,
      userName: e.userName,
      latitude: e.latitude,
      longitude: e.longitude,
      timestamp: e.timestamp,
      type: e.type,
      isSynced: e.isSynced,
      note: e.note);

  Map<String, dynamic> toApiJson() => {
        'user_id': userId,
        'user_name': userName,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'type': type,
        'note': note,
        if (projectId != null) 'project_id': projectId,
      };
}
