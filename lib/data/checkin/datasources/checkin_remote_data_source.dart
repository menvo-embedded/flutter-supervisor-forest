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
}
