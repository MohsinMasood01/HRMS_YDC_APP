part of 'leave_status_bloc.dart';

abstract class LeaveStatusEvent extends Equatable {
  const LeaveStatusEvent();

  @override
  List<Object?> get props => [];
}

class LeaveStatusRequested extends LeaveStatusEvent {
  const LeaveStatusRequested();
}

