import 'package:equatable/equatable.dart';

class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.date,
    required this.shift,
    required this.day,
    required this.timeIn,
    required this.timeOut,
    required this.workHours,
    required this.lateArrival,
    required this.approvedHours,
    required this.remarks,
    required this.isAbsent,
  });

  final DateTime date;
  final String shift;
  final int day;
  final Duration timeIn;
  final Duration timeOut;
  final Duration workHours;
  final Duration lateArrival;
  final Duration approvedHours;
  final String remarks;
  final bool isAbsent;

  bool get isLate => lateArrival > Duration.zero;

  @override
  List<Object?> get props => [
        date,
        shift,
        day,
        timeIn,
        timeOut,
        workHours,
        lateArrival,
        approvedHours,
        remarks,
        isAbsent,
      ];
}

