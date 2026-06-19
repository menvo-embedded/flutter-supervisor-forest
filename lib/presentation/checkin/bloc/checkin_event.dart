import 'package:equatable/equatable.dart';

abstract class CheckinEvent extends Equatable {
  const CheckinEvent();
  @override List<Object?> get props => [];
}

/// Bấm Check-in hoặc Check-out
class CheckinSubmitted extends CheckinEvent {
  final String userId, userName, type; // type: check_in | check_out
  const CheckinSubmitted({required this.userId, required this.userName, required this.type});
  @override List<Object?> get props => [userId, userName, type];
}

/// Tải lịch sử check-in/out
class CheckinHistoryRequested extends CheckinEvent {
  final String? userId;
  const CheckinHistoryRequested({this.userId});
  @override List<Object?> get props => [userId];
}
