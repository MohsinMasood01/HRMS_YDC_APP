part of 'attendance_bloc.dart';

enum AttendanceStatus { initial, loading, success, failure }

class AttendanceState extends Equatable {
  const AttendanceState({
    this.status = AttendanceStatus.initial,
    this.records = const [],
    this.errorMessage,
    this.fromDate,
    this.toDate,
  });

  final AttendanceStatus status;
  final List<AttendanceRecord> records;
  final String? errorMessage;
  final DateTime? fromDate;
  final DateTime? toDate;

  AttendanceState copyWith({
    AttendanceStatus? status,
    List<AttendanceRecord>? records,
    String? errorMessage,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      records: records ?? this.records,
      errorMessage: errorMessage,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  @override
  List<Object?> get props => [status, records, errorMessage, fromDate, toDate];
}
