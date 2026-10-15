part of 'biometric_attendance_bloc.dart';

/// Base event for biometric attendance
abstract class BiometricAttendanceEvent extends Equatable {
  const BiometricAttendanceEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the biometric attendance feature
class BiometricAttendanceInitialized extends BiometricAttendanceEvent {
  const BiometricAttendanceInitialized();
}

/// Request current location with address details
class BiometricAttendanceLocationRequested extends BiometricAttendanceEvent {
  const BiometricAttendanceLocationRequested();
}

/// Request to mark attendance with biometric verification
class BiometricAttendanceMarkRequested extends BiometricAttendanceEvent {
  const BiometricAttendanceMarkRequested();
}

/// Change attendance type (check-in or check-out)
class BiometricAttendanceTypeChanged extends BiometricAttendanceEvent {
  const BiometricAttendanceTypeChanged(this.type);

  final String type;

  @override
  List<Object?> get props => [type];
}

/// Reset state for new attendance marking
class BiometricAttendanceReset extends BiometricAttendanceEvent {
  const BiometricAttendanceReset();
}

/// Check today's attendance status
class BiometricAttendanceCheckTodayStatus extends BiometricAttendanceEvent {
  const BiometricAttendanceCheckTodayStatus();
}

/// Open location settings
class BiometricAttendanceOpenLocationSettings extends BiometricAttendanceEvent {
  const BiometricAttendanceOpenLocationSettings();
}
