part of 'leave_application_bloc.dart';

abstract class LeaveApplicationEvent extends Equatable {
  const LeaveApplicationEvent();

  @override
  List<Object?> get props => [];
}

class LeaveTypeChanged extends LeaveApplicationEvent {
  const LeaveTypeChanged(this.leaveType);

  final String leaveType;

  @override
  List<Object?> get props => [leaveType];
}

class LeaveDatesChanged extends LeaveApplicationEvent {
  const LeaveDatesChanged(this.from, this.to);

  final DateTime from;
  final DateTime to;

  @override
  List<Object?> get props => [from, to];
}

class LeaveReasonChanged extends LeaveApplicationEvent {
  const LeaveReasonChanged(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

class LeaveHalfDayToggled extends LeaveApplicationEvent {
  const LeaveHalfDayToggled(this.halfDay);

  final bool halfDay;

  @override
  List<Object?> get props => [halfDay];
}

class LeaveHalfDaySessionChanged extends LeaveApplicationEvent {
  const LeaveHalfDaySessionChanged(this.session);

  final HalfDaySession session;

  @override
  List<Object?> get props => [session];
}

class LeaveSubmitted extends LeaveApplicationEvent {
  const LeaveSubmitted();
}

