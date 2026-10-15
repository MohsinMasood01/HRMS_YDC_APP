import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/server_time.dart';
import '../../../../di/service_locator.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_summary.dart';
import '../../domain/entities/biometric_attendance.dart';

abstract class AttendanceRemoteDataSource {
  Future<BiometricAttendanceResponse> markBiometricAttendance(
    BiometricAttendanceRequest request,
  );

  Future<List<AttendanceRecord>> getAttendanceHistory({
    required String empPk,
    required String fromDate,
    required String toDate,
  });

  Future<AttendanceSummary> getAttendanceSummary({
    required String empPk,
    required String fromDate,
    required String toDate,
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  AttendanceRemoteDataSourceImpl({
    Dio? dio,
    required Future<String?> Function() cardNo1Provider,
  }) : _dio = dio ?? DioClient.instance,
       _cardNo1Provider = cardNo1Provider;

  final Dio _dio;
  final Future<String?> Function() _cardNo1Provider;

  /// Total attempts for one tap (the first send plus two retries).
  static const int _maxPunchAttempts = 3;

  /// True when we never received an answer, so the punch may or may not have
  /// been recorded. Anything with a `response` is a definite answer.
  static bool _isLostResponse(DioException e) {
    if (e.response != null) return false;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // Dio reports offline sockets as `unknown` on some platforms.
        final text = (e.error ?? e.message ?? '').toString().toLowerCase();
        return text.contains('socketexception') ||
            text.contains('connection closed') ||
            text.contains('connection reset') ||
            text.contains('software caused connection abort');
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  /// Attach Authorization header (Bearer token) like other LMS API calls.
  Future<Map<String, dynamic>?> _authorizedPost(
    String path, {
    Object? data,
  }) async {
    final secureStorage = getIt<SecureStorageService>();
    final token = await secureStorage.read('token');

    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(headers: headers),
    );

    return response.data;
  }

  Future<Map<String, dynamic>?> _authorizedGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final secureStorage = getIt<SecureStorageService>();
    final token = await secureStorage.read('token');

    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );

    return response.data;
  }

  @override
  Future<BiometricAttendanceResponse> markBiometricAttendance(
    BiometricAttendanceRequest request,
  ) async {
    // Route FACE biometric attendance to the dedicated Face Attendance API
    if (request.biometricType.toLowerCase() == 'face') {
      var cardNo1 = await _cardNo1Provider() ?? '';

      // In identify mode (login page), secure storage may be empty.
      // Fall back to the employeeId from the request (set by face identify).
      if (cardNo1.isEmpty && request.employeeId.isNotEmpty) {
        cardNo1 = request.employeeId;
      }

      if (cardNo1.isEmpty) {
        throw Exception('Card number not found. Please login again.');
      }

      final location = request.locationInfo;
      // DB column "ADDRESS" is VARCHAR2(100) - avoid ORA-12899 by trimming.
      final rawAddress = location.address ?? location.displayAddress;
      final safeAddress = rawAddress.length > 100
          ? rawAddress.substring(0, 100)
          : rawAddress;

      final payload = <String, dynamic>{
        'card_no': cardNo1,
        // Backend accepts "check_in" / "check_out" as used across the app.
        'attendance_type': request.attendanceType,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'accuracy': location.accuracy,
        'address': safeAddress,
        'formatted_address':
            location.formattedAddress ?? location.displayAddress,
        'timestamp': request.timestamp.toIso8601String(),
        'device_id': request.deviceId,
        'device_model': request.deviceModel,
        'app_version': request.appVersion,
        'app_build': request.appBuild,
        // Idempotency key for this tap. Repeated verbatim on every retry
        // below so a lost response can never become a second punch.
        if (request.clientEventId != null)
          'client_event_id': request.clientEventId,
      };

      // Attach the scanned face frames so the server re-identifies the person
      // and marks WHOEVER was scanned (ignoring card_no above, which stays a
      // legacy fallback for old builds). Requires >= 5 frames server-side.
      final frames = request.frames;
      if (frames != null && frames.isNotEmpty) {
        payload['frames'] = frames;
      }

      // The request may have REACHED the server even when we never see the
      // response, so a dropped connection is retried with the same
      // client_event_id rather than reported as a failure the employee would
      // tap through again (which is what turned a second tap into a
      // check-out). A response -- of any status -- is a definite answer and is
      // never retried.
      Map<String, dynamic> data;
      var attempt = 0;
      while (true) {
        attempt++;
        try {
          data =
              await _authorizedPost('/auth/attendance/face', data: payload) ??
              <String, dynamic>{};
          break;
        } on DioException catch (e) {
          // 400 with detail.code == FACE_NOT_RECOGNIZED → the scanned face
          // could not be identified. Surface a typed exception so the caller
          // shows the rejection and does NOT record a successful mark.
          if (e.response?.statusCode == 400) {
            final detail = (e.response?.data is Map)
                ? (e.response!.data as Map)['detail']
                : null;
            if (detail is Map && detail['code'] == 'FACE_NOT_RECOGNIZED') {
              throw FaceNotRecognizedException(
                (detail['message'] as String?) ??
                    'Face not recognized. Attendance not marked.',
              );
            }
          }

          final canRetry = request.clientEventId != null &&
              _isLostResponse(e) &&
              attempt < _maxPunchAttempts;
          if (!canRetry) rethrow;

          final backoff = Duration(seconds: attempt);
          debugPrint(
            'AttendanceRemoteDataSource: punch attempt $attempt lost '
            '(${e.type}); retrying same client_event_id in '
            '${backoff.inSeconds}s',
          );
          await Future<void>.delayed(backoff);
        }
      }

      // API returns: { "body": { "marked_at": "...", "location_verified": true,
      //   "card_no": "<scanned person>", "marked_for": "<name>" } }
      final body = (data['body'] as Map<String, dynamic>?) ?? data;

      final markedAtStr = body['marked_at']?.toString();
      DateTime markedAt;
      if (markedAtStr != null && markedAtStr.isNotEmpty) {
        // Backend returns "HH:MI" format (e.g. "14:30"), not ISO 8601.
        // Try ISO parse first, then fall back to HH:MI → today's DateTime.
        markedAt = DateTime.tryParse(markedAtStr) ?? _parseHHMM(markedAtStr);
      } else {
        markedAt = DateTime.now();
      }

      final locationVerified = body['location_verified'] == true;

      // Who the server actually marked (re-identified from the frames). These
      // are the source of truth for the confirmation UI — may differ from the
      // card_no we sent.
      final markedCardNo = body['card_no']?.toString();
      final markedFor = body['marked_for']?.toString();

      return BiometricAttendanceResponse(
        attendanceId: (body['attendance_id'] ?? '').toString(),
        markedAt: markedAt,
        locationVerified: locationVerified,
        // Face has already been verified on the frontend before this call
        biometricVerified: true,
        // A 2xx is only a success when the body does not say otherwise.
        success: body['success'] != false &&
            body['status']?.toString().toLowerCase() != 'error',
        message: (body['message'] ?? 'Attendance marked successfully')
            .toString(),
        markedCardNo: (markedCardNo != null && markedCardNo.isNotEmpty)
            ? markedCardNo
            : null,
        markedFor: (markedFor != null && markedFor.isNotEmpty)
            ? markedFor
            : null,
        // Shift-aware checkout ruling. The backend owns this decision because
        // it alone knows the shift; the app only relays it to tracking.
        isFinalCheckout: body['is_final_checkout'] as bool?,
        trackingState: body['tracking_state']?.toString(),
        // Saved-but-not-on-the-roster. A soft note for the employee, never a
        // failure — see BiometricAttendanceResponse.postedToErp.
        postedToErp: body['posted_to_erp'] as bool?,
        // What the server actually did, including 'noop' for a repeat punch.
        action: body['action']?.toString(),
        // When this session must stop recording location if no checkout
        // arrives first (shift end + grace). Computed by the backend, which
        // alone knows the employee's shift.
        trackingCutoffAt: parseServerInstant(body['tracking_cutoff_at']),
        attendanceDate: BiometricAttendanceResponse.attendanceDateFrom(
          body['attendance_date'],
        ),
      );
    }

    // Fallback for non-face biometric types (legacy endpoint)
    final data =
        await _authorizedPost(
          '/auth/attendance/biometric',
          data: request.toJson(),
        ) ??
        <String, dynamic>{};

    return BiometricAttendanceResponse.fromJson(data);
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceHistory({
    required String empPk,
    required String fromDate,
    required String toDate,
  }) async {
    final cardNo1 = await _cardNo1Provider() ?? '';

    if (cardNo1.isEmpty) {
      return <AttendanceRecord>[];
    }

    // Single bulk API call for the entire date range
    final data = await _authorizedGet(
      '/auth/attendance/report-range/$cardNo1',
      queryParameters: {
        'from_date': fromDate,
        'to_date': toDate,
      },
    );
    return _parseAttendanceHistoryResponse(data);
  }

  @override
  Future<AttendanceSummary> getAttendanceSummary({
    required String empPk,
    required String fromDate,
    required String toDate,
  }) async {
    final data = await _authorizedGet(
      '/auth/attendance/summary',
      queryParameters: {
        'emp_pk': empPk,
        'from_date': fromDate,
        'to_date': toDate,
      },
    );
    final body = data?['body'] as Map<String, dynamic>? ?? {};
    return AttendanceSummary(
      casualLeave: _asInt(body['casual_leave']),
      earnedLeave: _asInt(body['earned_leave']),
      medicalLeave: _asInt(body['medical_leave']),
      compensatoryLeave: _asInt(body['compensatory_leave']),
      sickLeave: _asInt(body['sick_leave']),
      lossOfPay: _asInt(body['loss_of_pay']),
      absent: _asInt(body['absent']),
      outdoorDuty: _asInt(body['outdoor_duty']),
      approvedExtraWork: _asInt(body['approved_extra_work']),
      lateCount: _asInt(body['late_count']),
      totalDays: _asInt(body['total_days']),
      presentDays: _asInt(body['present']),
      incompleteDays: _asInt(body['incomplete']),
      totalMinutes: _asInt(body['total_minutes']),
    );
  }

  List<AttendanceRecord> _parseAttendanceHistoryResponse(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return [];

    // New ORDS-style response: { "items": [ ... ] }
    if (data.containsKey('items')) {
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((item) => _mapRecord(item as Map<String, dynamic>))
          .toList();
    }

    // Legacy response: { "body": { "records": [ ... ] } }
    final body = data['body'] as Map<String, dynamic>? ?? {};
    final records = body['records'] as List<dynamic>? ?? [];
    return records
        .map((record) => _mapRecord(record as Map<String, dynamic>))
        .toList();
  }

  AttendanceRecord _mapRecord(Map<String, dynamic> json) {
    Duration parseDuration(String? value) {
      if (value == null || value.isEmpty) return Duration.zero;
      final parts = value.split(':').map(int.parse).toList();
      final hours = parts.isNotEmpty ? parts[0] : 0;
      final minutes = parts.length > 1 ? parts[1] : 0;
      final seconds = parts.length > 2 ? parts[2] : 0;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }

    // New ORDS /attendance/report format (roster_date, in_time, out_time, etc.)
    if (json.containsKey('roster_date')) {
      final rosterDateStr = json['roster_date']?.toString();
      DateTime date;
      try {
        date = rosterDateStr != null && rosterDateStr.isNotEmpty
            ? DateTime.parse(rosterDateStr)
            : DateTime.now();
      } catch (_) {
        date = DateTime.now();
      }

      final timeIn = parseDuration(json['in_time'] as String?);
      final timeOut = parseDuration(json['out_time'] as String?);

      // Use w_hrs/w_mnt from DUTY_ROSTER if available, else approximate
      final wHrs = _asInt(json['w_hrs']);
      final wMnt = _asInt(json['w_mnt']);
      final workHours = (wHrs > 0 || wMnt > 0)
          ? Duration(hours: wHrs, minutes: wMnt)
          : (timeIn != Duration.zero && timeOut != Duration.zero
              ? timeOut - timeIn
              : Duration.zero);

      final lateHrs = _asInt(json['late_hrs']);
      final lateMnt = _asInt(json['late_mnt']);
      final lateArrival = Duration(hours: lateHrs, minutes: lateMnt);

      final isAbsent = (json['absent_days'] is num)
          ? (json['absent_days'] as num) > 0
          : false;

      return AttendanceRecord(
        date: date,
        shift: (json['roster_shift'] ?? '').toString(),
        day: date.day,
        timeIn: timeIn,
        timeOut: timeOut,
        workHours: workHours,
        lateArrival: lateArrival,
        approvedHours: Duration.zero,
        remarks: (json['status'] ?? json['roster_remarks'] ?? '').toString(),
        isAbsent: isAbsent,
      );
    }

    // Legacy /attendance/report format (date, shift, time_in, etc.)
    return AttendanceRecord(
      date: DateTime.parse(json['date'] as String),
      shift: (json['shift'] ?? '').toString(),
      day: _asInt(json['day']),
      timeIn: parseDuration(json['time_in'] as String?),
      timeOut: parseDuration(json['time_out'] as String?),
      workHours: parseDuration(json['work_hours'] as String?),
      lateArrival: parseDuration(json['late_arrival'] as String?),
      approvedHours: parseDuration(json['approved_hours'] as String?),
      remarks: (json['remarks'] ?? '').toString(),
      isAbsent: json['is_absent'] == true,
    );
  }

  /// Parse "HH:MI" time string into today's DateTime.
  DateTime _parseHHMM(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final now = DateTime.now();
      return DateTime(
        now.year, now.month, now.day,
        int.parse(parts[0]),
        parts.length > 1 ? int.parse(parts[1]) : 0,
      );
    } catch (_) {
      return DateTime.now();
    }
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

}
