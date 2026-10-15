import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class GetAttendanceReportUseCase {
  GetAttendanceReportUseCase(this._repository);

  final AttendanceRepository _repository;

  Future<List<AttendanceRecord>> call(DateTime from, DateTime to) {
    return _repository.fetchAttendance(from, to);
  }

  List<AttendanceRecord>? cached() => _repository.cachedAttendance();
}
