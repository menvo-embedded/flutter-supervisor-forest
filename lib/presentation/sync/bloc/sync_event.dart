import 'package:equatable/equatable.dart';
abstract class SyncEvent extends Equatable {
  const SyncEvent();
  @override List<Object?> get props => [];
}
/// Yêu cầu đồng bộ ngay (kéo-refresh, nút "Đồng bộ ngay", hoặc khi có mạng trở lại)
class SyncRequested extends SyncEvent { const SyncRequested(); }
/// Chỉ kiểm tra số lượng đang chờ đồng bộ (không gọi API)
class SyncStatusChecked extends SyncEvent { const SyncStatusChecked(); }
