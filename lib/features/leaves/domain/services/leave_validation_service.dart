import '../../../../core/utils/islamic_calendar.dart';
import '../entities/leave_type.dart';

/// Service for validating leave applications
/// 
/// Handles special validation for:
/// - Paternity Leave (male only)
/// - Maternity Leave (female only)
/// - Compensatory Leave (min 4 hours overtime)
/// - Hajj Leave (Islamic calendar)
/// - Half-day rules
class LeaveValidationService {
  /// Validate a leave application
  LeaveValidationResult validateLeaveApplication({
    required LeaveType leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required String employeeGender,
    required double currentBalance,
    required bool isHalfDay,
    required HalfDayType? halfDayType,
    List<OvertimeRecord>? overtimeRecords,
    List<EnhancedLeaveRequest>? existingRequests,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // 1. Gender-specific validation
    if (leaveType.isGenderSpecific) {
      if (!leaveType.isAvailableForGender(employeeGender)) {
        final genderName = leaveType.allowedGender == 'M' ? 'male' : 'female';
        errors.add('${leaveType.name} is only available for $genderName employees');
      }
    }

    // 2. Balance check
    final requestedDays = _calculateDays(fromDate, toDate, isHalfDay);
    if (requestedDays > currentBalance) {
      errors.add(
        'Insufficient balance. You have $currentBalance days available '
        'but requested $requestedDays days',
      );
    }

    // 3. Half-day validation
    if (isHalfDay) {
      if (!leaveType.allowHalfDay) {
        errors.add('${leaveType.name} does not allow half-day applications');
      }
      
      if (halfDayType == null) {
        errors.add('Please specify first half or second half');
      }
      
      // Check for duplicate half-day on same date
      if (existingRequests != null) {
        final duplicateHalfDay = existingRequests.where((req) =>
            req.isHalfDay &&
            req.fromDate == fromDate &&
            req.status != LeaveRequestStatus.rejected &&
            req.status != LeaveRequestStatus.cancelled
        ).isNotEmpty;
        
        if (duplicateHalfDay) {
          errors.add('You already have a half-day leave applied for this date');
        }
      }
    }

    // 4. Special validation based on leave type
    switch (leaveType.specialValidation) {
      case LeaveValidationType.paternity:
        _validatePaternityLeave(leaveType, errors, warnings);
        break;
        
      case LeaveValidationType.maternity:
        _validateMaternityLeave(leaveType, fromDate, toDate, errors, warnings);
        break;
        
      case LeaveValidationType.compensatory:
        _validateCompensatoryLeave(
          leaveType, 
          overtimeRecords, 
          requestedDays,
          errors, 
          warnings,
        );
        break;
        
      case LeaveValidationType.hajj:
        _validateHajjLeave(fromDate, toDate, errors, warnings);
        break;
        
      case null:
        break;
    }

    // 5. Date validation
    if (fromDate.isAfter(toDate)) {
      errors.add('From date cannot be after To date');
    }

    if (fromDate.isBefore(DateTime.now().subtract(const Duration(days: 30)))) {
      errors.add('Cannot apply leave for dates more than 30 days in the past');
    }

    // 6. Overlapping leave check
    if (existingRequests != null) {
      final overlapping = _findOverlappingLeaves(
        fromDate, 
        toDate, 
        existingRequests,
      );
      if (overlapping.isNotEmpty) {
        errors.add('You have overlapping leave applications for these dates');
      }
    }

    return LeaveValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      calculatedDays: requestedDays,
    );
  }

  /// Validate half-day to full-day conversion
  LeaveValidationResult validateHalfDayConversion({
    required EnhancedLeaveRequest originalRequest,
    required double currentBalance,
    required List<EnhancedLeaveRequest>? existingRequests,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Must be a half-day request
    if (!originalRequest.isHalfDay) {
      errors.add('Only half-day leaves can be converted to full-day');
      return LeaveValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
        calculatedDays: 0,
      );
    }

    // Must be pending or approved
    if (originalRequest.status != LeaveRequestStatus.pending &&
        originalRequest.status != LeaveRequestStatus.approved) {
      errors.add('Only pending or approved leaves can be converted');
    }

    // Check if there's already another half-day on the same date
    if (existingRequests != null) {
      final otherHalfDay = existingRequests.where((req) =>
          req.id != originalRequest.id &&
          req.isHalfDay &&
          req.fromDate == originalRequest.fromDate &&
          req.status != LeaveRequestStatus.rejected &&
          req.status != LeaveRequestStatus.cancelled
      ).isNotEmpty;
      
      if (otherHalfDay) {
        errors.add(
          'Another half-day leave exists for this date. '
          'Please cancel it first or apply a different leave.',
        );
      }
    }

    // Check balance for additional 0.5 days
    if (currentBalance < 0.5) {
      errors.add('Insufficient balance for conversion. Need 0.5 additional days.');
    }

    return LeaveValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      calculatedDays: 0.5, // Additional days needed
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE VALIDATION METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _validatePaternityLeave(
    LeaveType leaveType,
    List<String> errors,
    List<String> warnings,
  ) {
    warnings.add(
      'Paternity leave requires proof of childbirth. '
      'Please submit required documents.',
    );
  }

  void _validateMaternityLeave(
    LeaveType leaveType,
    DateTime fromDate,
    DateTime toDate,
    List<String> errors,
    List<String> warnings,
  ) {
    final days = toDate.difference(fromDate).inDays + 1;
    
    if (days < 30) {
      warnings.add(
        'Maternity leave is typically taken for longer periods. '
        'You can extend it later if needed.',
      );
    }
    
    warnings.add(
      'Maternity leave requires medical documentation. '
      'Please submit required certificates.',
    );
  }

  void _validateCompensatoryLeave(
    LeaveType leaveType,
    List<OvertimeRecord>? overtimeRecords,
    double requestedDays,
    List<String> errors,
    List<String> warnings,
  ) {
    if (overtimeRecords == null || overtimeRecords.isEmpty) {
      errors.add(
        'Compensatory leave requires approved overtime records. '
        'No overtime records found.',
      );
      return;
    }

    // Calculate available comp off days
    final eligibleOvertime = overtimeRecords.where(
      (record) => record.qualifiesForCompLeave && !record.compensatoryLeaveEarned,
    ).toList();

    if (eligibleOvertime.isEmpty) {
      errors.add(
        'No eligible overtime records found. '
        'Minimum 4 hours of approved overtime required per comp off day.',
      );
      return;
    }

    final availableCompDays = eligibleOvertime.length.toDouble();
    if (requestedDays > availableCompDays) {
      errors.add(
        'You have only $availableCompDays compensatory days available '
        'but requested $requestedDays days.',
      );
    }

    warnings.add(
      'Compensatory leave will be deducted from your overtime balance.',
    );
  }

  void _validateHajjLeave(
    DateTime fromDate,
    DateTime toDate,
    List<String> errors,
    List<String> warnings,
  ) {
    final validation = IslamicCalendar.validateHajjLeave(fromDate, toDate);
    
    if (!validation.isValid) {
      errors.add(validation.message);
    } else {
      warnings.add(
        'Leave dates: ${validation.fromHijri} to ${validation.toHijri}\n'
        'Please ensure you have made Hajj arrangements.',
      );
    }
    
    // Get Hajj season info
    final hajjSeason = IslamicCalendar.getHajjSeasonForYear(fromDate.year);
    warnings.add(
      'Hajj season this year is approximately from '
      '${_formatDate(hajjSeason.startDate)} to ${_formatDate(hajjSeason.endDate)}',
    );
  }

  double _calculateDays(DateTime from, DateTime to, bool isHalfDay) {
    if (isHalfDay) return 0.5;
    
    int totalDays = 0;
    DateTime current = from;
    
    while (!current.isAfter(to)) {
      // Skip weekends (Saturday = 6, Sunday = 7)
      if (current.weekday != DateTime.saturday && 
          current.weekday != DateTime.sunday) {
        totalDays++;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return totalDays.toDouble();
  }

  List<EnhancedLeaveRequest> _findOverlappingLeaves(
    DateTime from,
    DateTime to,
    List<EnhancedLeaveRequest> existingRequests,
  ) {
    return existingRequests.where((request) {
      if (request.status == LeaveRequestStatus.rejected ||
          request.status == LeaveRequestStatus.cancelled) {
        return false;
      }
      
      // Check if date ranges overlap
      return !(to.isBefore(request.fromDate) || from.isAfter(request.toDate));
    }).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Result of leave validation
class LeaveValidationResult {
  const LeaveValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.calculatedDays,
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final double calculatedDays;

  /// Whether there are any warnings
  bool get hasWarnings => warnings.isNotEmpty;
}

