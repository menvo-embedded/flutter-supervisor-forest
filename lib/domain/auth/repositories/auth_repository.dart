import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../entities/user_entity.dart';

/// Interface tầng Domain - không phụ thuộc Dio/Storage cụ thể
abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login(String email, String password);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity>> getCachedUser();
  Future<bool> hasValidSession();
}
