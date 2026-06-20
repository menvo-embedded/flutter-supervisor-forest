import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/location_service.dart';
import '../../../domain/checkin/entities/checkin_entity.dart';
import '../../../domain/checkin/repositories/checkin_repository.dart';
import 'checkin_event.dart';
import 'checkin_state.dart';

/// BLoC Check-in GPS (Module 6 + Module 9 Mobile App)
class CheckinBloc extends Bloc<CheckinEvent, CheckinState> {
  final CheckinRepository repository;
  final LocationService locationService;

  CheckinBloc({required this.repository, required this.locationService})
      : super(const CheckinInitial()) {
    on<CheckinSubmitted>(_onSubmit);
    on<CheckinHistoryRequested>(_onLoadHistory);
  }

  Future<void> _onSubmit(
      CheckinSubmitted event, Emitter<CheckinState> emit) async {
    emit(const CheckinLoading());
    try {
      final loc = await locationService.getCurrentLocation();
      final entity = CheckinEntity(
        userId: event.userId,
        userName: event.userName,
        latitude: loc.latitude,
        longitude: loc.longitude,
        timestamp: loc.timestamp,
        type: event.type,
      );
      final result = await repository.submitCheckin(entity);
      await result.fold(
        (f) async => emit(CheckinFailure(message: f.message)),
        (saved) async {
          final history = await repository.getHistory(userId: event.userId);
          history.fold(
            (f) => emit(CheckinFailure(message: f.message)),
            (list) => emit(CheckinLoaded(history: list, lastAction: saved)),
          );
        },
      );
    } on LocationException catch (e) {
      emit(CheckinFailure(message: e.message));
    } catch (e) {
      emit(CheckinFailure(message: 'Check-in thất bại: $e'));
    }
  }

  Future<void> _onLoadHistory(
      CheckinHistoryRequested event, Emitter<CheckinState> emit) async {
    emit(const CheckinLoading());
    final result = await repository.getHistory(userId: event.userId);
    result.fold(
      (f) => emit(CheckinFailure(message: f.message)),
      (list) => emit(CheckinLoaded(history: list)),
    );
  }
}
