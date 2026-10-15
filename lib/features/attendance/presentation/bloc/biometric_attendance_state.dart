part of 'biometric_attendance_bloc.dart';

/// Status of biometric attendance process
enum BiometricAttendanceStatus {
  /// Initial state
  initial,

  /// Loading face status check
  checkingFaceStatus,

  /// Ready to mark attendance (face is registered)
  ready,

  /// Face not registered - cannot proceed
  faceNotRegistered,

  /// Capturing face frames for verification
  capturingFaceFrames,

  /// Verifying face with backend
  verifyingFace,

  /// Face verification failed
  faceVerificationFailed,

  /// Face verification succeeded - marking attendance
  markingAttendance,

  /// Attendance marked successfully
  success,

  /// Error occurred
  error,
}

/// State for biometric attendance
class BiometricAttendanceState extends Equatable {
  const BiometricAttendanceState({
    this.status = BiometricAttendanceStatus.initial,
    this.hasFaceId = false,
    this.hasFingerprint = false,
    this.availableBiometrics = const [],
    this.locationInfo,
    this.isLoadingLocation = false,
    this.locationError,
    this.isLocationServiceEnabled = true,
    this.attendanceType = 'check_in',
    this.errorMessage,
    this.successMessage,
    this.markedAt,
    this.savedFilePath,
    this.hasCheckedInToday = false,
    this.hasCheckedOutToday = false,
    this.todayCheckInTime,
    this.todayCheckOutTime,
    this.todayFromServer = false,
    this.isFaceRegistered = false,
    this.faceVerificationMessage,
    this.faceVerificationConfidence,
    this.hrSyncPending = false,
    this.markedAction,
    this.capturedFramesCount = 0,
    this.totalFramesToCapture = 20,
  });

  /// Current status of the attendance process
  final BiometricAttendanceStatus status;

  /// Whether face ID is available
  final bool hasFaceId;

  /// Whether fingerprint is available
  final bool hasFingerprint;

  /// List of available biometric types
  final List<BiometricType> availableBiometrics;

  /// Current location information
  final LocationInfo? locationInfo;

  /// Whether location is being loaded
  final bool isLoadingLocation;

  /// Location error message if any
  final String? locationError;

  /// Whether location services (GPS) are enabled on the device
  final bool isLocationServiceEnabled;

  /// Type of attendance (check_in or check_out)
  final String attendanceType;

  /// Error message if any
  final String? errorMessage;

  /// Success message after marking attendance
  final String? successMessage;

  /// Timestamp when attendance was marked
  final DateTime? markedAt;

  /// Path to the saved attendance file
  final String? savedFilePath;

  /// Whether user has checked in today
  final bool hasCheckedInToday;

  /// Whether user has checked out today
  final bool hasCheckedOutToday;

  /// Today's check-in time
  final String? todayCheckInTime;

  /// Today's check-out time
  final String? todayCheckOutTime;

  /// True when today's card reflects what the SERVER has on file. False means
  /// the server could not be reached and the card shows this phone's own
  /// record, which may not match HR.
  final bool todayFromServer;

  /// Whether face is registered on backend
  final bool isFaceRegistered;

  /// Face verification result message
  final String? faceVerificationMessage;

  /// Face verification confidence score
  final double? faceVerificationConfidence;

  /// True when the server saved the punch but the ERP roster did not take it
  /// (`posted_to_erp: false`). The punch itself is fine — this only drives a
  /// soft "HR sync pending" note so the employee raises it the same day.
  final bool hrSyncPending;

  /// What the server said it did: `check_in`, `check_out` or `noop`.
  /// Null when the backend does not report it.
  final String? markedAction;

  /// Number of frames captured for verification
  final int capturedFramesCount;

  /// Total number of frames to capture for verification
  final int totalFramesToCapture;

  /// Whether any biometric is available (from state)
  bool get isBiometricAvailable => hasFaceId || hasFingerprint;

  /// Whether location is ready
  /// Made more lenient - allow proceeding even if location is not fully ready
  bool get isLocationReady => !isLoadingLocation;

  /// Whether we can mark attendance
  /// Requires: face registered, location services enabled, and valid attendance state
  bool get canMarkAttendance {
    // Must be in ready state (face checked and registered)
    if (status != BiometricAttendanceStatus.ready) return false;

    // Face MUST be registered
    if (!isFaceRegistered) return false;

    // Location services MUST be enabled
    if (!isLocationServiceEnabled) return false;

    // Check-in: can only if not already checked in today
    if (attendanceType == 'check_in' && hasCheckedInToday) return false;

    // Check-out: can only if checked in but not checked out
    if (attendanceType == 'check_out') {
      if (!hasCheckedInToday) return false;
      if (hasCheckedOutToday) return false;
    }

    return true;
  }

  /// Get today's status text
  String get todayStatusText {
    // The server can hold a check-out with no check-in (the check-in punch
    // never reached the roster). Say so instead of "Day Complete".
    if (hasCheckedOutToday && !hasCheckedInToday) {
      return 'Check-in Missing';
    }
    if (hasCheckedOutToday) {
      return 'Day Complete';
    } else if (hasCheckedInToday) {
      return 'Checked In';
    }
    return 'Not Checked In';
  }

  /// Human-readable biometric type description
  String get biometricDescription {
    if (hasFaceId && hasFingerprint) return 'Face ID or Fingerprint';
    if (hasFaceId) return 'Face ID';
    if (hasFingerprint) return 'Fingerprint';
    return 'Biometric';
  }

  BiometricAttendanceState copyWith({
    BiometricAttendanceStatus? status,
    bool? hasFaceId,
    bool? hasFingerprint,
    List<BiometricType>? availableBiometrics,
    LocationInfo? locationInfo,
    bool? isLoadingLocation,
    String? locationError,
    bool? isLocationServiceEnabled,
    String? attendanceType,
    String? errorMessage,
    String? successMessage,
    DateTime? markedAt,
    String? savedFilePath,
    bool? hasCheckedInToday,
    bool? hasCheckedOutToday,
    String? todayCheckInTime,
    String? todayCheckOutTime,
    bool? todayFromServer,
    // Replaces both today times with exactly the values given (nulls
    // included), so a stale time can be cleared rather than kept.
    bool replaceTodayTimes = false,
    bool? isFaceRegistered,
    String? faceVerificationMessage,
    double? faceVerificationConfidence,
    bool? hrSyncPending,
    String? markedAction,
    int? capturedFramesCount,
    int? totalFramesToCapture,
  }) {
    return BiometricAttendanceState(
      status: status ?? this.status,
      hasFaceId: hasFaceId ?? this.hasFaceId,
      hasFingerprint: hasFingerprint ?? this.hasFingerprint,
      availableBiometrics: availableBiometrics ?? this.availableBiometrics,
      locationInfo: locationInfo ?? this.locationInfo,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      locationError: locationError ?? this.locationError,
      isLocationServiceEnabled:
          isLocationServiceEnabled ?? this.isLocationServiceEnabled,
      attendanceType: attendanceType ?? this.attendanceType,
      errorMessage: errorMessage,
      successMessage: successMessage,
      markedAt: markedAt,
      savedFilePath: savedFilePath,
      hasCheckedInToday: hasCheckedInToday ?? this.hasCheckedInToday,
      hasCheckedOutToday: hasCheckedOutToday ?? this.hasCheckedOutToday,
      todayCheckInTime: replaceTodayTimes
          ? todayCheckInTime
          : todayCheckInTime ?? this.todayCheckInTime,
      todayCheckOutTime: replaceTodayTimes
          ? todayCheckOutTime
          : todayCheckOutTime ?? this.todayCheckOutTime,
      todayFromServer: todayFromServer ?? this.todayFromServer,
      isFaceRegistered: isFaceRegistered ?? this.isFaceRegistered,
      faceVerificationMessage: faceVerificationMessage,
      faceVerificationConfidence: faceVerificationConfidence,
      hrSyncPending: hrSyncPending ?? this.hrSyncPending,
      markedAction: markedAction ?? this.markedAction,
      capturedFramesCount: capturedFramesCount ?? this.capturedFramesCount,
      totalFramesToCapture:
          totalFramesToCapture ?? this.totalFramesToCapture,
    );
  }

  @override
  List<Object?> get props => [
    status,
    hasFaceId,
    hasFingerprint,
    availableBiometrics,
    locationInfo,
    isLoadingLocation,
    locationError,
    isLocationServiceEnabled,
    attendanceType,
    errorMessage,
    successMessage,
    markedAt,
    savedFilePath,
    hasCheckedInToday,
    hasCheckedOutToday,
    todayCheckInTime,
    todayCheckOutTime,
    todayFromServer,
    isFaceRegistered,
    faceVerificationMessage,
    faceVerificationConfidence,
    hrSyncPending,
    markedAction,
    capturedFramesCount,
    totalFramesToCapture,
  ];
}
