// FILE: lib/data/logbook/datasources/logbook_remote_data_source.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';
import '../models/logbook_model.dart';

abstract class LogbookRemoteDataSource {
  Future<bool> checkConnectivity();
  Future<String> uploadLogbook(LogbookEntity logbook, String token);
  Future<List<LogbookModel>> fetchLogbooks(String token, {int page, int limit});
}

/// REST implementation kept for compatibility with older wiring.
class LogbookRemoteDataSourceImpl implements LogbookRemoteDataSource {
  final Dio dio;

  LogbookRemoteDataSourceImpl({Dio? dioClient})
      : dio = dioClient ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Accept': 'application/json'},
            ));

  @override
  Future<bool> checkConnectivity() async {
    try {
      final r = await dio.get(
        '/health',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return r.statusCode == 200;
    } catch (_) {
      try {
        final res = await InternetAddress.lookup('google.com');
        return res.isNotEmpty && res[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  @override
  Future<String> uploadLogbook(LogbookEntity logbook, String token) async {
    final model = LogbookModel.fromEntity(logbook);
    final form = FormData.fromMap(model.toApiJson());

    for (var i = 0; i < logbook.imagePaths.length; i++) {
      final f = File(logbook.imagePaths[i]);
      if (await f.exists()) {
        form.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(f.path, filename: 'field_${i + 1}.jpg'),
        ));
      }
    }

    try {
      final res = await dio.post(
        ApiConstants.logbooks,
        data: form,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (res.data['data']?['id'] ?? res.data['id']).toString();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) throw const NetworkFailure();
      throw ServerFailure(
        message: e.message ?? 'Upload thất bại',
        code: e.response?.statusCode,
      );
    }
  }

  @override
  Future<List<LogbookModel>> fetchLogbooks(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await dio.get(
        ApiConstants.logbooks,
        queryParameters: {'page': page, 'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return (res.data['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(LogbookModel.fromApiJson)
          .toList();
    } on DioException catch (e) {
      throw ServerFailure(
        message: e.message ?? 'Tải dữ liệu thất bại',
        code: e.response?.statusCode,
      );
    }
  }
}

class LogbookRemoteDataSourceMock implements LogbookRemoteDataSource {
  bool forceOffline;
  LogbookRemoteDataSourceMock({this.forceOffline = false});

  @override
  Future<bool> checkConnectivity() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return !forceOffline;
  }

  @override
  Future<String> uploadLogbook(LogbookEntity logbook, String token) async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (forceOffline) throw const NetworkFailure();
    return 'SRV-LOG-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<List<LogbookModel>> fetchLogbooks(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [];
  }
}

/// Supabase Postgres + Storage implementation.
class LogbookRemoteDataSourceSupabase implements LogbookRemoteDataSource {
  final SupabaseClient _client;

  LogbookRemoteDataSourceSupabase({SupabaseClient? client})
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
  Future<String> uploadLogbook(LogbookEntity logbook, String token) async {
    final currentUserId = _client.auth.currentUser?.id;
    final userId = currentUserId ?? logbook.userId;
    if (userId.isEmpty) {
      throw const AuthFailure(message: 'Chưa đăng nhập Supabase.');
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('owner_id')
          .eq('id', userId)
          .maybeSingle();
      final ownerId = profile?['owner_id'];

      final inserted = await _client
          .from('logbooks')
          .insert({
            'user_id': userId,
            if (ownerId != null) 'owner_id': ownerId,
            if (logbook.projectId != null) 'project_id': logbook.projectId,
            'work_type': logbook.jobType.apiValue,
            'description': logbook.description,
            'latitude': logbook.latitude,
            'longitude': logbook.longitude,
            'photo_urls': <String>[],
            'is_synced': true,
            'created_at': logbook.timestamp.toIso8601String(),
          })
          .select('id')
          .single();

      final logbookId = inserted['id'].toString();
      final photoUrls = await _uploadImages(userId, logbookId, logbook.imagePaths);

      if (photoUrls.isNotEmpty) {
        await _client
            .from('logbooks')
            .update({'photo_urls': photoUrls})
            .eq('id', logbookId);
      }

      return logbookId;
    } on StorageException catch (e) {
      throw ServerFailure(message: 'Upload ảnh Supabase thất bại: ${e.message}');
    } on PostgrestException catch (e) {
      throw ServerFailure(message: e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(message: e.toString());
    }
  }

  Future<List<String>> _uploadImages(
    String userId,
    String logbookId,
    List<String> imagePaths,
  ) async {
    final paths = imagePaths.take(10).toList();
    final urls = <String>[];

    for (final imagePath in paths) {
      final extension = _extensionOf(imagePath).toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw ServerFailure(
          message: 'Chỉ hỗ trợ ảnh jpg, jpeg, png: ${_fileNameOf(imagePath)}',
        );
      }

      final file = File(imagePath);
      if (!await file.exists()) continue;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'logbooks/$userId/$logbookId/${timestamp}_${_fileNameOf(imagePath)}';
      await _client.storage.from(SupabaseConstants.logbookImagesBucket).uploadBinary(
            storagePath,
            await file.readAsBytes(),
            fileOptions: FileOptions(
              contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
              upsert: false,
            ),
          );
      final publicUrl = _client.storage
          .from(SupabaseConstants.logbookImagesBucket)
          .getPublicUrl(storagePath);
      urls.add(publicUrl);
    }
    return urls;
  }

  @override
  Future<List<LogbookModel>> fetchLogbooks(
    String token, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw const AuthFailure(message: 'Chưa đăng nhập.');

      final profile = await _client
          .from('profiles')
          .select('role, owner_id')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role'] ?? 'worker';
      final from = (page - 1) * limit;
      final to = from + limit - 1;

      final List<dynamic> rows;
      if (role == 'admin') {
        rows = await _client
            .from('logbooks')
            .select()
            .order('created_at', ascending: false)
            .range(from, to);
      } else if (role == 'owner' && profile?['owner_id'] != null) {
        rows = await _client
            .from('logbooks')
            .select()
            .eq('owner_id', profile!['owner_id'])
            .order('created_at', ascending: false)
            .range(from, to);
      } else {
        rows = await _client
            .from('logbooks')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .range(from, to);
      }

      return rows
          .cast<Map<String, dynamic>>()
          .map(_logbookFromSupabase)
          .toList();
    } on PostgrestException catch (e) {
      throw ServerFailure(message: e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(message: e.toString());
    }
  }

  LogbookModel _logbookFromSupabase(Map<String, dynamic> row) {
    return LogbookModel.fromApiJson({
      ...row,
      'job_type': row['work_type'],
      'timestamp': row['created_at'],
      'image_urls': row['photo_urls'] ?? <String>[],
    });
  }

  String _fileNameOf(String path) => path.split(RegExp(r'[\\/]')).last;

  String _extensionOf(String path) {
    final fileName = _fileNameOf(path);
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1);
  }
}
