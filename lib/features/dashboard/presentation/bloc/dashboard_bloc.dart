import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/get_dashboard_summary_usecase.dart';
import '../../../../core/errors/error_messages.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._getDashboardSummaryUseCase)
    : super(const DashboardState()) {
    on<DashboardRequested>(_onRequested);
  }

  final GetDashboardSummaryUseCase _getDashboardSummaryUseCase;

  Future<void> _onRequested(
    DashboardRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(status: DashboardStatus.loading, errorMessage: null));
    try {
      final summary = await _getDashboardSummaryUseCase();
      emit(state.copyWith(status: DashboardStatus.success, summary: summary));
    } catch (e) {
      emit(
        state.copyWith(
          status: DashboardStatus.failure,
          errorMessage: ErrorMessages.from(
            e,
            fallback: 'Could not load your dashboard. Please try again.',
          ),
        ),
      );
    }
  }
}






