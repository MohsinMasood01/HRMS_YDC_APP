import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../di/service_locator.dart';
import '../../authentication/presentation/bloc/auth_bloc.dart';
import '../data/repositories/payslip_repository.dart';
import 'pages/payslips_page.dart';

/// Sends the user back to sign in when a payslip call reports an expired /
/// missing session (401) or a card mismatch (403), and brings them back to
/// My Payslips once they have signed in again as the same employee.
class PayslipSession {
  PayslipSession._();

  /// Card that was viewing payslips when the session expired. In memory
  /// only: a restarted app simply lands on the Dashboard.
  static String? _resumeForCard;

  static Future<void> expire(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();
    final navigator = Navigator.of(context);
    _resumeForCard = await getIt<PayslipRepository>().currentCardNo();

    navigator.popUntil((route) => route.isFirst);
    authBloc.add(const SessionExpired());
  }

  /// Called by the home shell after sign-in. Re-opens My Payslips if the
  /// previous session ended on it and the same employee signed back in.
  static Future<void> resumeIfPending(BuildContext context) async {
    final pending = _resumeForCard;
    if (pending == null) return;
    _resumeForCard = null;

    final card = await getIt<PayslipRepository>().currentCardNo();
    if (card != pending || !context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PayslipsPage()));
  }
}

/// Display formatting shared by the payslip screens. Money is rounded to a
/// whole number with thousands separators, matching the web payslip.
class PayslipFormat {
  PayslipFormat._();

  static final NumberFormat _money = NumberFormat('#,##0', 'en_US');
  static final DateFormat _date = DateFormat('d MMM yyyy');

  static String money(num value) => _money.format(value.round());

  static String range(DateTime? from, DateTime? to) {
    if (from == null && to == null) return '';
    if (from == null) return _date.format(to!);
    if (to == null) return _date.format(from);
    return '${_date.format(from)} – ${_date.format(to)}';
  }
}
