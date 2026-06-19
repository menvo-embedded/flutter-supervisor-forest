import 'package:equatable/equatable.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';

abstract class LogbookEvent extends Equatable {
  const LogbookEvent();
  @override List<Object?> get props => [];
}

/// Tải danh sách nhật ký (theo userId nếu là Worker, null nếu Owner/Admin xem tất cả)
class LogbookLoadRequested extends LogbookEvent {
  final String? userId;
  const LogbookLoadRequested({this.userId});
  @override List<Object?> get props => [userId];
}

/// Gửi form nhật ký mới
class LogbookSubmitted extends LogbookEvent {
  final LogbookEntity logbook;
  const LogbookSubmitted({required this.logbook});
  @override List<Object?> get props => [logbook];
}

class LogbookReset extends LogbookEvent { const LogbookReset(); }
