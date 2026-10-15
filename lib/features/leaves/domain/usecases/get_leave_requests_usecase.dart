import '../entities/leave_request.dart';
import '../repositories/leave_repository.dart';

class GetLeaveRequestsUseCase {
  GetLeaveRequestsUseCase(this._repository);

  final LeaveRepository _repository;

  Future<List<LeaveRequest>> call() => _repository.fetchRequests();
  List<LeaveRequest>? cached() => _repository.cachedRequests();
}

