import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/leave_balance.dart';
import '../../../domain/usecases/get_leave_balances_usecase.dart';
import '../../../../../core/errors/error_messages.dart';

part 'leave_balance_event.dart';
part 'leave_balance_state.dart';

class LeaveBalanceBloc extends Bloc<LeaveBalanceEvent, LeaveBalanceState> {
  LeaveBalanceBloc(this._useCase) : super(const LeaveBalanceState()) {
    on<LeaveBalanceRequested>(_onRequested);
  }

  final GetLeaveBalancesUseCase _useCase;

  Future<void> _onRequested(LeaveBalanceRequested event, Emitter<LeaveBalanceState> emit) async {
    final cached = _useCase.cached();
    if (cached != null) {
      emit(state.copyWith(status: LeaveBalanceStatus.success, balances: cached));
    } else {
      emit(state.copyWith(status: LeaveBalanceStatus.loading));
    }
    try {
      final balances = await _useCase();
      emit(state.copyWith(status: LeaveBalanceStatus.success, balances: balances));
    } catch (error) {
      emit(state.copyWith(status: LeaveBalanceStatus.failure, errorMessage: ErrorMessages.from(error,
              fallback: 'Could not load your leave balances. Please try again.')));
    }
  }
}

