import '../entities/attendance_summary.dart';
import '../repositories/attendance_repository.dart';

class GetAttendanceSummaryUseCase {
  GetAttendanceSummaryUseCase(this._repository);

  final AttendanceRepository _repository;

  Future<AttendanceSummary> call(DateTime from, DateTime to) {
    return _repository.fetchSummary(from, to);
  }

  AttendanceSummary? cached() => _repository.cachedSummary();
}

