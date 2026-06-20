// FILE: lib/data/checkin/repositories/checkin_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../domain/checkin/entities/checkin_entity.dart';
import '../../../domain/checkin/repositories/checkin_repository.dart';
import '../datasources/checkin_local_data_source.dart';
import '../datasources/checkin_remote_data_source.dart';
import '../models/checkin_model.dart';
import '../../auth/datasources/auth_local_data_source.dart';

class CheckinRepositoryImpl implements CheckinRepository {
  final CheckinLocalDataSource  local;
  final CheckinRemoteDataSource remote;
  final AuthLocalDataSource     authLocal;

  CheckinRepositoryImpl({
    required this.local,
    required this.remote,
    required this.authLocal,
  });

  @override
  Future<Either<Failure, CheckinEntity>> submitCheckin(CheckinEntity item) async {
    try {
      // 1. Lưu local trước
      final saved = await local.save(CheckinModel.fromEntity(item));

      // 2. Kiểm tra mạng
      final online = await remote.checkConnectivity();
      if (!online) return Right(saved);

      // 3. Upload
      final user     = await authLocal.getCachedUser();
      final serverId = await remote.upload(saved, user?.token ?? '');
      await local.markSynced(saved.id!, serverId);

      // 4. Trả entity đã synced (copyWith đã có sau fix)
      return Right(saved.copyWith(isSynced: true, serverId: serverId));
    } on NetworkFailure {
      final history = await local.getAll(userId: item.userId);
      return Right(history.isNotEmpty ? history.first
        : CheckinModel.fromEntity(item));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CheckinEntity>>> getHistory({String? userId}) async {
    try {
      final online = await remote.checkConnectivity();
      if (online) {
        final user = await authLocal.getCachedUser();
        if (user != null) {
          try {
            final remoteItems = await remote.fetchCheckins(user.token, userId: userId);
            await local.saveAll(remoteItems);
          } catch (_) {
            // Bỏ qua lỗi tải remote để chạy tiếp bằng dữ liệu local hiện tại
          }
        }
      }
      return Right(await local.getAll(userId: userId));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> syncPending() async {
    try {
      if (!await remote.checkConnectivity()) return const Left(NetworkFailure());

      final pending = await local.getUnsynced();
      final user    = await authLocal.getCachedUser();
      int ok = 0;
      for (final item in pending) {
        try {
          final sid = await remote.upload(item, user?.token ?? '');
          await local.markSynced(item.id!, sid);
          ok++;
        } catch (_) {}
      }
      return Right(ok);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<int> getPendingCount() async => (await local.getUnsynced()).length;
}
