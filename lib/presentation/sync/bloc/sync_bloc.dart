import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/sync/sync_repository.dart';
import 'sync_event.dart';
import 'sync_state.dart';

/// BLoC điều phối đồng bộ Offline -> Online (Module 9)
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository repository;
  SyncBloc({required this.repository}) : super(const SyncIdle(pendingCount: 0)) {
    on<SyncStatusChecked>(_onCheck);
    on<SyncRequested>(_onSync);
  }

  Future<void> _onCheck(SyncStatusChecked event, Emitter<SyncState> emit) async {
    final count = await repository.getPendingCount();
    emit(SyncIdle(pendingCount: count));
  }

  Future<void> _onSync(SyncRequested event, Emitter<SyncState> emit) async {
    emit(const SyncInProgress());
    try {
      final result = await repository.syncAll();
      if (!result.isOnline && result.totalPending > 0) {
        emit(SyncFailed(message: 'Không có mạng. Sẽ tự đồng bộ sau.', pendingCount: result.totalPending));
        return;
      }
      emit(SyncCompleted(result: result));
    } catch (e) {
      final count = await repository.getPendingCount();
      emit(SyncFailed(message: e.toString(), pendingCount: count));
    }
  }
}
