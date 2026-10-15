part of 'leave_application_bloc.dart';

enum LeaveApplicationStatus { idle, submitting, success, failure }

class LeaveApplicationState extends Equatable {
  const LeaveApplicationState({
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.halfDay,
    this.halfDaySession,
    this.status = LeaveApplicationStatus.idle,
    this.errorMessage,
  });

  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final bool halfDay;
  final HalfDaySession? halfDaySession;
  final LeaveApplicationStatus status;
  final String? errorMessage;

  factory LeaveApplicationState.initial() {
    final now = DateTime.now();
    return LeaveApplicationState(
      leaveType: 'CL',
      fromDate: now,
      toDate: now,
      reason: '',
      halfDay: false,
      halfDaySession: null,
    );
  }

  LeaveApplicationState copyWith({
    String? leaveType,
    DateTime? fromDate,
    DateTime? toDate,
    String? reason,
    bool? halfDay,
    HalfDaySession? halfDaySession,
    bool clearHalfDaySession = false,
    LeaveApplicationStatus? status,
    String? errorMessage,
  }) {
    return LeaveApplicationState(
      leaveType: leaveType ?? this.leaveType,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      reason: reason ?? this.reason,
      halfDay: halfDay ?? this.halfDay,
      halfDaySession:
          clearHalfDaySession ? null : (halfDaySession ?? this.halfDaySession),
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [leaveType, fromDate, toDate, reason, halfDay, halfDaySession, status, errorMessage];
}

