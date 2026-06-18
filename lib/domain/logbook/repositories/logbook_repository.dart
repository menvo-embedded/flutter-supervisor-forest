import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../entities/logbook_entity.dart';

abstract class LogbookRepository {
  /// Lưu nhật ký: ghi local trước, thử đồng bộ server nếu có mạng
  Future<Either<Failure, LogbookEntity>> submitLogbook(LogbookEntity logbook);

  /// Lấy danh sách nhật ký (local cache, kèm trạng thái đồng bộ)
  Future<Either<Failure, List<LogbookEntity>>> getLogbooks({String? userId});

  /// Đồng bộ toàn bộ nhật ký pending lên server
  Future<Either<Failure, int>> syncPending();

  Future<int> getPendingCount();
}
