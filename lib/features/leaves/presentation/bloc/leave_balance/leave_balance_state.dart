part of 'leave_balance_bloc.dart';

enum LeaveBalanceStatus { initial, loading, success, failure }

class LeaveBalanceState extends Equatable {
  const LeaveBalanceState({
    this.status = LeaveBalanceStatus.initial,
    this.balances = const [],
    this.errorMessage,
  });

  final LeaveBalanceStatus status;
  final List<LeaveBalance> balances;
  final String? errorMessage;

  LeaveBalanceState copyWith({
    LeaveBalanceStatus? status,
    List<LeaveBalance>? balances,
    String? errorMessage,
  }) {
    return LeaveBalanceState(
      status: status ?? this.status,
      balances: balances ?? this.balances,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, balances, errorMessage];
}

