// FILE: lib/data/auth/datasources/auth_remote_data_source.dart
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<void> logout(String token);
}

/// REST implementation kept for compatibility with older wiring.
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({Dio? dioClient})
      : dio = dioClient ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ));

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final res = await dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      return UserModel.fromJson(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw const NetworkFailure();
      }
      if (e.response?.statusCode == 401) throw const AuthFailure();
      throw ServerFailure(
        message: e.response?.data?['message'] ?? 'Lỗi máy chủ',
        code: e.response?.statusCode,
      );
    }
  }

  @override
  Future<void> logout(String token) async {
    try {
      await dio.post(
        ApiConstants.logout,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException {
      // Local logout still proceeds if the legacy API is unavailable.
    }
  }
}

/// Demo implementation kept for offline UI testing.
class AuthRemoteDataSourceMock implements AuthRemoteDataSource {
  static final _users = [
    {
      'id': 'ADM-001',
      'fullName': 'Admin Platform',
      'email': 'admin@qlr.vn',
      'phone': '0900000001',
      'role': 'platform_admin',
      'password': '123456',
      'status': 'active',
    },
    {
      'id': 'OWN-001',
      'fullName': 'Nguyen Van A',
      'email': 'owner@qlr.vn',
      'phone': '0900000002',
      'role': 'forest_owner',
      'password': '123456',
      'status': 'active',
    },
    {
      'id': 'WKR-001',
      'fullName': 'Tran Thi B',
      'email': 'worker@qlr.vn',
      'phone': '0900000003',
      'role': 'forest_worker',
      'password': '123456',
      'status': 'active',
    },
  ];

  @override
  Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final u = _users.firstWhere(
      (x) => x['email'] == email && x['password'] == password,
      orElse: () => {},
    );
    if (u.isEmpty) throw const AuthFailure();
    if (u['status'] == 'locked') {
      throw const AuthFailure(
        message: 'Tài khoản đã bị khóa. Liên hệ quản trị viên.',
      );
    }
    return UserModel(
      id: u['id']!,
      fullName: u['fullName']!,
      email: u['email']!,
      phone: u['phone']!,
      role: userRoleFromApi(u['role']!),
      token: 'jwt_${u['id']}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'refresh_${u['id']}',
      status: u['status']!,
      lastLogin: DateTime.now(),
    );
  }

  @override
  Future<void> logout(String token) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }
}

/// Supabase Auth + profiles implementation.
class AuthRemoteDataSourceSupabase implements AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSourceSupabase({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      final session = response.session;
      if (user == null) {
        throw const AuthFailure(message: 'Đăng nhập thất bại.');
      }

      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) {
        await _client.auth.signOut();
        throw const AuthFailure(
          message: 'Tài khoản chưa được phân quyền trong bảng profiles.',
        );
      }
      if (profile['status'] == 'locked') {
        await _client.auth.signOut();
        throw const AuthFailure(
          message: 'Tài khoản đã bị khóa. Liên hệ quản trị viên.',
        );
      }

    return UserModel(
      id: user.id,
      fullName: profile['fullName'] ?? profile['full_name'] ?? '',
      email: profile['email'] ?? user.email ?? email,
      phone: profile['phone'] ?? '',
      role: userRoleFromApi(profile['role'] ?? 'worker'),
      token: session?.accessToken ?? '',
      refreshToken: session?.refreshToken ?? '',
      status: profile['status'] ?? 'active',
      ownerId: profile['owner_id']?.toString(),
      lastLogin: DateTime.now(),
    );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('email') || msg.contains('password')) {
        throw const AuthFailure();
      }
      throw ServerFailure(message: e.message);
    } on PostgrestException catch (e) {
      throw ServerFailure(message: e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw ServerFailure(message: e.toString());
    }
  }

  @override
  Future<void> logout(String token) async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Local logout still proceeds.
    }
  }
}
