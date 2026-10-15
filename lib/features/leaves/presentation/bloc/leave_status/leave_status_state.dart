part of 'leave_status_bloc.dart';

enum LeaveStatusEnum { initial, loading, success, failure }

class LeaveStatusState extends Equatable {
  const LeaveStatusState({
    this.status = LeaveStatusEnum.initial,
    this.requests = const [],
    this.errorMessage,
  });

  final LeaveStatusEnum status;
  final List<LeaveRequest> requests;
  final String? errorMessage;

  LeaveStatusState copyWith({
    LeaveStatusEnum? status,
    List<LeaveRequest>? requests,
    String? errorMessage,
  }) {
    return LeaveStatusState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, requests, errorMessage];
}

