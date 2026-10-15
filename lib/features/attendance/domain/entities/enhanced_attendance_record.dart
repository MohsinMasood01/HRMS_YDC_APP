import 'package:equatable/equatable.dart';

import '../../../attendance/domain/entities/location_info.dart';

/// Enhanced attendance record with location and status tracking
class EnhancedAttendanceRecord extends Equatable {
  const EnhancedAttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.shiftName,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.workHours,
    this.overtimeHours,
    this.lateMinutes,
    this.earlyLeaveMinutes,
    this.remarks,
    this.approvedBy,
    this.isHalfDay = false,
    this.halfDayType,
    this.biometricType,
  });

  final String id;
  final String employeeId;
  final DateTime date;
  final AttendanceStatus status;
  
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  
  /// Location where check-in was done
  final LocationInfo? checkInLocation;
  
  /// Location where check-out was done
  final LocationInfo? checkOutLocation;
  
  final String? shiftName;
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;
  
  /// Total hours worked
  final Duration? workHours;
  
  /// Overtime hours (beyond scheduled)
  final Duration? overtimeHours;
  
  /// Minutes late for check-in
  final int? lateMinutes;
  
  /// Minutes left early before scheduled end
  final int? earlyLeaveMinutes;
  
  final String? remarks;
  final String? approvedBy;
  
  final bool isHalfDay;
  final String? halfDayType; // 'first_half' or 'second_half'
  
  /// Type of biometric used (fingerprint/face)
  final String? biometricType;

  /// Whether this is a late check-in
  bool get isLate => (lateMinutes ?? 0) > 0;

  /// Whether this is an early leave
  bool get isEarlyLeave => (earlyLeaveMinutes ?? 0) > 0;

  /// Get formatted work hours
  String get formattedWorkHours {
    if (workHours == null) return '--:--';
    final hours = workHours!.inHours;
    final minutes = workHours!.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Get formatted check-in time
  String get formattedCheckIn {
    if (checkInTime == null) return '--:--';
    return '${checkInTime!.hour.toString().padLeft(2, '0')}:${checkInTime!.minute.toString().padLeft(2, '0')}';
  }

  /// Get formatted check-out time
  String get formattedCheckOut {
    if (checkOutTime == null) return '--:--';
    return '${checkOutTime!.hour.toString().padLeft(2, '0')}:${checkOutTime!.minute.toString().padLeft(2, '0')}';
  }

  /// Get check-in location description
  String get checkInLocationText {
    if (checkInLocation == null) return 'Unknown';
    return checkInLocation!.nearestLandmark ?? checkInLocation!.shortDescription;
  }

  /// Get check-out location description
  String get checkOutLocationText {
    if (checkOutLocation == null) return 'Unknown';
    return checkOutLocation!.nearestLandmark ?? checkOutLocation!.shortDescription;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date.toIso8601String(),
      'status': status.name,
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'check_in_location': checkInLocation?.toJson(),
      'check_out_location': checkOutLocation?.toJson(),
      'shift_name': shiftName,
      'scheduled_start_time': scheduledStartTime?.toIso8601String(),
      'scheduled_end_time': scheduledEndTime?.toIso8601String(),
      'work_hours_minutes': workHours?.inMinutes,
      'overtime_hours_minutes': overtimeHours?.inMinutes,
      'late_minutes': lateMinutes,
      'early_leave_minutes': earlyLeaveMinutes,
      'remarks': remarks,
      'approved_by': approvedBy,
      'is_half_day': isHalfDay,
      'half_day_type': halfDayType,
      'biometric_type': biometricType,
    };
  }

  factory EnhancedAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return EnhancedAttendanceRecord(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: AttendanceStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => AttendanceStatus.absent,
      ),
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'] as String)
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      checkInLocation: json['check_in_location'] != null
          ? LocationInfo.fromJson(json['check_in_location'] as Map<String, dynamic>)
          : null,
      checkOutLocation: json['check_out_location'] != null
          ? LocationInfo.fromJson(json['check_out_location'] as Map<String, dynamic>)
          : null,
      shiftName: json['shift_name'] as String?,
      scheduledStartTime: json['scheduled_start_time'] != null
          ? DateTime.parse(json['scheduled_start_time'] as String)
          : null,
      scheduledEndTime: json['scheduled_end_time'] != null
          ? DateTime.parse(json['scheduled_end_time'] as String)
          : null,
      workHours: json['work_hours_minutes'] != null
          ? Duration(minutes: json['work_hours_minutes'] as int)
          : null,
      overtimeHours: json['overtime_hours_minutes'] != null
          ? Duration(minutes: json['overtime_hours_minutes'] as int)
          : null,
      lateMinutes: json['late_minutes'] as int?,
      earlyLeaveMinutes: json['early_leave_minutes'] as int?,
      remarks: json['remarks'] as String?,
      approvedBy: json['approved_by'] as String?,
      isHalfDay: json['is_half_day'] as bool? ?? false,
      halfDayType: json['half_day_type'] as String?,
      biometricType: json['biometric_type'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        employeeId,
        date,
        status,
        checkInTime,
        checkOutTime,
        checkInLocation,
        checkOutLocation,
        shiftName,
        scheduledStartTime,
        scheduledEndTime,
        workHours,
        overtimeHours,
        lateMinutes,
        earlyLeaveMinutes,
        remarks,
        approvedBy,
        isHalfDay,
        halfDayType,
        biometricType,
      ];
}

/// Attendance status types
enum AttendanceStatus {
  present,
  absent,
  halfDay,
  late,
  earlyCheckout,
  onDuty,        // OD - Outdoor Duty
  leave,
  holiday,
  weeklyOff,
  compensatoryOff,
}

extension AttendanceStatusExtension on AttendanceStatus {
  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.earlyCheckout:
        return 'Early Checkout';
      case AttendanceStatus.onDuty:
        return 'On Duty (OD)';
      case AttendanceStatus.leave:
        return 'On Leave';
      case AttendanceStatus.holiday:
        return 'Holiday';
      case AttendanceStatus.weeklyOff:
        return 'Weekly Off';
      case AttendanceStatus.compensatoryOff:
        return 'Comp Off';
    }
  }

  String get code {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.halfDay:
        return 'HD';
      case AttendanceStatus.late:
        return 'L';
      case AttendanceStatus.earlyCheckout:
        return 'EC';
      case AttendanceStatus.onDuty:
        return 'OD';
      case AttendanceStatus.leave:
        return 'LV';
      case AttendanceStatus.holiday:
        return 'H';
      case AttendanceStatus.weeklyOff:
        return 'WO';
      case AttendanceStatus.compensatoryOff:
        return 'CO';
    }
  }

  /// Whether this status counts as present for attendance calculation
  bool get countsAsPresent {
    return this == AttendanceStatus.present ||
           this == AttendanceStatus.late ||
           this == AttendanceStatus.earlyCheckout ||
           this == AttendanceStatus.onDuty;
  }

  /// Whether this status should NOT be counted in leave balance
  /// OD should not be counted
  bool get excludeFromLeaveBalance {
    return this == AttendanceStatus.onDuty;
  }
}

/// Filter options for attendance list
class AttendanceFilter {
  const AttendanceFilter({
    this.fromDate,
    this.toDate,
    this.statuses,
    this.sortOrder = SortOrder.descending,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final List<AttendanceStatus>? statuses;
  final SortOrder sortOrder;

  AttendanceFilter copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    List<AttendanceStatus>? statuses,
    SortOrder? sortOrder,
  }) {
    return AttendanceFilter(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      statuses: statuses ?? this.statuses,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

enum SortOrder { ascending, descending }

/// Attendance summary statistics
class AttendanceSummaryStats {
  const AttendanceSummaryStats({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.halfDays,
    required this.lateDays,
    required this.earlyCheckouts,
    required this.onDutyDays,
    required this.leaveDays,
    required this.holidays,
    required this.weeklyOffs,
  });

  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int halfDays;
  final int lateDays;
  final int earlyCheckouts;
  final int onDutyDays;   // Should NOT be counted in leave balances
  final int leaveDays;
  final int holidays;
  final int weeklyOffs;

  /// Calculate attendance percentage (excluding holidays and weekly offs)
  double get attendancePercentage {
    final workingDays = totalDays - holidays - weeklyOffs;
    if (workingDays == 0) return 0;
    
    // Present + Half days (as 0.5) + On Duty + Late (still present)
    final attended = presentDays + (halfDays * 0.5) + onDutyDays + lateDays;
    return (attended / workingDays) * 100;
  }

  factory AttendanceSummaryStats.fromRecords(
    List<EnhancedAttendanceRecord> records,
  ) {
    return AttendanceSummaryStats(
      totalDays: records.length,
      presentDays: records.where((r) => r.status == AttendanceStatus.present).length,
      absentDays: records.where((r) => r.status == AttendanceStatus.absent).length,
      halfDays: records.where((r) => r.status == AttendanceStatus.halfDay).length,
      lateDays: records.where((r) => r.status == AttendanceStatus.late).length,
      earlyCheckouts: records.where((r) => r.status == AttendanceStatus.earlyCheckout).length,
      onDutyDays: records.where((r) => r.status == AttendanceStatus.onDuty).length,
      leaveDays: records.where((r) => r.status == AttendanceStatus.leave).length,
      holidays: records.where((r) => r.status == AttendanceStatus.holiday).length,
      weeklyOffs: records.where((r) => r.status == AttendanceStatus.weeklyOff).length,
    );
  }
}

