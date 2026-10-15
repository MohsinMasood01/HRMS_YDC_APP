import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/leave_request.dart';
import '../../../domain/usecases/get_leave_balances_usecase.dart';
import '../../../domain/usecases/submit_leave_request_usecase.dart';
import '../../../../../core/errors/error_messages.dart';

part 'leave_application_event.dart';
part 'leave_application_state.dart';

/// Auto-generated reason suggestions, keyed by leave-type code. These are shown
/// as the Reason field's placeholder for the selected type and are submitted
/// verbatim when the user does not type their own reason.
const Map<String, String> kAutoLeaveReasons = {
  'CL': 'Casual leave for personal matters',
  'EL': 'Earned leave for planned personal commitments',
  'AL': 'Annual leave for planned time off',
  'PL': 'Privilege leave for planned personal commitments',
  'SL': 'Sick leave due to illness',
  'ML': 'Medical leave due to health reasons',
  'OD': 'Out door duty for official purpose',
  'CO': 'Compensatory off against extra hours worked',
  'LWP': 'Leave without pay for personal reasons',
  'MAT': 'Maternity leave as per company policy',
  'PAT': 'Paternity leave as per company policy',
  'BL': 'Bereavement leave for a family loss',
  'HL': 'Hajj / Umrah leave as per company policy',
  'SPL': 'Special leave as approved by management',
  'STL': 'Study leave for examination preparation',
  'MRL': 'Marriage leave as per company policy',
};

/// Reason placeholder for [leaveType]; falls back to a generic sentence so
/// every leave type has a suggestion.
String autoReasonFor(String leaveType, {String? leaveName}) {
  final code = leaveType.trim().toUpperCase();
  final match = kAutoLeaveReasons[code];
  if (match != null) return match;
  final label = (leaveName != null && leaveName.trim().isNotEmpty)
      ? leaveName.trim()
      : code;
  if (label.isEmpty) return 'Leave applied for personal reasons';
  return 'Applying for $label as per company policy';
}

class LeaveApplicationBloc extends Bloc<LeaveApplicationEvent, LeaveApplicationState> {
  LeaveApplicationBloc(this._submitUseCase, {GetLeaveBalancesUseCase? getBalancesUseCase})
      : _getBalancesUseCase = getBalancesUseCase,
        super(LeaveApplicationState.initial()) {
    on<LeaveTypeChanged>(_onTypeChanged);
    on<LeaveDatesChanged>(_onDatesChanged);
    on<LeaveReasonChanged>(_onReasonChanged);
    on<LeaveHalfDayToggled>(_onHalfDayToggled);
    on<LeaveHalfDaySessionChanged>(_onHalfDaySessionChanged);
    on<LeaveSubmitted>(_onSubmitted);
  }

  final SubmitLeaveRequestUseCase _submitUseCase;
  final GetLeaveBalancesUseCase? _getBalancesUseCase;
  final _uuid = const Uuid();

  /// True when the reason box still holds an auto-generated suggestion (or is
  /// empty), so switching leave type may safely replace it.
  bool _reasonIsAuto(String reason) {
    if (reason.trim().isEmpty) return true;
    return kAutoLeaveReasons.values.contains(reason.trim()) ||
        reason.trim() == autoReasonFor(state.leaveType);
  }

  void _onTypeChanged(LeaveTypeChanged event, Emitter<LeaveApplicationState> emit) {
    // Only overwrite the reason when the user hasn't written their own.
    final reason =
        _reasonIsAuto(state.reason) ? '' : state.reason;
    emit(state.copyWith(leaveType: event.leaveType, reason: reason));
  }

  void _onDatesChanged(LeaveDatesChanged event, Emitter<LeaveApplicationState> emit) {
    // A half-day leave is a single day: keep both ends pinned together.
    if (state.halfDay) {
      final day = event.from != state.fromDate ? event.from : event.to;
      emit(state.copyWith(fromDate: day, toDate: day));
      return;
    }
    emit(state.copyWith(fromDate: event.from, toDate: event.to));
  }

  void _onReasonChanged(LeaveReasonChanged event, Emitter<LeaveApplicationState> emit) {
    emit(state.copyWith(reason: event.reason));
  }

  void _onHalfDayToggled(LeaveHalfDayToggled event, Emitter<LeaveApplicationState> emit) {
    if (event.halfDay) {
      // Collapse the range to a single day and default to the first half.
      emit(state.copyWith(
        halfDay: true,
        toDate: state.fromDate,
        halfDaySession: state.halfDaySession ?? HalfDaySession.firstHalf,
      ));
    } else {
      emit(state.copyWith(halfDay: false, clearHalfDaySession: true));
    }
  }

  void _onHalfDaySessionChanged(
    LeaveHalfDaySessionChanged event,
    Emitter<LeaveApplicationState> emit,
  ) {
    emit(state.copyWith(halfDaySession: event.session));
  }

  Future<void> _onSubmitted(LeaveSubmitted event, Emitter<LeaveApplicationState> emit) async {
    emit(state.copyWith(status: LeaveApplicationStatus.submitting));
    try {
      // Fall back to the auto-generated reason when the user left it blank.
      final reason = state.reason.trim().isEmpty
          ? autoReasonFor(state.leaveType)
          : state.reason.trim();
      final request = LeaveRequest(
        id: _uuid.v4(),
        type: state.leaveType,
        fromDate: state.fromDate,
        toDate: state.halfDay ? state.fromDate : state.toDate,
        status: LeaveStatus.pending,
        reason: reason,
        halfDay: state.halfDay,
        halfDaySession: state.halfDay ? state.halfDaySession : null,
      );
      _validate(request);

      // Check leave balance before submitting
      if (_getBalancesUseCase != null) {
        final balances = _getBalancesUseCase.cached() ?? await _getBalancesUseCase();
        final match = balances.where((b) => b.code == request.type).toList();
        if (match.isNotEmpty) {
          final available = match.first.balance;
          if (available <= 0) {
            throw Exception('No remaining balance for this leave type.');
          }
          final requestedDays = request.halfDay
              ? 0.5
              : (request.toDate.difference(request.fromDate).inDays + 1)
                  .toDouble();
          if (requestedDays > available) {
            throw Exception(
              'Insufficient balance. You have $available day(s) but requested $requestedDays day(s).',
            );
          }
        }
      }

      await _submitUseCase(request);
      emit(state.copyWith(status: LeaveApplicationStatus.success));
    } catch (error) {
      emit(state.copyWith(status: LeaveApplicationStatus.failure, errorMessage: ErrorMessages.from(error,
              fallback: 'Could not submit your leave request. Please try again.')));
    }
  }

  void _validate(LeaveRequest request) {
    if (request.type.isEmpty) {
      throw Exception('Select leave type');
    }
    if (request.fromDate.isAfter(request.toDate)) {
      throw Exception('From date cannot be after To date');
    }
    final now = DateTime.now();
    if (request.type != 'OD' && request.fromDate.isBefore(DateTime(now.year, now.month, now.day))) {
      throw Exception('Cannot apply leave for past dates (except OD)');
    }
    if (request.halfDay && state.halfDaySession == null) {
      throw Exception('Select First Half or Second Half for half-day leave');
    }
  }
}
