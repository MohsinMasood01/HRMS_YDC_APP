import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/payslip_repository.dart';
import '../../domain/payslip_exception.dart';

enum PayslipDetailStatus { loading, ready, failure }

class PayslipDetailState extends Equatable {
  const PayslipDetailState({
    this.status = PayslipDetailStatus.loading,
    this.file,
    this.error,
  });

  final PayslipDetailStatus status;
  final File? file;
  final PayslipException? error;

  @override
  List<Object?> get props => [status, file?.path, error?.kind, error?.message];
}

class PayslipDetailCubit extends Cubit<PayslipDetailState> {
  PayslipDetailCubit(this._repository, this.period)
    : super(const PayslipDetailState());

  final PayslipRepository _repository;
  final int period;
  bool _redownloadedAfterRenderError = false;

  /// [forceRefresh] re-downloads even when a cached copy exists (used after
  /// the viewer failed to render the cached file).
  Future<void> load({bool forceRefresh = false}) async {
    emit(const PayslipDetailState(status: PayslipDetailStatus.loading));
    try {
      final file = await _repository.getPayslipPdf(
        period,
        forceRefresh: forceRefresh,
      );
      emit(PayslipDetailState(status: PayslipDetailStatus.ready, file: file));
    } on PayslipException catch (e) {
      emit(PayslipDetailState(status: PayslipDetailStatus.failure, error: e));
    } catch (_) {
      emit(
        const PayslipDetailState(
          status: PayslipDetailStatus.failure,
          error: PayslipException(
            PayslipErrorKind.network,
            'The payslip could not be downloaded. Please try again.',
          ),
        ),
      );
    }
  }

  /// The viewer could not open the file. Re-download once (the cached copy
  /// may be damaged); if that copy fails too, show a retryable error instead
  /// of looping.
  Future<void> onRenderError() async {
    if (!_redownloadedAfterRenderError) {
      _redownloadedAfterRenderError = true;
      return load(forceRefresh: true);
    }
    emit(
      const PayslipDetailState(
        status: PayslipDetailStatus.failure,
        error: PayslipException(
          PayslipErrorKind.network,
          'This payslip could not be displayed. Please try again.',
        ),
      ),
    );
  }
}
