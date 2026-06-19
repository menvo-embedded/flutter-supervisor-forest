import 'package:equatable/equatable.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';

abstract class LogbookState extends Equatable {
  const LogbookState();
  @override List<Object?> get props => [];
}

class LogbookInitial extends LogbookState { const LogbookInitial(); }
class LogbookLoading extends LogbookState { const LogbookLoading(); }

class LogbookLoaded extends LogbookState {
  final List<LogbookEntity> items;
  final int pendingCount;
  const LogbookLoaded({required this.items, required this.pendingCount});
  @override List<Object?> get props => [items, pendingCount];
}

class LogbookSubmitting extends LogbookState { const LogbookSubmitting(); }

class LogbookSubmitSuccess extends LogbookState {
  final LogbookEntity saved;
  final bool isOnline;
  const LogbookSubmitSuccess({required this.saved, required this.isOnline});
  @override List<Object?> get props => [saved, isOnline];
}

class LogbookFailure extends LogbookState {
  final String message;
  const LogbookFailure({required this.message});
  @override List<Object?> get props => [message];
}
