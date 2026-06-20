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
  Future<List<CheckinModel>> fetchCheckins(String token, {String? userId});
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
  Future<List<CheckinModel>> fetchCheckins(String token, {String? userId}) async {
    return [];
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
  Future<List<CheckinModel>> fetchCheckins(String token, {String? userId}) async {
    return [];
  }
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
    if (userId.isEmpty) {
      throw const AuthFailure(message: 'Chưa đăng nhập Supabase.');
    }

    try {
      final inserted = await _client
          .from('checkins')
          .insert({
            'user_id': userId,
            if (item.projectId != null) 'project_id': item.projectId,
            'latitude': item.latitude,
            'longitude': item.longitude,
            'checked_at': item.timestamp.toUtc().toIso8601String(),
            'created_at': item.timestamp.toUtc().toIso8601String(),
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
  Future<List<CheckinModel>> fetchCheckins(String token, {String? userId}) async {
    final currentUserId = _client.auth.currentUser?.id;
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null || targetUserId.isEmpty) {
      throw const AuthFailure(message: 'Chưa đăng nhập Supabase.');
    }

    try {
      final List<dynamic> rows = await _client
          .from('checkins')
          .select()
          .eq('user_id', targetUserId)
          .order('checked_at', ascending: true);

      // Group records by day (local time zone) to assign alternating types starting from check_in
      final Map<String, List<CheckinModel>> grouped = {};
      for (final row in rows) {
        final timestamp = DateTime.tryParse(row['checked_at'] ?? row['created_at'] ?? '') ?? DateTime.now();
        final localTime = timestamp.toLocal();
        final dayKey = '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';

        final model = CheckinModel(
          id: row['id']?.toString(),
          serverId: row['id']?.toString(),
          projectId: row['project_id']?.toString(),
          userId: row['user_id']?.toString() ?? '',
          userName: '',
          latitude: (row['latitude'] ?? 0.0).toDouble(),
          longitude: (row['longitude'] ?? 0.0).toDouble(),
          timestamp: localTime,
          type: 'check_in',
          isSynced: true,
          note: '',
        );
        grouped.putIfAbsent(dayKey, () => []).add(model);
      }

      final List<CheckinModel> result = [];
      grouped.forEach((dayKey, list) {
        for (int i = 0; i < list.length; i++) {
          final type = (i % 2 == 0) ? 'check_in' : 'check_out';
          result.add(CheckinModel.fromEntity(list[i].copyWith(type: type)));
        }
      });

      // Sort descending (newest first)
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result;
    } on PostgrestException catch (e) {
      throw ServerFailure(message: e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(message: e.toString());
    }
  }
}
