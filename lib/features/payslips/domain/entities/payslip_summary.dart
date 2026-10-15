import 'package:equatable/equatable.dart';

/// One finalised (HR-posted) month, as returned by
/// `GET /auth/payslips/:card_no`. Figures are displayed exactly as the server
/// sends them -- the app never recalculates salary.
class PayslipSummary extends Equatable {
  const PayslipSummary({
    required this.period,
    required this.label,
    required this.periodFrom,
    required this.periodTo,
    required this.totalEarning,
    required this.totalDeduction,
    required this.netPayable,
  });

  final int period;

  /// e.g. "AUG - 2026".
  final String label;
  final DateTime? periodFrom;
  final DateTime? periodTo;
  final num totalEarning;
  final num totalDeduction;
  final num netPayable;

  @override
  List<Object?> get props => [
    period,
    label,
    periodFrom,
    periodTo,
    totalEarning,
    totalDeduction,
    netPayable,
  ];
}
