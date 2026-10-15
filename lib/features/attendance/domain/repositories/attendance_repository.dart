import '../entities/attendance_record.dart';
import '../entities/attendance_summary.dart';
import '../entities/biometric_attendance.dart';

abstract class AttendanceRepository {
  Future<BiometricAttendanceResponse> markBiometricAttendance(
    BiometricAttendanceRequest request,
  );

  Future<List<AttendanceRecord>> fetchAttendance(DateTime from, DateTime to);

  List<AttendanceRecord>? cachedAttendance();

  Future<AttendanceSummary> fetchSummary(DateTime from, DateTime to);

  AttendanceSummary? cachedSummary();
}






