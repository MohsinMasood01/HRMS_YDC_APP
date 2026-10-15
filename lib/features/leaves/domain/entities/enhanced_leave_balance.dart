import 'package:equatable/equatable.dart';

import 'leave_type.dart';

/// Enhanced leave balance with proper calculations
/// 
/// Key Features:
/// - Excludes OD (On Duty) from leave balance
/// - Tracks available, used, and pending leaves
/// - Handles carry forward
/// - Gender-specific leave filtering
class EnhancedLeaveBalance extends Equatable {
  const EnhancedLeaveBalance({
    required this.leaveType,
    required this.totalEntitled,
    required this.used,
    required this.pending,
    required this.carriedForward,
    this.lapsedFromLastYear = 0,
  });

  /// The leave type configuration
  final LeaveType leaveType;

  /// Total days entitled for the year
  final double totalEntitled;

  /// Days already used
  final double used;

  /// Days in pending requests
  final double pending;

  /// Days carried forward from last year
  final double carriedForward;

  /// Days lapsed from last year (not carried forward)
  final double lapsedFromLastYear;

  /// Available balance (entitled + carried - used - pending)
  double get available => totalEntitled + carriedForward - used - pending;

  /// Total balance including carried forward
  double get totalBalance => totalEntitled + carriedForward;

  /// Percentage used
  double get usedPercentage {
    if (totalBalance == 0) return 0;
    return (used / totalBalance) * 100;
  }

  /// Convenience getters
  String get code => leaveType.code;
  String get name => leaveType.name;

  /// Check if this leave can be applied
  bool canApply(double days) => available >= days;

  /// Create from JSON
  factory EnhancedLeaveBalance.fromJson(
    Map<String, dynamic> json,
    LeaveType leaveType,
  ) {
    return EnhancedLeaveBalance(
      leaveType: leaveType,
      totalEntitled: (json['total_entitled'] as num?)?.toDouble() ?? 0,
      used: (json['used'] as num?)?.toDouble() ?? 0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0,
      carriedForward: (json['carried_forward'] as num?)?.toDouble() ?? 0,
      lapsedFromLastYear: (json['lapsed'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'leave_type_code': leaveType.code,
        'total_entitled': totalEntitled,
        'used': used,
        'pending': pending,
        'carried_forward': carriedForward,
        'lapsed': lapsedFromLastYear,
        'available': available,
      };

  @override
  List<Object?> get props => [
        leaveType,
        totalEntitled,
        used,
        pending,
        carriedForward,
        lapsedFromLastYear,
      ];
}

/// Leave balance summary for employee
class LeaveBalanceSummary extends Equatable {
  const LeaveBalanceSummary({
    required this.employeeId,
    required this.year,
    required this.balances,
    required this.employeeGender,
  });

  final String employeeId;
  final int year;
  final List<EnhancedLeaveBalance> balances;
  final String employeeGender;

  /// Get balances filtered by gender
  /// This removes gender-specific leaves that don't apply to the employee
  List<EnhancedLeaveBalance> get applicableBalances {
    return balances.where((balance) {
      return balance.leaveType.isAvailableForGender(employeeGender);
    }).toList();
  }

  /// Get balance for a specific leave type
  EnhancedLeaveBalance? getBalance(String leaveTypeCode) {
    try {
      return balances.firstWhere((b) => b.code == leaveTypeCode);
    } catch (_) {
      return null;
    }
  }

  /// Total available leaves (excluding OD and restricted types)
  double get totalAvailable {
    return applicableBalances
        .where((b) => !b.leaveType.code.contains('OD')) // Exclude OD
        .fold(0.0, (sum, b) => sum + b.available);
  }

  /// Total used leaves
  double get totalUsed {
    return applicableBalances
        .where((b) => !b.leaveType.code.contains('OD'))
        .fold(0.0, (sum, b) => sum + b.used);
  }

  @override
  List<Object?> get props => [employeeId, year, balances, employeeGender];
}

/// Helper to calculate leave balances correctly
class LeaveBalanceCalculator {
  /// Calculate the correct balance excluding OD
  static EnhancedLeaveBalance calculateBalance({
    required LeaveType leaveType,
    required double entitled,
    required List<EnhancedLeaveRequest> requests,
    double carriedForward = 0,
  }) {
    // Filter requests for this leave type
    final typeRequests = requests.where(
      (r) => r.leaveTypeCode == leaveType.code,
    );

    // Calculate used (approved only)
    final used = typeRequests
        .where((r) => r.status == LeaveRequestStatus.approved)
        .fold(0.0, (sum, r) => sum + r.numberOfDays);

    // Calculate pending
    final pending = typeRequests
        .where((r) => r.status == LeaveRequestStatus.pending)
        .fold(0.0, (sum, r) => sum + r.numberOfDays);

    return EnhancedLeaveBalance(
      leaveType: leaveType,
      totalEntitled: entitled,
      used: used,
      pending: pending,
      carriedForward: carriedForward,
    );
  }

  /// Calculate balances from attendance records
  /// IMPORTANT: OD (On Duty) should NOT affect leave balance
  static Map<String, int> calculateFromAttendance(
    List<dynamic> attendanceRecords,
  ) {
    int absentDays = 0;
    int lateDays = 0;
    int halfDays = 0;
    int presentDays = 0;
    int odDays = 0; // Track OD separately, don't mix with leaves

    for (final record in attendanceRecords) {
      // Assuming record has a 'status' field
      final status = record.status;
      
      if (status == 'present' || status == 'P') {
        presentDays++;
      } else if (status == 'absent' || status == 'A') {
        absentDays++;
      } else if (status == 'late' || status == 'L') {
        lateDays++;
      } else if (status == 'half_day' || status == 'HD') {
        halfDays++;
      } else if (status == 'on_duty' || status == 'OD') {
        odDays++;
        // OD does NOT reduce leave balance
        // OD is counted as present for attendance but NOT as a leave type
      }
    }

    return {
      'present': presentDays,
      'absent': absentDays,
      'late': lateDays,
      'half_day': halfDays,
      'on_duty': odDays, // Tracked but NOT mixed with leaves
    };
  }
}

/// Leave statistics for dashboard
class LeaveStatistics extends Equatable {
  const LeaveStatistics({
    required this.totalEntitled,
    required this.totalUsed,
    required this.totalPending,
    required this.totalAvailable,
    required this.casualLeaveBalance,
    required this.earnedLeaveBalance,
    required this.sickLeaveBalance,
    this.medicalLeaveBalance,
    this.specialLeaveBalance,
  });

  final double totalEntitled;
  final double totalUsed;
  final double totalPending;
  final double totalAvailable;
  final double casualLeaveBalance;
  final double earnedLeaveBalance;
  final double sickLeaveBalance;
  final double? medicalLeaveBalance;
  final double? specialLeaveBalance;

  factory LeaveStatistics.fromBalances(List<EnhancedLeaveBalance> balances) {
    double totalEntitled = 0;
    double totalUsed = 0;
    double totalPending = 0;
    double cl = 0, el = 0, sl = 0, ml = 0;

    for (final balance in balances) {
      // Skip OD - it's not a leave type
      if (balance.code == 'OD') continue;

      totalEntitled += balance.totalEntitled;
      totalUsed += balance.used;
      totalPending += balance.pending;

      switch (balance.code) {
        case 'CL':
          cl = balance.available;
          break;
        case 'EL':
          el = balance.available;
          break;
        case 'SL':
          sl = balance.available;
          break;
        case 'ML':
          ml = balance.available;
          break;
      }
    }

    return LeaveStatistics(
      totalEntitled: totalEntitled,
      totalUsed: totalUsed,
      totalPending: totalPending,
      totalAvailable: totalEntitled - totalUsed - totalPending,
      casualLeaveBalance: cl,
      earnedLeaveBalance: el,
      sickLeaveBalance: sl,
      medicalLeaveBalance: ml > 0 ? ml : null,
    );
  }

  @override
  List<Object?> get props => [
        totalEntitled,
        totalUsed,
        totalPending,
        totalAvailable,
        casualLeaveBalance,
        earnedLeaveBalance,
        sickLeaveBalance,
        medicalLeaveBalance,
        specialLeaveBalance,
      ];
}

