part of 'leave_balance_bloc.dart';

abstract class LeaveBalanceEvent extends Equatable {
  const LeaveBalanceEvent();

  @override
  List<Object?> get props => [];
}

class LeaveBalanceRequested extends LeaveBalanceEvent {
  const LeaveBalanceRequested();
}

