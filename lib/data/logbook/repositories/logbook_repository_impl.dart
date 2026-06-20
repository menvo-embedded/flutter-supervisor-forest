// FILE: lib/data/logbook/repositories/logbook_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';
import '../../../domain/logbook/repositories/logbook_repository.dart';
import '../datasources/logbook_local_data_source.dart';
import '../datasources/logbook_remote_data_source.dart';
import '../models/logbook_model.dart';
import '../../auth/datasources/auth_local_data_source.dart';

/// Điều phối Local (Offline JSON DB) ↔ Remote (Web Server REST API)
/// Luồng chuẩn: Lưu local trước → kiểm tra mạng → đồng bộ nếu online
class LogbookRepositoryImpl implements LogbookRepository {
  final LogbookLocalDataSource  local;
  final LogbookRemoteDataSource remote;
  final AuthLocalDataSource     authLocal;

  LogbookRepositoryImpl({
    required this.local,
    required this.remote,
    required this.authLocal,
  });

  @override
  Future<Either<Failure, LogbookEntity>> submitLogbook(LogbookEntity logbook) async {
    try {
      // 1. Luôn lưu local trước — đảm bảo Module 9 (Offline Storage)
      final saved = await local.saveLogbook(LogbookModel.fromEntity(logbook));

      // 2. Kiểm tra kết nối mạng
      final online = await remote.checkConnectivity();
      if (!online) {
        // Offline → trả về đã lưu local, syncStatus = pending
        return Right(saved);
      }

      // 3. Online → upload lên Web Server ngay
      final user = await authLocal.getCachedUser();
      final serverId = await remote.uploadLogbook(saved, user?.token ?? '');
      await local.markSynced(saved.id!, serverId);

      return Right(saved.copyWith(
        isSynced:   true,
        syncStatus: 'synced',
        serverId:   serverId,
      ));
    } on NetworkFailure {
      // Upload thất bại giữa chừng → vẫn trả thành công (đã lưu local)
      final all = await local.getAll(userId: logbook.userId);
      final latest = all.isNotEmpty ? all.first : LogbookModel.fromEntity(logbook);
      return Right(latest);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LogbookEntity>>> getLogbooks({String? userId}) async {
    try {
      final online = await remote.checkConnectivity();
      if (online) {
        final user = await authLocal.getCachedUser();
        if (user != null) {
          try {
            final remoteItems = await remote.fetchLogbooks(user.token);
            await local.saveAll(remoteItems);
          } catch (_) {
            // Bỏ qua lỗi tải remote để tiếp tục chạy bằng dữ liệu local hiện tại
          }
        }
      }
      final items = await local.getAll(userId: userId);
      return Right(items);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> syncPending() async {
    try {
      final online = await remote.checkConnectivity();
      if (!online) return const Left(NetworkFailure());

      final pending = await local.getUnsynced();
      final user    = await authLocal.getCachedUser();
      int success   = 0;

      for (final item in pending) {
        try {
          final serverId = await remote.uploadLogbook(item, user?.token ?? '');
          await local.markSynced(item.id!, serverId);
          success++;
        } catch (_) { /* bỏ qua item lỗi, thử lần tiếp theo */ }
      }
      return Right(success);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<int> getPendingCount() async => (await local.getUnsynced()).length;

  @override
  Future<Either<Failure, void>> deleteLogbook(String id, {String? serverId}) async {
    try {
      // 1. Xóa local trước
      await local.deleteLogbook(id);

      // 2. Nếu có serverId (đã đồng bộ), xóa trên server
      if (serverId != null && serverId.isNotEmpty) {
        final online = await remote.checkConnectivity();
        if (online) {
          await remote.deleteLogbook(serverId);
        } else {
          return const Left(NetworkFailure(message: 'Không có mạng. Vui lòng kết nối Internet để xóa trên server.'));
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
