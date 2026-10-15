import 'package:equatable/equatable.dart';

enum LeaveStatus { pending, approved, rejected }

/// Which half of the working day a half-day leave covers. HRMS works in
/// sessions, not arbitrary clock times, so the user picks one of these.
enum HalfDaySession { firstHalf, secondHalf }

extension HalfDaySessionX on HalfDaySession {
  /// Wire value sent to / received from the backend.
  String get apiValue =>
      this == HalfDaySession.firstHalf ? 'first_half' : 'second_half';

  String get label =>
      this == HalfDaySession.firstHalf ? 'First Half' : 'Second Half';

  static HalfDaySession? fromApi(String? value) {
    switch (value?.toLowerCase().trim().replaceAll('-', '_').replaceAll(' ', '_')) {
      case 'first_half':
      case 'firsthalf':
      case '1':
      case 'fh':
        return HalfDaySession.firstHalf;
      case 'second_half':
      case 'secondhalf':
      case '2':
      case 'sh':
        return HalfDaySession.secondHalf;
      default:
        return null;
    }
  }
}

class LeaveRequest extends Equatable {
  const LeaveRequest({
    required this.id,
    required this.type,
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.reason,
    this.halfDay = false,
    this.halfDaySession,
    this.approverComment,
  });

  final String id;
  final String type;
  final DateTime fromDate;
  final DateTime toDate;
  final LeaveStatus status;
  final String reason;
  final bool halfDay;

  /// Only meaningful when [halfDay] is true.
  final HalfDaySession? halfDaySession;
  final String? approverComment;

  @override
  List<Object?> get props => [
        id,
        type,
        fromDate,
        toDate,
        status,
        reason,
        halfDay,
        halfDaySession,
        approverComment,
      ];
}
