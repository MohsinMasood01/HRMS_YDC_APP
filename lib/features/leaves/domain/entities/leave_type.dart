import 'package:equatable/equatable.dart';

/// Comprehensive leave type configuration
/// 
/// Handles special leave rules for:
/// - Paternity Leave (male only)
/// - Maternity Leave (female only)
/// - Compensatory Leave (requires 4+ hours overtime)
/// - Hajj Leave (Islamic calendar validation)
/// - Half-day leaves
class LeaveType extends Equatable {
  const LeaveType({
    required this.code,
    required this.name,
    required this.description,
    required this.maxDays,
    required this.isGenderSpecific,
    this.allowedGender,
    required this.requiresApproval,
    required this.isPaid,
    required this.allowHalfDay,
    required this.carryForward,
    this.carryForwardLimit,
    this.minOvertimeHoursRequired,
    this.seasonalRestriction,
    this.specialValidation,
  });

  /// Unique code (CL, EL, ML, PL, MAT, COMP, HAJJ, etc.)
  final String code;

  /// Display name
  final String name;

  /// Description of the leave type
  final String description;

  /// Maximum days allowed per year
  final int maxDays;

  /// Whether this leave is restricted by gender
  final bool isGenderSpecific;

  /// 'M' for male, 'F' for female, null for all
  final String? allowedGender;

  /// Whether manager approval is required
  final bool requiresApproval;

  /// Whether this is paid leave
  final bool isPaid;

  /// Whether half-day can be applied
  final bool allowHalfDay;

  /// Whether unused leaves carry forward
  final bool carryForward;

  /// Maximum days that can be carried forward
  final int? carryForwardLimit;

  /// Minimum overtime hours required (for compensatory leave)
  final int? minOvertimeHoursRequired;

  /// Season restriction (e.g., 'hajj' for Hajj leave)
  final String? seasonalRestriction;

  /// Special validation type
  final LeaveValidationType? specialValidation;

  /// Check if this leave type is available for a gender
  bool isAvailableForGender(String gender) {
    if (!isGenderSpecific) return true;
    return allowedGender?.toUpperCase() == gender.toUpperCase();
  }

  /// Standard leave types factory
  static List<LeaveType> get standardTypes => [
    // Casual Leave
    const LeaveType(
      code: 'CL',
      name: 'Casual Leave',
      description: 'For personal matters and short absences',
      maxDays: 12,
      isGenderSpecific: false,
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: true,
      carryForward: false,
    ),

    // Earned Leave / Annual Leave
    const LeaveType(
      code: 'EL',
      name: 'Earned Leave',
      description: 'Annual leave earned based on service',
      maxDays: 21,
      isGenderSpecific: false,
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: false,
      carryForward: true,
      carryForwardLimit: 30,
    ),

    // Medical Leave
    const LeaveType(
      code: 'ML',
      name: 'Medical Leave',
      description: 'For illness or medical procedures',
      maxDays: 10,
      isGenderSpecific: false,
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: false,
      carryForward: false,
    ),

    // Sick Leave
    const LeaveType(
      code: 'SL',
      name: 'Sick Leave',
      description: 'Short-term illness leave',
      maxDays: 15,
      isGenderSpecific: false,
      requiresApproval: false, // Usually auto-approved for short durations
      isPaid: true,
      allowHalfDay: true,
      carryForward: false,
    ),

    // Paternity Leave (Male Only)
    const LeaveType(
      code: 'PL',
      name: 'Paternity Leave',
      description: 'Leave for new fathers',
      maxDays: 7,
      isGenderSpecific: true,
      allowedGender: 'M',
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: false,
      carryForward: false,
      specialValidation: LeaveValidationType.paternity,
    ),

    // Maternity Leave (Female Only)
    const LeaveType(
      code: 'MAT',
      name: 'Maternity Leave',
      description: 'Leave for expecting mothers',
      maxDays: 90,
      isGenderSpecific: true,
      allowedGender: 'F',
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: false,
      carryForward: false,
      specialValidation: LeaveValidationType.maternity,
    ),

    // Compensatory Leave
    const LeaveType(
      code: 'COMP',
      name: 'Compensatory Leave',
      description: 'Leave earned from overtime work (min 4 hours)',
      maxDays: 10,
      isGenderSpecific: false,
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: true,
      carryForward: true,
      carryForwardLimit: 5,
      minOvertimeHoursRequired: 4,
      specialValidation: LeaveValidationType.compensatory,
    ),

    // Hajj Leave
    const LeaveType(
      code: 'HAJJ',
      name: 'Hajj Leave',
      description: 'Leave for performing Hajj pilgrimage',
      maxDays: 30,
      isGenderSpecific: false,
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: false,
      carryForward: false,
      seasonalRestriction: 'hajj',
      specialValidation: LeaveValidationType.hajj,
    ),

    // Loss of Pay
    const LeaveType(
      code: 'LWP',
      name: 'Leave Without Pay',
      description: 'Unpaid leave when all balances exhausted',
      maxDays: 365, // Unlimited but needs approval
      isGenderSpecific: false,
      requiresApproval: true,
      isPaid: false,
      allowHalfDay: false,
      carryForward: false,
    ),

    // Study Leave
    const LeaveType(
      code: 'STL',
      name: 'Study Leave',
      description: 'Leave for examinations or educational purposes',
      maxDays: 15,
      isGenderSpecific: false,
      requiresApproval: true,
      isPaid: true,
      allowHalfDay: true,
      carryForward: false,
    ),

    // Bereavement Leave
    const LeaveType(
      code: 'BRL',
      name: 'Bereavement Leave',
      description: 'Leave for death in immediate family',
      maxDays: 5,
      isGenderSpecific: false,
      requiresApproval: false,
      isPaid: true,
      allowHalfDay: false,
      carryForward: false,
    ),
  ];

  @override
  List<Object?> get props => [
        code,
        name,
        description,
        maxDays,
        isGenderSpecific,
        allowedGender,
        requiresApproval,
        isPaid,
        allowHalfDay,
        carryForward,
        carryForwardLimit,
        minOvertimeHoursRequired,
        seasonalRestriction,
        specialValidation,
      ];
}

/// Special validation types for leaves
enum LeaveValidationType {
  /// Requires proof of childbirth
  paternity,

  /// Requires medical certificate
  maternity,

  /// Requires overtime record validation
  compensatory,

  /// Requires Islamic calendar date validation
  hajj,
}

/// Leave application with enhanced fields
class EnhancedLeaveRequest extends Equatable {
  const EnhancedLeaveRequest({
    required this.id,
    required this.employeeId,
    required this.leaveTypeCode,
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.reason,
    required this.appliedOn,
    this.isHalfDay = false,
    this.halfDayType,
    this.numberOfDays = 1,
    this.approverComment,
    this.approvedBy,
    this.approvedOn,
    this.attachmentUrl,
    this.isConverted = false,
    this.convertedFrom,
  });

  final String id;
  final String employeeId;
  final String leaveTypeCode;
  final DateTime fromDate;
  final DateTime toDate;
  final LeaveRequestStatus status;
  final String reason;
  final DateTime appliedOn;
  final bool isHalfDay;
  final HalfDayType? halfDayType;
  final double numberOfDays;
  final String? approverComment;
  final String? approvedBy;
  final DateTime? approvedOn;
  final String? attachmentUrl;
  
  /// Whether this was converted from half-day to full-day
  final bool isConverted;
  
  /// Original request ID if converted
  final String? convertedFrom;

  @override
  List<Object?> get props => [
        id,
        employeeId,
        leaveTypeCode,
        fromDate,
        toDate,
        status,
        reason,
        appliedOn,
        isHalfDay,
        halfDayType,
        numberOfDays,
        approverComment,
        approvedBy,
        approvedOn,
        attachmentUrl,
        isConverted,
        convertedFrom,
      ];
}

/// Leave request status
enum LeaveRequestStatus {
  draft,
  pending,
  approved,
  rejected,
  cancelled,
  converted,
}

/// Half-day types
enum HalfDayType {
  firstHalf,
  secondHalf,
}

/// Overtime record for compensatory leave validation
class OvertimeRecord extends Equatable {
  const OvertimeRecord({
    required this.date,
    required this.hoursWorked,
    required this.isApproved,
    this.compensatoryLeaveEarned = false,
  });

  final DateTime date;
  final double hoursWorked;
  final bool isApproved;
  final bool compensatoryLeaveEarned;

  /// Check if this overtime qualifies for compensatory leave
  bool get qualifiesForCompLeave => hoursWorked >= 4.0 && isApproved;

  @override
  List<Object?> get props => [date, hoursWorked, isApproved, compensatoryLeaveEarned];
}

