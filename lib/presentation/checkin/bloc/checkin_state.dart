import 'package:equatable/equatable.dart';
import '../../../domain/checkin/entities/checkin_entity.dart';

abstract class CheckinState extends Equatable {
  const CheckinState();
  @override List<Object?> get props => [];
}

class CheckinInitial extends CheckinState { const CheckinInitial(); }
class CheckinLoading extends CheckinState { const CheckinLoading(); }

class CheckinLoaded extends CheckinState {
  final List<CheckinEntity> history;
  final CheckinEntity? lastAction;
  const CheckinLoaded({required this.history, this.lastAction});
  @override List<Object?> get props => [history, lastAction];

  /// Lịch sử hôm nay
  List<CheckinEntity> get todayHistory {
    final now = DateTime.now();
    return history.where((h) {
      final localTime = h.timestamp.toLocal();
      return localTime.year == now.year &&
             localTime.month == now.month &&
             localTime.day == now.day;
    }).toList();
  }

  /// Trạng thái hiện tại: đang ở hiện trường nếu bản ghi mới nhất hôm nay là check_in
  bool get isCheckedIn {
    final today = todayHistory;
    return today.isNotEmpty && today.first.type == 'check_in';
  }
}

class CheckinFailure extends CheckinState {
  final String message;
  const CheckinFailure({required this.message});
  @override List<Object?> get props => [message];
}
