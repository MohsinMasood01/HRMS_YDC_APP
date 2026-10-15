import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/attendance_record.dart';
import '../../domain/usecases/get_attendance_report_usecase.dart';
import '../../../../core/errors/error_messages.dart';

part 'attendance_event.dart';
part 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  AttendanceBloc(this._getAttendanceReportUseCase)
    : super(const AttendanceState()) {
    on<AttendanceRequested>(_onRequested);
  }

  final GetAttendanceReportUseCase _getAttendanceReportUseCase;

  Future<void> _onRequested(
    AttendanceRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    final now = DateTime.now();
    final start = event.from ?? DateTime(now.year, now.month, 1);
    final end = event.to ?? DateTime(now.year, now.month + 1, 0);

    emit(state.copyWith(
      status: AttendanceStatus.loading,
      errorMessage: null,
      fromDate: start,
      toDate: end,
    ));
    try {
      final records = await _getAttendanceReportUseCase(start, end);
      emit(state.copyWith(
        status: AttendanceStatus.success,
        records: records,
        fromDate: start,
        toDate: end,
      ));
    } catch (e) {
      emit(
        state.copyWith(
          status: AttendanceStatus.failure,
          errorMessage: ErrorMessages.from(
            e,
            fallback: 'Could not load your attendance. Please try again.',
          ),
        ),
      );
    }
  }
}
