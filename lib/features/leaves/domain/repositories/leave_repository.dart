import '../entities/leave_balance.dart';
import '../entities/leave_request.dart';

abstract class LeaveRepository {
  Future<List<LeaveBalance>> fetchBalances();
  Future<List<LeaveRequest>> fetchRequests();
  Future<void> submitRequest(LeaveRequest request);
  List<LeaveBalance>? cachedBalances();
  List<LeaveRequest>? cachedRequests();
}
