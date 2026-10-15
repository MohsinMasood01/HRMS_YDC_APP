enum PayslipErrorKind {
  /// 401 SESSION_REQUIRED / 403 CARD_MISMATCH, or no token/card stored at all.
  /// The user has to sign in again.
  session,

  /// 404: the period is not finalised for this employee (or unknown employee).
  notFound,

  /// Offline, timeout, 5xx or an unreadable response. Retryable.
  network,
}

class PayslipException implements Exception {
  const PayslipException(this.kind, this.message);

  const PayslipException.session()
    : kind = PayslipErrorKind.session,
      message = 'Your session has expired. Please sign in again.';

  const PayslipException.notFound()
    : kind = PayslipErrorKind.notFound,
      message = 'Payslip not available';

  final PayslipErrorKind kind;
  final String message;

  @override
  String toString() => message;
}
