import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Service for validating attendance marking rules
///
/// Handles:
/// - Multiple check-ins allowed (from different locations only)
/// - Duplicate check-in prevention (same location - no duplicates allowed)
/// - Duplicate check-out prevention
/// - Offline attendance tracking
class AttendanceValidationService {
  AttendanceValidationService(this._prefs);

  final SharedPreferences _prefs;

  /// Current user identifier — set before each attendance flow so that
  /// check-in / check-out history is scoped per employee, not per device.
  String _currentUserId = '';

  void setCurrentUser(String userId) {
    _currentUserId = userId;
  }

  /// Per-user prefix so different employees on the same phone don't clash.
  String get _prefix => _currentUserId.isNotEmpty ? '${_currentUserId}_' : '';

  String get _checkInHistoryKey => '${_prefix}check_in_history';
  String get _checkOutKey => '${_prefix}last_check_out_date';
  String get _checkOutTimeKey => '${_prefix}last_check_out_time';
  String get _checkOutLocationKey => '${_prefix}last_check_out_location';

  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm:ss');

  /// Maximum distance (in meters) to consider same location
  static const double _sameLocationDistanceMeters = 50.0;

  /// Check if user can mark check-in (allows multiple from different locations)
  AttendanceValidationResult canCheckIn({
    required double latitude,
    required double longitude,
  }) {
    final now = DateTime.now();
    final today = _dateFormat.format(now);

    // Get check-in history for today
    final historyJson = _prefs.getString(_checkInHistoryKey);
    if (historyJson != null) {
      try {
        final history = (jsonDecode(historyJson) as List)
            .map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
            .toList();

        // Filter today's check-ins
        final todayCheckIns = history.where((record) {
          final recordDate = _dateFormat.format(record.timestamp);
          return recordDate == today;
        }).toList();

        // Check for duplicate from same location (no time restriction - prevent all duplicates from same location)
        for (final record in todayCheckIns) {
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            record.latitude,
            record.longitude,
          );

          // If same location, prevent duplicate check-in
          if (distance <= _sameLocationDistanceMeters) {
            final timeDifference = now.difference(record.timestamp);
            final hours = timeDifference.inHours;
            final minutes = timeDifference.inMinutes.remainder(60);

            String timeAgo;
            if (hours > 0) {
              timeAgo =
                  '$hours hour${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes minute${minutes > 1 ? 's' : ''}' : ''} ago';
            } else {
              timeAgo = '$minutes minute${minutes > 1 ? 's' : ''} ago';
            }

            return AttendanceValidationResult(
              canProceed: false,
              reason:
                  'You have already checked in from this location today ($timeAgo). '
                  'Please move to a different location to mark another check-in.',
              errorType: AttendanceErrorType.duplicateCheckIn,
            );
          }
        }
      } catch (e) {
        // If parsing fails, clear and allow check-in
        _prefs.remove(_checkInHistoryKey);
      }
    }

    return const AttendanceValidationResult(
      canProceed: true,
      reason: 'Check-in allowed',
    );
  }

  /// Check if user can mark check-out today
  AttendanceValidationResult canCheckOut() {
    final today = _dateFormat.format(DateTime.now());
    final lastCheckOutDate = _prefs.getString(_checkOutKey);

    // Check if there are any check-ins today
    final historyJson = _prefs.getString(_checkInHistoryKey);
    bool hasCheckedInToday = false;

    if (historyJson != null) {
      try {
        final history = (jsonDecode(historyJson) as List)
            .map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
            .toList();

        hasCheckedInToday = history.any((record) {
          final recordDate = _dateFormat.format(record.timestamp);
          return recordDate == today;
        });
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Must have checked in first
    if (!hasCheckedInToday) {
      return const AttendanceValidationResult(
        canProceed: false,
        reason: 'You must check in first before checking out',
        errorType: AttendanceErrorType.noCheckIn,
      );
    }

    // Cannot checkout twice
    if (lastCheckOutDate == today) {
      final lastTime = _prefs.getString(_checkOutTimeKey) ?? '';
      return AttendanceValidationResult(
        canProceed: false,
        reason: 'You have already checked out today at $lastTime',
        errorType: AttendanceErrorType.duplicateCheckOut,
      );
    }

    return const AttendanceValidationResult(
      canProceed: true,
      reason: 'Check-out allowed',
    );
  }

  /// Validate if location is within geofence
  AttendanceValidationResult validateGeofence({
    required double latitude,
    required double longitude,
    required double officeLatitude,
    required double officeLongitude,
    required double allowedRadiusMeters,
    required double currentDistance,
  }) {
    if (currentDistance > allowedRadiusMeters) {
      return AttendanceValidationResult(
        canProceed: false,
        reason:
            'You are ${currentDistance.toStringAsFixed(0)}m away from office. '
            'Must be within ${allowedRadiusMeters.toStringAsFixed(0)}m to mark attendance.',
        errorType: AttendanceErrorType.outsideGeofence,
      );
    }

    return const AttendanceValidationResult(
      canProceed: true,
      reason: 'Within geofence',
    );
  }

  /// Record successful check-in with location
  Future<void> recordCheckIn({
    required double latitude,
    required double longitude,
  }) async {
    final now = DateTime.now();
    final record = CheckInRecord(
      timestamp: now,
      latitude: latitude,
      longitude: longitude,
    );

    // Get existing history
    final historyJson = _prefs.getString(_checkInHistoryKey);
    List<CheckInRecord> history = [];

    if (historyJson != null) {
      try {
        history = (jsonDecode(historyJson) as List)
            .map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        history = [];
      }
    }

    // Add new record
    history.add(record);

    // Keep only last 100 records to prevent storage bloat
    if (history.length > 100) {
      history = history.sublist(history.length - 100);
    }

    // Save back
    final updatedJson = jsonEncode(history.map((r) => r.toJson()).toList());
    await _prefs.setString(_checkInHistoryKey, updatedJson);
  }

  /// Record successful check-out with location
  Future<void> recordCheckOut({
    required double latitude,
    required double longitude,
  }) async {
    final today = _dateFormat.format(DateTime.now());
    final time = _timeFormat.format(DateTime.now());
    final location = '$latitude,$longitude';

    await _prefs.setString(_checkOutKey, today);
    await _prefs.setString(_checkOutTimeKey, time);
    await _prefs.setString(_checkOutLocationKey, location);
  }

  /// Get today's attendance status
  TodayAttendanceStatus getTodayStatus() {
    final today = _dateFormat.format(DateTime.now());
    final lastCheckOutDate = _prefs.getString(_checkOutKey);
    final checkOutTime = _prefs.getString(_checkOutTimeKey);

    // Check if there are any check-ins today
    final historyJson = _prefs.getString(_checkInHistoryKey);
    bool hasCheckedIn = false;
    String? checkInTime;

    if (historyJson != null) {
      try {
        final history = (jsonDecode(historyJson) as List)
            .map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
            .toList();

        final todayCheckIns = history.where((record) {
          final recordDate = _dateFormat.format(record.timestamp);
          return recordDate == today;
        }).toList();

        if (todayCheckIns.isNotEmpty) {
          hasCheckedIn = true;
          // Get the latest check-in time
          todayCheckIns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          checkInTime = _timeFormat.format(todayCheckIns.first.timestamp);
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    final hasCheckedOut = lastCheckOutDate == today;

    return TodayAttendanceStatus(
      hasCheckedIn: hasCheckedIn,
      hasCheckedOut: hasCheckedOut,
      checkInTime: checkInTime,
      checkOutTime: hasCheckedOut ? checkOutTime : null,
    );
  }

  /// Get today's check-in count
  int getTodayCheckInCount() {
    final today = _dateFormat.format(DateTime.now());
    final historyJson = _prefs.getString(_checkInHistoryKey);

    if (historyJson == null) return 0;

    try {
      final history = (jsonDecode(historyJson) as List)
          .map((e) => CheckInRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      return history.where((record) {
        final recordDate = _dateFormat.format(record.timestamp);
        return recordDate == today;
      }).length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear attendance records (for testing or admin reset)
  Future<void> clearRecords() async {
    await _prefs.remove(_checkInHistoryKey);
    await _prefs.remove(_checkOutKey);
    await _prefs.remove(_checkOutTimeKey);
    await _prefs.remove(_checkOutLocationKey);
  }
}

/// Check-in record with location and timestamp
class CheckInRecord {
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  CheckInRecord({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory CheckInRecord.fromJson(Map<String, dynamic> json) {
    return CheckInRecord(
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// Result of attendance validation
class AttendanceValidationResult {
  const AttendanceValidationResult({
    required this.canProceed,
    required this.reason,
    this.errorType,
  });

  final bool canProceed;
  final String reason;
  final AttendanceErrorType? errorType;
}

/// Types of attendance validation errors
enum AttendanceErrorType {
  duplicateCheckIn,
  duplicateCheckOut,
  noCheckIn,
  outsideGeofence,
  mockLocationDetected,
  poorGpsAccuracy,
}

/// Today's attendance status
class TodayAttendanceStatus {
  const TodayAttendanceStatus({
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    this.checkInTime,
    this.checkOutTime,
  });

  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final String? checkInTime;
  final String? checkOutTime;

  /// Human-readable status
  String get statusText {
    if (!hasCheckedIn) return 'Not Checked In';
    if (!hasCheckedOut) return 'Checked In';
    return 'Day Complete';
  }

  /// Whether any attendance action can be taken
  bool get canMarkAttendance => !hasCheckedIn || !hasCheckedOut;

  /// What type of attendance can be marked
  String? get nextAction {
    if (!hasCheckedIn) return 'check_in';
    if (!hasCheckedOut) return 'check_out';
    return null;
  }
}
