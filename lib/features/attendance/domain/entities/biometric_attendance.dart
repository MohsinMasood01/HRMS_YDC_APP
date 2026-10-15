import 'package:equatable/equatable.dart';

import '../../../../core/utils/server_time.dart';

import 'location_info.dart';

class BiometricAttendanceRequest extends Equatable {
  const BiometricAttendanceRequest({
    required this.employeeId,
    required this.attendanceType,
    required this.biometricType,
    required this.locationInfo,
    required this.timestamp,
    this.deviceId,
    this.deviceModel,
    this.appVersion,
    this.appBuild,
    this.frames,
    this.clientEventId,
  });

  final String employeeId;
  final String attendanceType;
  final String biometricType;
  final LocationInfo locationInfo;
  final DateTime timestamp;
  final String? deviceId;
  final String? deviceModel;
  final String? appVersion;
  // Numeric app build (e.g. 48). Sent alongside appVersion on
  // /auth/attendance/face so the server can enforce a minimum build and
  // reject stale clients with HTTP 426.
  final int? appBuild;

  // Base64-encoded JPEG face frames (the same ones sent to /face/identify).
  // When present on a FACE mark, the backend re-identifies the scanned person
  // from these and marks whoever was scanned, ignoring [employeeId]/card_no
  // (which is kept only as a legacy fallback for builds that send no frames).
  final List<String>? frames;

  /// Idempotency key for ONE deliberate tap.
  ///
  /// Generated before the request leaves the phone and reused verbatim on
  /// every network retry of that same tap, so a lost RESPONSE can never turn
  /// into a second punch. A repeat of the same id is answered by the server
  /// with the original result. A new id is minted only when the employee taps
  /// again on purpose.
  final String? clientEventId;

  Map<String, dynamic> toJson() {
    return {
      'emp_pk': employeeId,
      'attendance_type': attendanceType,
      'biometric_type': biometricType,
      'location': locationInfo.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'device_id': deviceId,
      'device_model': deviceModel,
      'app_version': appVersion,
      'app_build': appBuild,
      if (clientEventId != null) 'client_event_id': clientEventId,
    };
  }

  @override
  List<Object?> get props => [
    employeeId,
    attendanceType,
    biometricType,
    locationInfo,
    timestamp,
    deviceId,
    deviceModel,
    appVersion,
    appBuild,
    frames,
    clientEventId,
  ];
}

class BiometricAttendanceResponse extends Equatable {
  const BiometricAttendanceResponse({
    required this.attendanceId,
    required this.markedAt,
    required this.locationVerified,
    required this.biometricVerified,
    this.success = true,
    this.message = '',
    this.markedCardNo,
    this.markedFor,
    this.isFinalCheckout,
    this.trackingState,
    this.postedToErp,
    this.action,
    this.trackingCutoffAt,
    this.attendanceDate,
  });

  final String attendanceId;
  final DateTime markedAt;
  final bool locationVerified;
  final bool biometricVerified;
  final bool success;
  final String message;

  // Who the backend ACTUALLY marked, re-identified from the face frames.
  // [markedCardNo] is the scanned person's card_no (source of truth — may
  // differ from the card_no the app sent). [markedFor] is their display name
  // (may be null). Callers must show these, not the pre-filled user.
  final String? markedCardNo;
  final String? markedFor;

  // ---- Shift-aware checkout, decided by the backend ----
  //
  // Our system allows several checkouts per shift, so the phone must never
  // infer that a checkout was the last one. [isFinalCheckout] mirrors
  // `is_final_checkout` and [trackingState] mirrors `tracking_state`
  // (ACTIVE | PAUSED | STOPPED) on the attendance response.
  //
  // Both are null when the backend does not send them; callers then treat the
  // checkout as INTERMEDIATE, which pauses tracking without ending the
  // session. See LocationTrackingService.applyCheckoutDirective.
  final bool? isFinalCheckout;
  final String? trackingState;

  // ---- ERP roster acknowledgement ----
  //
  // Mirrors `posted_to_erp`. `true` means the punch reached the ERP duty
  // roster and HRMS will show the day as present. `false` means the punch is
  // SAVED but the roster did not take it, so the day reads as absent until HR
  // corrects it -- a soft note for the employee, never an error: the punch is
  // not failed, not retried and not queued. `null` means not applicable (a
  // check-out) or not checked, and is treated as if the field did not exist.
  final bool? postedToErp;

  /// What the server actually did: `check_in`, `check_out`, or `noop`.
  ///
  /// `noop` means the punch was a repeat of one already on file (the employee
  /// was already checked in) -- the UI must say so rather than celebrating a
  /// fresh check-in. Null when the backend does not send it.
  final String? action;

  /// True when the server says this punch changed nothing: `noop` for a
  /// repeat punch, or `already_done` when the day already has both punches.
  /// Either way nothing new is on file, so nothing may be recorded locally.
  bool get isNoop {
    final value = action?.toLowerCase().trim();
    return value == 'noop' || value == 'already_done';
  }

  /// True only when the server explicitly said the ERP roster refused it.
  bool get isHrSyncPending => postedToErp == false;

  // ---- Session cutoff, computed by the backend from the shift ----
  //
  // Mirrors `tracking_cutoff_at`: the instant (UTC) after which this
  // attendance session may record no location -- the employee's shift end
  // plus the grace period. Only the backend knows the shift, so the phone
  // never computes this; it relays it to LocationTrackingService, which
  // stops capture at that instant when no checkout arrives first.
  //
  // Null when the backend does not send it; tracking then falls back to
  // TrackingSession.fallbackMaxDuration so a session still cannot stay open
  // indefinitely.
  final DateTime? trackingCutoffAt;

  /// Mirrors `attendance_date` (yyyy-MM-dd): the roster day this session
  /// belongs to. Matters for overnight shifts, where the roster day and the
  /// calendar day of a later fix differ. Null when not sent.
  final String? attendanceDate;

  factory BiometricAttendanceResponse.fromJson(Map<String, dynamic> json) {
    final header = json['header'] as Map<String, dynamic>?;
    final body = json['body'] as Map<String, dynamic>? ?? json;
    return BiometricAttendanceResponse(
      attendanceId: (body['attendance_id'] ?? '').toString(),
      markedAt: body['marked_at'] != null
          ? DateTime.parse(body['marked_at'] as String)
          : DateTime.now(),
      locationVerified: body['location_verified'] == true,
      biometricVerified: body['biometric_verified'] == true,
      success: header?['code'] == 100 || body['success'] == true,
      message: (header?['message'] ?? body['message'] ?? '').toString(),
      markedCardNo: body['card_no']?.toString(),
      markedFor: body['marked_for']?.toString(),
      isFinalCheckout: body['is_final_checkout'] as bool?,
      trackingState: body['tracking_state']?.toString(),
      postedToErp: body['posted_to_erp'] as bool?,
      action: body['action']?.toString(),
      trackingCutoffAt: parseServerInstant(body['tracking_cutoff_at']),
      attendanceDate: _dayOrNull(body['attendance_date']),
    );
  }

  /// Accepts `yyyy-MM-dd` (or a longer ISO string) and keeps the day part.
  static String? _dayOrNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.length >= 10 ? text.substring(0, 10) : null;
  }

  /// Parser for callers that build the response by hand, e.g. the face
  /// attendance branch of the remote data source.
  static String? attendanceDateFrom(Object? value) => _dayOrNull(value);

  @override
  List<Object?> get props => [
    attendanceId,
    markedAt,
    locationVerified,
    biometricVerified,
    success,
    message,
    markedCardNo,
    markedFor,
    isFinalCheckout,
    trackingState,
    postedToErp,
    action,
    trackingCutoffAt,
    attendanceDate,
  ];
}

/// Thrown when the backend rejects a FACE attendance mark because the scanned
/// face could not be confidently identified — HTTP 400 with body
/// `{ "detail": { "code": "FACE_NOT_RECOGNIZED", "message": "..." } }`.
///
/// Callers MUST surface [message] and MUST NOT record a successful mark or
/// fall back to a local save — no attendance was recorded server-side.
class FaceNotRecognizedException implements Exception {
  const FaceNotRecognizedException(this.message);

  final String message;

  @override
  String toString() => message;
}
