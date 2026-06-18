import 'package:equatable/equatable.dart';
import '../../../data/sync/sync_repository.dart';

abstract class SyncState extends Equatable {
  const SyncState();
  @override List<Object?> get props => [];
}
class SyncIdle extends SyncState {
  final int pendingCount;
  const SyncIdle({required this.pendingCount});
  @override List<Object?> get props => [pendingCount];
}
class SyncInProgress extends SyncState { const SyncInProgress(); }
class SyncCompleted extends SyncState {
  final SyncResult result;
  const SyncCompleted({required this.result});
  @override List<Object?> get props => [result];
}
class SyncFailed extends SyncState {
  final String message; final int pendingCount;
  const SyncFailed({required this.message, required this.pendingCount});
  @override List<Object?> get props => [message, pendingCount];
}
