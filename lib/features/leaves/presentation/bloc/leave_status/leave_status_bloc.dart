import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/leave_request.dart';
import '../../../domain/usecases/get_leave_requests_usecase.dart';
import '../../../../../core/errors/error_messages.dart';

part 'leave_status_event.dart';
part 'leave_status_state.dart';

class LeaveStatusBloc extends Bloc<LeaveStatusEvent, LeaveStatusState> {
  LeaveStatusBloc(this._useCase) : super(const LeaveStatusState()) {
    on<LeaveStatusRequested>(_onRequested);
  }

  final GetLeaveRequestsUseCase _useCase;

  Future<void> _onRequested(LeaveStatusRequested event, Emitter<LeaveStatusState> emit) async {
    final cached = _useCase.cached();
    if (cached != null) {
      emit(state.copyWith(status: LeaveStatusEnum.success, requests: cached));
    } else {
      emit(state.copyWith(status: LeaveStatusEnum.loading));
    }
    try {
      final requests = await _useCase();
      emit(state.copyWith(status: LeaveStatusEnum.success, requests: requests));
    } catch (error) {
      emit(state.copyWith(status: LeaveStatusEnum.failure, errorMessage: ErrorMessages.from(error,
              fallback: 'Could not load your leave requests. Please try again.')));
    }
  }
}

