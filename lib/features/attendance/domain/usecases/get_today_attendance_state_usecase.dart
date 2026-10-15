import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

/// Today's attendance as the SERVER sees it.
///
/// The phone's local record is a mirror, not the truth: it goes stale when a
/// punch is made from another device, when HR corrects a day, or simply after
/// a reinstall. Showing the server's view on screen open is what stops
/// employees re-tapping because they cannot tell whether the earlier tap
/// worked — and a second tap is exactly what the server turns into a
/// check-out after an hour.
class TodayAttendanceState {
  const TodayAttendanceState({
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    this.checkInTime,
    this.checkOutTime,
  });

  final bool hasCheckedIn;
  final bool hasCheckedOut;

  /// `HH:mm`, as recorded by the server. Null when not punched.
  final String? checkInTime;
  final String? checkOutTime;

  static const TodayAttendanceState unknown = TodayAttendanceState(
    hasCheckedIn: false,
    hasCheckedOut: false,
  );
}

class GetTodayAttendanceStateUseCase {
  GetTodayAttendanceStateUseCase(this._repository);

  final AttendanceRepository _repository;

  /// Returns null when the server could not be reached, so the caller keeps
  /// showing what it already had instead of wrongly clearing it to "not
  /// marked yet".
  Future<TodayAttendanceState?> call() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      final records = await _repository.fetchAttendance(today, today);
      final record = _todayRecord(records, today);
      if (record == null) return TodayAttendanceState.unknown;

      final inTime = record.timeIn;
      final outTime = record.timeOut;
      return TodayAttendanceState(
        hasCheckedIn: inTime > Duration.zero,
        hasCheckedOut: outTime > Duration.zero,
        checkInTime: inTime > Duration.zero ? _hhmm(inTime) : null,
        checkOutTime: outTime > Duration.zero ? _hhmm(outTime) : null,
      );
    } catch (_) {
      return null;
    }
  }

  static AttendanceRecord? _todayRecord(
    List<AttendanceRecord> records,
    DateTime today,
  ) {
    for (final record in records) {
      final date = record.date;
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        return record;
      }
    }
    return null;
  }

  static String _hhmm(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}
