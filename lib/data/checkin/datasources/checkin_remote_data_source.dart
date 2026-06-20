// FILE: lib/data/checkin/datasources/checkin_remote_data_source.dart
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../domain/checkin/entities/checkin_entity.dart';
import '../models/checkin_model.dart';

abstract class CheckinRemoteDataSource {
  Future<bool> checkConnectivity();
  Future<String> upload(CheckinEntity item, String token);
  Future<List<CheckinModel>> fetchHistory(String token);
}

/// REST implementation kept for compatibility with older wiring.
class CheckinRemoteDataSourceImpl implements CheckinRemoteDataSource {
  final Dio dio;

  CheckinRemoteDataSourceImpl({Dio? dioClient})
      : dio = dioClient ?? Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  @override
  Future<bool> checkConnectivity() async {
    try {
      final r = await dio.get('/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> upload(CheckinEntity item, String token) async {
    try {
      final res = await dio.post(
        ApiConstants.checkins,
        data: CheckinModel.fromEntity(item).toApiJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (res.data['data']?['id'] ?? res.data['id']).toString();
    } on DioException catch (e) {
      throw ServerFailure(
        message: e.message ?? 'Lỗi đồng bộ check-in',
        code: e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<CheckinModel>> fetchHistory(String token) async {
    final res = await dio.get(
      ApiConstants.checkins,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final body = res.data;
    final rows = body is List ? body : (body['data'] as List? ?? const []);
    return rows
        .map((row) => _fromRemoteMap(Map<String, dynamic>.from(row)))
        .toList();
  }
}

class CheckinRemoteDataSourceMock implements CheckinRemoteDataSource {
  bool forceOffline;
  CheckinRemoteDataSourceMock({this.forceOffline = false});

  @override
  Future<bool> checkConnectivity() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return !forceOffline;
  }

  @override
  Future<String> upload(CheckinEntity item, String token) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (forceOffline) throw const NetworkFailure();
    return 'SRV-CHK-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<List<CheckinModel>> fetchHistory(String token) async => [];
}

/// Supabase Postgres implementation.
class CheckinRemoteDataSourceSupabase implements CheckinRemoteDataSource {
  final SupabaseClient _client;

  CheckinRemoteDataSourceSupabase({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<bool> checkConnectivity() async {
    try {
      await _client
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> upload(CheckinEntity item, String token) async {
    final currentUserId = _client.auth.currentUser?.id;
    final userId = currentUserId ?? item.userId;
    final checkedAt = item.timestamp.toUtc().toIso8601String();
    if (userId.isEmpty) {
      throw const AuthFailure(message: 'Chưa đăng nhập Supabase.');
    }

    try {
      // Kiểm tra owner_id cho worker trước khi check-in
      final profile = await _client
          .from('profiles')
          .select('role, owner_id')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null && profile['role'] == 'worker') {
        final ownerId = profile['owner_id']?.toString() ?? '';
        if (ownerId.isEmpty) {
          throw const ServerFailure(
            message:
                'Tài khoản worker chưa được gán chủ rừng. Không thể check-in.',
          );
        }
      }

      final inserted = await _client
          .from('checkins')
          .insert({
            'user_id': userId,
            if (item.projectId != null) 'project_id': item.projectId,
            'latitude': item.latitude,
            'longitude': item.longitude,
            'checked_at': checkedAt,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'type': item.type,
          })
          .select('id')
          .single();
      return inserted['id'].toString();
    } on PostgrestException catch (e) {
      throw ServerFailure(message: e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(message: e.toString());
    }
  }

  @override
  Future<List<CheckinModel>> fetchHistory(String token) async {
    try {
      final rows = await _client
          .from('checkins')
          .select()
          .order('checked_at', ascending: false)
          .limit(200);
      final userIds = (rows as List)
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final profiles = userIds.isEmpty
          ? <dynamic>[]
          : await _client
              .from('profiles')
              .select('id,full_name,email')
              .inFilter('id', userIds);
      final names = {
        for (final profile in profiles)
          profile['id'].toString():
              (profile['full_name'] ?? profile['email'] ?? '').toString()
      };
      return rows
          .cast<Map<String, dynamic>>()
          .map((row) =>
              _fromRemoteMap(row, userName: names[row['user_id']] ?? ''))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerFailure(message: e.message);
    }
  }
}

CheckinModel _fromRemoteMap(Map<String, dynamic> row, {String? userName}) {
  final userId = (row['user_id'] ?? row['userId'] ?? '').toString();
  return CheckinModel(
    id: row['id']?.toString(),
    serverId: row['id']?.toString(),
    projectId: row['project_id']?.toString(),
    userId: userId,
    userName:
        userName ?? (row['user_name'] ?? row['userName'] ?? userId).toString(),
    latitude: double.tryParse(row['latitude']?.toString() ?? '') ?? 0,
    longitude: double.tryParse(row['longitude']?.toString() ?? '') ?? 0,
    timestamp: DateTime.tryParse(
            (row['checked_at'] ?? row['created_at'] ?? row['timestamp'] ?? '')
                .toString()) ??
        DateTime.now(),
    type: (row['type'] ?? 'check_in').toString(),
    note: (row['note'] ?? '').toString(),
    isSynced: true,
  );
}
