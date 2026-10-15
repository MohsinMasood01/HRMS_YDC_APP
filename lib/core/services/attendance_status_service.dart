import 'package:flutter/material.dart';

enum AttendanceDayStatus {
  present,
  late,
  halfDay,
  absent,
  onLeave,
  earlyCheckout,
  outdoorDuty,
}

class AttendanceStatusService {
  // Office start time: 9:30 AM (with 10 minutes grace period)
  static const int officeStartHour = 9;
  static const int officeStartMinute = 30;
  static const int gracePeriodMinutes = 10;

  // Late arrival window: 9:41 AM - 11:29 AM
  // Half day cutoff: 11:30 AM
  static const int halfDayCutoffHour = 11;
  static const int halfDayCutoffMinute = 30;

  /// Determine attendance status based on check-in time and other factors.
  static AttendanceDayStatus getAttendanceStatus({
    required Duration checkInTime,
    required bool isAbsent,
    required bool isOnLeave,
    Duration? checkOutTime,
    bool isOutdoorDuty = false,
  }) {
    if (isAbsent) {
      return AttendanceDayStatus.absent;
    }
    if (isOnLeave) {
      return AttendanceDayStatus.onLeave;
    }
    if (isOutdoorDuty) {
      return AttendanceDayStatus.outdoorDuty;
    }

    // Convert Duration to DateTime for comparison on a dummy date
    final dummyDate = DateTime(2000, 1, 1);
    final actualCheckInDateTime = dummyDate.add(checkInTime);

    // Define office start with grace period and half-day cutoff as DateTime objects
    final officeStartDateTime = DateTime(
      dummyDate.year,
      dummyDate.month,
      dummyDate.day,
      officeStartHour,
      officeStartMinute,
    );
    final gracePeriodEndDateTime = officeStartDateTime.add(
      Duration(minutes: gracePeriodMinutes),
    );
    final lateCutoffDateTime = DateTime(
      dummyDate.year,
      dummyDate.month,
      dummyDate.day,
      halfDayCutoffHour,
      halfDayCutoffMinute,
    );

    // Check if check-in is before or within grace period (on time)
    if (actualCheckInDateTime.isBefore(gracePeriodEndDateTime) ||
        actualCheckInDateTime.isAtSameMomentAs(gracePeriodEndDateTime)) {
      return AttendanceDayStatus.present;
    }

    // Check if check-in is after grace period but before late cutoff (late)
    if (actualCheckInDateTime.isAfter(gracePeriodEndDateTime) &&
        actualCheckInDateTime.isBefore(lateCutoffDateTime)) {
      return AttendanceDayStatus.late;
    }

    // Check if check-in is at or after late cutoff (half day)
    if (actualCheckInDateTime.isAtSameMomentAs(lateCutoffDateTime) ||
        actualCheckInDateTime.isAfter(lateCutoffDateTime)) {
      return AttendanceDayStatus.halfDay;
    }

    // Default to present if none of the above conditions are met
    return AttendanceDayStatus.present;
  }

  /// Get status color for calendar display
  static int getStatusColor(AttendanceDayStatus status) {
    switch (status) {
      case AttendanceDayStatus.present:
        return 0xFF4CAF50; // Green
      case AttendanceDayStatus.late:
        return 0xFFF44336; // Red
      case AttendanceDayStatus.halfDay:
        return 0xFFFF9800; // Orange
      case AttendanceDayStatus.absent:
        return 0xFF757575; // Grey
      case AttendanceDayStatus.onLeave:
        return 0xFFFFEB3B; // Yellow
      case AttendanceDayStatus.earlyCheckout:
        return 0xFF2196F3; // Blue
      case AttendanceDayStatus.outdoorDuty:
        return 0xFF9C27B0; // Purple
    }
  }

  /// Get status icon for calendar display
  static String getStatusIcon(AttendanceDayStatus status) {
    switch (status) {
      case AttendanceDayStatus.present:
        return '✓';
      case AttendanceDayStatus.late:
        return 'L';
      case AttendanceDayStatus.halfDay:
        return '½';
      case AttendanceDayStatus.absent:
        return '✗';
      case AttendanceDayStatus.onLeave:
        return 'L';
      case AttendanceDayStatus.earlyCheckout:
        return 'E';
      case AttendanceDayStatus.outdoorDuty:
        return 'O';
    }
  }

  /// Get human-readable status text
  static String getStatusText(AttendanceDayStatus status) {
    switch (status) {
      case AttendanceDayStatus.present:
        return 'Present';
      case AttendanceDayStatus.late:
        return 'Late Arrival';
      case AttendanceDayStatus.halfDay:
        return 'Half Day';
      case AttendanceDayStatus.absent:
        return 'Absent';
      case AttendanceDayStatus.onLeave:
        return 'On Leave';
      case AttendanceDayStatus.earlyCheckout:
        return 'Early Checkout';
      case AttendanceDayStatus.outdoorDuty:
        return 'Outdoor Duty';
    }
  }

  /// Alias for getStatusText (for backward compatibility)
  static String getStatusName(AttendanceDayStatus status) {
    return getStatusText(status);
  }

  /// Calculate status from DateTime check-in time
  /// This is a convenience method that converts DateTime to Duration
  static AttendanceDayStatus calculateStatus({
    required DateTime checkInTime,
    required bool isAbsent,
    bool isLeave = false,
    bool isOutdoorDuty = false,
  }) {
    // Extract time of day from DateTime
    final timeOfDay = TimeOfDay.fromDateTime(checkInTime);
    final checkInDuration = Duration(
      hours: timeOfDay.hour,
      minutes: timeOfDay.minute,
    );

    return getAttendanceStatus(
      checkInTime: checkInDuration,
      isAbsent: isAbsent,
      isOnLeave: isLeave,
      isOutdoorDuty: isOutdoorDuty,
    );
  }
}
