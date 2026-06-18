// FILE: lib/data/sync/sync_repository.dart
import '../../domain/logbook/repositories/logbook_repository.dart';
import '../../domain/checkin/repositories/checkin_repository.dart';

/// Kết quả một lần đồng bộ batch
class SyncResult {
  final int  logbooksSynced;
  final int  checkinsSynced;
  final int  totalPending;
  final bool isOnline;

  const SyncResult({
    required this.logbooksSynced,
    required this.checkinsSynced,
    required this.totalPending,
    required this.isOnline,
  });

  int get totalSynced => logbooksSynced + checkinsSynced;
}

/// Điều phối đồng bộ tất cả dữ liệu offline lên Web Server (Module 9).
/// Gọi khi: mở app (AuthCheckRequested), kéo-refresh, hoặc
/// khi connectivity_plus báo mạng trở lại.
class SyncRepository {
  final LogbookRepository logbookRepo;
  final CheckinRepository checkinRepo;

  SyncRepository({required this.logbookRepo, required this.checkinRepo});

  Future<SyncResult> syncAll() async {
    final logResult = await logbookRepo.syncPending();
    final chkResult = await checkinRepo.syncPending();

    final logSynced = logResult.fold((_) => 0, (n) => n);
    final chkSynced = chkResult.fold((_) => 0, (n) => n);

    // isOnline = ít nhất một trong hai sync không trả Left(NetworkFailure)
    final isOnline = logResult.isRight() || chkResult.isRight();

    final pending = await getPendingCount();
    return SyncResult(
      logbooksSynced: logSynced,
      checkinsSynced: chkSynced,
      totalPending:   pending,
      isOnline:       isOnline,
    );
  }

  Future<int> getPendingCount() async {
    final a = await logbookRepo.getPendingCount();
    final b = await checkinRepo.getPendingCount();
    return a + b;
  }
}
