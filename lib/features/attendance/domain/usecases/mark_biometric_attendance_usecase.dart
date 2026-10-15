import '../../domain/entities/biometric_attendance.dart';
import '../../domain/entities/location_info.dart';
import '../repositories/attendance_repository.dart';

/// Use case for marking attendance with biometric verification
///
/// This use case handles:
/// - Biometric authentication verification
/// - Location info gathering
/// - Attendance marking API call
class MarkBiometricAttendanceUseCase {
  MarkBiometricAttendanceUseCase(this._repository);

  final AttendanceRepository _repository;

  /// Mark attendance with biometric verification
  ///
  /// [employeeId] - Employee identifier
  /// [attendanceType] - Either 'check_in' or 'check_out'
  /// [biometricType] - Either 'fingerprint' or 'face'
  /// [locationInfo] - Location details including coordinates and landmarks
  /// [deviceId] - Unique device identifier
  /// [deviceModel] - Device model name
  /// [appVersion] - App version string (e.g. "1.4.2")
  /// [appBuild]   - App build number as int (e.g. 48)
  /// [frames]     - Base64 JPEG face frames (the same ones sent to
  ///                /face/identify). When present on a face mark, the backend
  ///                re-identifies the scanned person and marks whoever scanned.
  /// [clientEventId] - Idempotency key for ONE deliberate tap. The data source
  ///                reuses it on every network retry of that tap, so a lost
  ///                response cannot become a second punch.
  Future<BiometricAttendanceResponse> call({
    required String employeeId,
    required String attendanceType,
    required String biometricType,
    required LocationInfo locationInfo,
    String? deviceId,
    String? deviceModel,
    String? appVersion,
    int? appBuild,
    List<String>? frames,
    String? clientEventId,
  }) async {
    final request = BiometricAttendanceRequest(
      employeeId: employeeId,
      attendanceType: attendanceType,
      biometricType: biometricType,
      locationInfo: locationInfo,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      deviceModel: deviceModel,
      appVersion: appVersion,
      appBuild: appBuild,
      frames: frames,
      clientEventId: clientEventId,
    );

    return _repository.markBiometricAttendance(request);
  }
}
