import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../entities/checkin_entity.dart';

abstract class CheckinRepository {
  Future<Either<Failure, CheckinEntity>> submitCheckin(CheckinEntity checkin);
  Future<Either<Failure, List<CheckinEntity>>> getHistory({String? userId});
  Future<Either<Failure, int>> syncPending();
  Future<int> getPendingCount();
}
