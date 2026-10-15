import '../entities/leave_balance.dart';
import '../repositories/leave_repository.dart';

class GetLeaveBalancesUseCase {
  GetLeaveBalancesUseCase(this._repository);

  final LeaveRepository _repository;

  Future<List<LeaveBalance>> call() => _repository.fetchBalances();
  List<LeaveBalance>? cached() => _repository.cachedBalances();
}

