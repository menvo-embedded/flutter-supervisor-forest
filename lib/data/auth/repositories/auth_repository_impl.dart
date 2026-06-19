import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../domain/auth/entities/user_entity.dart';
import '../../../domain/auth/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

/// Triển khai AuthRepository - điều phối Remote (API) & Local (cache)
/// Chuẩn hoá lỗi về Either<Failure, T> theo yêu cầu dartz
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  AuthRepositoryImpl({required this.remote, required this.local});

  @override
  Future<Either<Failure, UserEntity>> login(String email, String password) async {
    try {
      final user = await remote.login(email, password);
      await local.cacheUser(user);
      return Right(user);
    } on AuthFailure catch (f) {
      return Left(f);
    } on NetworkFailure catch (f) {
      return Left(f);
    } on ServerFailure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final cached = await local.getCachedUser();
      if (cached != null) await remote.logout(cached.token);
      await local.clearSession();
      return const Right(null);
    } catch (e) {
      // Vẫn xoá local dù API lỗi để đảm bảo logout
      await local.clearSession();
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCachedUser() async {
    final cached = await local.getCachedUser();
    if (cached == null) {
      return const Left(CacheFailure(message: 'Chưa đăng nhập'));
    }
    return Right(cached);
  }

  @override
  Future<bool> hasValidSession() async {
    final cached = await local.getCachedUser();
    return cached != null && cached.token.isNotEmpty;
  }
}
