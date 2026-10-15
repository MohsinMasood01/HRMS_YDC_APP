import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/dio_client.dart';
import '../utils/server_time.dart';

/// Model for employee location tracking settings
class LocationTrackingConfig {
  final String empCode;
  final String employeeName;
  final String trackLocation; // 'Y' or 'N'
  final int trackLocationHr; // Hours interval
  final String status;
  final String message;

  LocationTrackingConfig({
    required this.empCode,
    required this.employeeName,
    required this.trackLocation,
    required this.trackLocationHr,
    required this.status,
    this.message = '',
    this.intervalMinutesFromServer,
    this.trackingCutoffAt,
    this.attendanceDate,
  });

  /// Cutoff of the employee's currently open attendance session, when the
  /// backend reports one (`tracking_cutoff_at`): shift end plus grace. Lets a
  /// restarted app, or a shift change made by HR mid-day, correct the cutoff
  /// the session was started with. Null when there is no open session or the
  /// backend does not send it.
  final DateTime? trackingCutoffAt;

  /// Roster day (yyyy-MM-dd) of the session [trackingCutoffAt] belongs to, so
  /// the app can tell whether that cutoff is for the session it is tracking.
  final String? attendanceDate;

  /// Capture interval in minutes exactly as HR configured it, or null when
  /// the backend did not state one.
  ///
  /// Kept separate from [trackLocationHr] (which carries a legacy default of
  /// 2) so callers can tell "HR said 2 hours" apart from "the backend said
  /// nothing". The scheduler needs that distinction: it falls back to the
  /// last cached interval rather than inventing one.
  final int? intervalMinutesFromServer;

  bool get isTrackingEnabled => trackLocation.toUpperCase() == 'Y';

  /// Resolved interval in minutes, or null when the backend was silent.
  int? get resolvedIntervalMinutes => intervalMinutesFromServer;

  Duration get trackingInterval => Duration(hours: trackLocationHr);

  factory LocationTrackingConfig.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    // Minutes win when present; otherwise derive them from the hours field.
    // Absent entirely -> null, meaning "backend did not say".
    final minutes =
        asInt(json['interval_minutes']) ?? asInt(json['track_location_min']);
    final hours = asInt(json['track_location_hr']);

    return LocationTrackingConfig(
      empCode: json['emp_code'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      trackLocation: json['track_location'] as String? ?? 'N',
      trackLocationHr: hours ?? 2,
      status: json['status'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      intervalMinutesFromServer:
          minutes ?? (hours != null && hours > 0 ? hours * 60 : null),
      trackingCutoffAt: parseServerInstant(json['tracking_cutoff_at']),
      attendanceDate: _dayOrNull(json['attendance_date']),
    );
  }

  static String? _dayOrNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.length >= 10 ? text.substring(0, 10) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_code': empCode,
      'employee_name': employeeName,
      'track_location': trackLocation,
      'track_location_hr': trackLocationHr,
      'status': status,
    };
  }

  @override
  String toString() {
    return 'LocationTrackingConfig(empCode: $empCode, trackingEnabled: $isTrackingEnabled, interval: ${trackLocationHr}h)';
  }
}

/// Attendance geofence settings for an employee.
///
/// When [fixedLocation] is 'Y', the employee may only mark attendance
/// (check-in / check-out) while within [margin] metres of
/// ([latitude], [longitude]).
class GeofenceSettings {
  final String empCode;
  final String employeeName;
  final String fixedLocation; // 'Y' or 'N'
  final double? latitude;
  final double? longitude;
  final double margin; // allowed radius in metres

  GeofenceSettings({
    required this.empCode,
    required this.employeeName,
    required this.fixedLocation,
    required this.latitude,
    required this.longitude,
    required this.margin,
  });

  /// True only when the geofence is enforced AND coordinates are present.
  bool get isEnforced =>
      fixedLocation.toUpperCase() == 'Y' &&
      latitude != null &&
      longitude != null;

  factory GeofenceSettings.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return GeofenceSettings(
      empCode: json['emp_code'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      fixedLocation: json['fixed_location'] as String? ?? 'N',
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      margin: toDouble(json['margin']) ?? 200.0,
    );
  }

  @override
  String toString() =>
      'GeofenceSettings(empCode: $empCode, enforced: $isEnforced, '
      'lat: $latitude, lng: $longitude, margin: ${margin}m)';
}

/// Service for managing employee location tracking configuration
class LocationTrackingConfigService {
  final Dio _dio = DioClient.instance;
  static const String _baseUrl = '/location-tracking';

  /// Fetch the attendance geofence settings for an employee.
  ///
  /// Returns `null` if the request fails — callers should treat a null
  /// result as "no geofence restriction" so a server/network hiccup never
  /// locks the whole workforce out of attendance marking.
  Future<GeofenceSettings?> getGeofenceSettings(String empCode) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/geofence/$empCode',
      );
      if (response.statusCode == 200 && response.data != null) {
        return GeofenceSettings.fromJson(response.data!);
      }
      return null;
    } on DioException catch (e) {
      debugPrint('[Geofence] Error fetching geofence settings: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[Geofence] Unexpected error fetching geofence settings: $e');
      return null;
    }
  }

  /// Get tracking settings for a specific employee
  Future<LocationTrackingConfig> getTrackingSettings(String empCode) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/settings/$empCode',
      );

      if (response.statusCode == 200 && response.data != null) {
        return LocationTrackingConfig.fromJson(response.data!);
      } else {
        throw Exception('Failed to fetch tracking settings');
      }
    } on DioException catch (e) {
      throw Exception('Error fetching tracking settings: ${e.message}');
    }
  }

  /// Update tracking settings for an employee
  Future<bool> updateTrackingSettings({
    required String empCode,
    required bool enableTracking,
    required int intervalHours,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/settings/$empCode/update',
        queryParameters: {
          'track_location': enableTracking ? 'Y' : 'N',
          'track_location_hr': intervalHours.clamp(1, 24),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data?['success'] == true;
      }
      return false;
    } on DioException catch (e) {
      throw Exception('Error updating tracking settings: ${e.message}');
    }
  }

  /// Get all employees with tracking enabled
  Future<List<LocationTrackingConfig>> getActiveTrackingEmployees() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/active-employees',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final employees = data['employees'] as List? ?? [];
        
        return employees
            .map((emp) => LocationTrackingConfig.fromJson(emp as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('Error fetching active tracking employees: ${e.message}');
    }
  }

  /// Get location tracking statistics
  Future<Map<String, dynamic>> getTrackingStatistics() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/statistics',
      );

      if (response.statusCode == 200) {
        return response.data ?? {};
      }
      return {};
    } on DioException catch (e) {
      throw Exception('Error fetching tracking statistics: ${e.message}');
    }
  }

  /// Validate if an employee should be tracked
  Future<bool> shouldTrackEmployee(String empCode) async {
    try {
      final config = await getTrackingSettings(empCode);
      return config.isTrackingEnabled;
    } catch (e) {
      debugPrint('[LocationTrackingConfig] Error checking if should track: $e');
      return false; // Default to not tracking on error
    }
  }

  /// Get tracking interval for employee (in hours)
  Future<int> getTrackingIntervalHours(String empCode) async {
    try {
      final config = await getTrackingSettings(empCode);
      return config.trackLocationHr;
    } catch (e) {
      debugPrint('[LocationTrackingConfig] Error getting interval: $e');
      return 2; // Default 2 hours on error
    }
  }
}
