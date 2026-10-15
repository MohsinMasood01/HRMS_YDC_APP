import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_summary.dart';
import '../../domain/entities/biometric_attendance.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_data_source.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl(this._remoteDataSource, this._empPkProvider);

  final AttendanceRemoteDataSource _remoteDataSource;
  final Future<String?> Function() _empPkProvider;
  List<AttendanceRecord>? _cachedRecords;
  AttendanceSummary? _cachedSummary;

  @override
  Future<BiometricAttendanceResponse> markBiometricAttendance(
    BiometricAttendanceRequest request,
  ) {
    return _remoteDataSource.markBiometricAttendance(request);
  }

  @override
  Future<List<AttendanceRecord>> fetchAttendance(
    DateTime from,
    DateTime to,
  ) async {
    final empPk = await _empPkProvider() ?? '';
    final records = await _remoteDataSource.getAttendanceHistory(
      empPk: empPk,
      fromDate: _fmt(from),
      toDate: _fmt(to),
    );
    _cachedRecords = records;
    return records;
  }

  @override
  List<AttendanceRecord>? cachedAttendance() => _cachedRecords;

  @override
  Future<AttendanceSummary> fetchSummary(DateTime from, DateTime to) async {
    final empPk = await _empPkProvider() ?? '';
    final summary = await _remoteDataSource.getAttendanceSummary(
      empPk: empPk,
      fromDate: _fmt(from),
      toDate: _fmt(to),
    );
    _cachedSummary = summary;
    return summary;
  }

  @override
  AttendanceSummary? cachedSummary() => _cachedSummary;

  String _fmt(DateTime value) => value.toIso8601String().split('T').first;
}






