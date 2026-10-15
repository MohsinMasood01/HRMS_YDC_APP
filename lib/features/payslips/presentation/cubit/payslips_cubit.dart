import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/payslip_repository.dart';
import '../../domain/entities/payslip_summary.dart';
import '../../domain/payslip_exception.dart';

enum PayslipsStatus { loading, success, failure }

class PayslipsState extends Equatable {
  const PayslipsState({
    this.status = PayslipsStatus.loading,
    this.items = const [],
    this.error,
  });

  final PayslipsStatus status;
  final List<PayslipSummary> items;
  final PayslipException? error;

  @override
  List<Object?> get props => [status, items, error?.kind, error?.message];
}

class PayslipsCubit extends Cubit<PayslipsState> {
  PayslipsCubit(this._repository) : super(const PayslipsState());

  final PayslipRepository _repository;

  Future<void> load({bool refresh = false}) async {
    // Keep the current rows on screen during a pull-to-refresh.
    if (!refresh || state.items.isEmpty) {
      emit(const PayslipsState(status: PayslipsStatus.loading));
    }
    try {
      final items = await _repository.getPayslips(refresh: refresh);
      emit(PayslipsState(status: PayslipsStatus.success, items: items));
    } on PayslipException catch (e) {
      emit(PayslipsState(status: PayslipsStatus.failure, error: e));
    } catch (_) {
      emit(
        const PayslipsState(
          status: PayslipsStatus.failure,
          error: PayslipException(
            PayslipErrorKind.network,
            'Could not load your payslips. Please try again.',
          ),
        ),
      );
    }
  }
}
