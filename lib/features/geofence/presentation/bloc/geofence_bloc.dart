import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/geofence_service.dart';
import '../../domain/entities/geofence_status.dart';
import '../../domain/usecases/manual_attendance_override_usecase.dart';
import '../../domain/usecases/mark_automatic_check_in_usecase.dart';

part 'geofence_event.dart';
part 'geofence_state.dart';

/// BLoC for managing geofence state and attendance
/// 
/// This bloc handles:
/// - Starting/stopping geofence monitoring
/// - Processing geofence status updates
/// - Auto-marking attendance on entry
/// - Manual attendance override
class GeoFenceBloc extends Bloc<GeoFenceEvent, GeoFenceState> {
  GeoFenceBloc(
    this._geoFenceService,
    this._markAutomaticCheckInUseCase,
    this._manualAttendanceOverrideUseCase,
  ) : super(const GeoFenceState()) {
    on<GeoFenceStarted>(_onStarted);
    on<_GeoFenceStatusUpdated>(_onStatusUpdated);
    on<GeoFenceManualOverrideRequested>(_onManualOverride);
    on<GeoFenceRefreshRequested>(_onRefreshRequested);
    on<GeoFenceStopped>(_onStopped);
    on<GeoFenceOfflineSyncRequested>(_onOfflineSyncRequested);
  }

  final GeoFenceService _geoFenceService;
  final MarkAutomaticCheckInUseCase _markAutomaticCheckInUseCase;
  final ManualAttendanceOverrideUseCase _manualAttendanceOverrideUseCase;

  StreamSubscription<GeoFenceStatus>? _subscription;

  /// Start geofence monitoring
  Future<void> _onStarted(GeoFenceStarted event, Emitter<GeoFenceState> emit) async {
    // Cancel existing subscription
    await _subscription?.cancel();

    // Subscribe to status updates
    _subscription = _geoFenceService.statusStream.listen((status) {
      add(_GeoFenceStatusUpdated(status));
    });

    // Start monitoring
    await _geoFenceService.startMonitoring();
  }

  /// Handle status updates from the geofence service
  Future<void> _onStatusUpdated(
    _GeoFenceStatusUpdated event,
    Emitter<GeoFenceState> emit,
  ) async {
    final status = event.status;
    
    // Update state with new status
    emit(state.copyWith(status: status));

    // Handle entry event - mark attendance automatically
    if (status.shouldMarkEntry) {
      try {
        await _markAutomaticCheckInUseCase();
        emit(state.copyWith(
          lastMessage: 'Attendance marked automatically',
        ));
      } catch (e) {
        emit(state.copyWith(
          lastMessage: 'Failed to mark attendance: $e',
        ));
      }
    }

    // Handle exit event
    if (status.isExitEvent) {
      emit(state.copyWith(
        lastMessage: 'You have left the office zone',
      ));
    }

    // Handle errors
    if (status.hasError) {
      emit(state.copyWith(
        lastMessage: status.errorMessage,
      ));
    }

    // Handle mock location detection
    if (status.isMockLocation) {
      emit(state.copyWith(
        lastMessage: 'Warning: Mock location detected. Attendance cannot be marked.',
      ));
    }
  }

  /// Handle manual attendance override
  Future<void> _onManualOverride(
    GeoFenceManualOverrideRequested event,
    Emitter<GeoFenceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    
    try {
      await _manualAttendanceOverrideUseCase(note: event.note);
      emit(state.copyWith(
        isSubmitting: false,
        lastMessage: 'Manual override submitted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        lastMessage: 'Failed to submit override: $e',
      ));
    }
  }

  /// Handle refresh request
  Future<void> _onRefreshRequested(
    GeoFenceRefreshRequested event,
    Emitter<GeoFenceState> emit,
  ) async {
    await _geoFenceService.refreshStatus();
  }

  /// Handle stop request
  Future<void> _onStopped(
    GeoFenceStopped event,
    Emitter<GeoFenceState> emit,
  ) async {
    _geoFenceService.stopMonitoring();
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Handle offline sync request
  Future<void> _onOfflineSyncRequested(
    GeoFenceOfflineSyncRequested event,
    Emitter<GeoFenceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    
    try {
      await _geoFenceService.syncOfflineEntries();
      final pendingCount = _geoFenceService.offlineQueueCount;
      
      if (pendingCount == 0) {
        emit(state.copyWith(
          isSubmitting: false,
          lastMessage: 'All offline entries synced successfully',
        ));
      } else {
        emit(state.copyWith(
          isSubmitting: false,
          lastMessage: '$pendingCount entries still pending sync',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        lastMessage: 'Sync failed: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
