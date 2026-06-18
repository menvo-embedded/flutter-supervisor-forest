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

  /// Trạng thái hiện tại: đang ở hiện trường (check_in chưa có check_out tương ứng)
  bool get isCheckedIn => history.isNotEmpty && history.first.type=='check_in';
}

class CheckinFailure extends CheckinState {
  final String message;
  const CheckinFailure({required this.message});
  @override List<Object?> get props => [message];
}
