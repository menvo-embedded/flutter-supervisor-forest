import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/location_service.dart';
import '../../../domain/logbook/entities/logbook_entity.dart';
import '../../../domain/logbook/repositories/logbook_repository.dart';
import 'logbook_event.dart';
import 'logbook_state.dart';

/// BLoC quản lý cả danh sách & form nhật ký hiện trường (Module 8)
class LogbookBloc extends Bloc<LogbookEvent, LogbookState> {
  final LogbookRepository repository;
  final LocationService locationService;

  LogbookBloc({required this.repository, required this.locationService})
      : super(const LogbookInitial()) {
    on<LogbookLoadRequested>(_onLoad);
    on<LogbookSubmitted>(_onSubmit);
    on<LogbookReset>((_, emit) => emit(const LogbookInitial()));
    on<LogbookDeleted>(_onDelete);
  }

  Future<void> _onDelete(LogbookDeleted event, Emitter<LogbookState> emit) async {
    emit(const LogbookLoading());
    final result = await repository.deleteLogbook(event.id, serverId: event.serverId);
    await result.fold(
      (f) async => emit(LogbookFailure(message: f.message)),
      (_) async {
        final loadResult = await repository.getLogbooks(userId: event.userId);
        final pending = await repository.getPendingCount();
        loadResult.fold(
          (f) => emit(LogbookFailure(message: f.message)),
          (items) => emit(LogbookLoaded(items: items, pendingCount: pending)),
        );
      },
    );
  }

  Future<void> _onLoad(LogbookLoadRequested event, Emitter<LogbookState> emit) async {
    emit(const LogbookLoading());
    final result = await repository.getLogbooks(userId: event.userId);
    final pending = await repository.getPendingCount();
    result.fold(
      (f) => emit(LogbookFailure(message: f.message)),
      (items) => emit(LogbookLoaded(items: items, pendingCount: pending)),
    );
  }

  Future<void> _onSubmit(LogbookSubmitted event, Emitter<LogbookState> emit) async {
    final pressTime = DateTime.now();
    emit(const LogbookSubmitting());
    try {
      // Bước 1: lấy GPS thực từ thiết bị (Module 6)
      final loc = await locationService.getCurrentLocation();

      final logbookWithGps = LogbookEntity(
        jobType: event.logbook.jobType,
        description: event.logbook.description,
        imagePaths: event.logbook.imagePaths,
        latitude: loc.latitude, longitude: loc.longitude,
        timestamp: pressTime,
        userId: event.logbook.userId, userName: event.logbook.userName,
        projectId: event.logbook.projectId,
      );

      // Bước 2: gửi qua repository (tự lưu local + đồng bộ nếu có mạng)
      final result = await repository.submitLogbook(logbookWithGps);
      result.fold(
        (f) => emit(LogbookFailure(message: f.message)),
        (saved) => emit(LogbookSubmitSuccess(saved: saved, isOnline: saved.isSynced)),
      );
    } catch (e) {
      emit(LogbookFailure(message: 'Lưu nhật ký thất bại: $e'));
    }
  }
}
