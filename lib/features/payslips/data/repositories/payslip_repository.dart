import 'dart:io';

import '../../../../core/services/secure_storage_service.dart';
import '../../domain/entities/payslip_summary.dart';
import '../../domain/payslip_exception.dart';
import '../datasources/payslip_file_cache.dart';
import '../datasources/payslip_remote_data_source.dart';

/// Payslips of the signed-in employee.
///
/// The card number and `session_token` always come from what the login stored
/// (secure storage keys `card_no1`/`card_no` and `token`), so these endpoints
/// can never be called for anyone else's card, and never without the Bearer
/// token -- a missing value is reported as a session problem instead.
class PayslipRepository {
  PayslipRepository({
    required PayslipRemoteDataSource remote,
    required PayslipFileCache cache,
    required SecureStorageService secureStorage,
  }) : _remote = remote,
       _cache = cache,
       _secureStorage = secureStorage;

  final PayslipRemoteDataSource _remote;
  final PayslipFileCache _cache;
  final SecureStorageService _secureStorage;

  /// Logged-in employee's card number, or null when nobody is signed in.
  Future<String?> currentCardNo() async {
    final card =
        (await _secureStorage.read('card_no1') ??
                await _secureStorage.read('card_no') ??
                '')
            .trim();
    return card.isEmpty ? null : card;
  }

  Future<({String cardNo, String token})> _credentials() async {
    final cardNo = await currentCardNo();
    final token = (await _secureStorage.read('token'))?.trim() ?? '';
    if (cardNo == null || token.isEmpty) {
      throw const PayslipException.session();
    }
    return (cardNo: cardNo, token: token);
  }

  /// Finalised months, newest first, exactly as the server returns them.
  ///
  /// [refresh] (pull-to-refresh) also drops the cached PDFs so each payslip is
  /// downloaded again the next time it is opened.
  Future<List<PayslipSummary>> getPayslips({bool refresh = false}) async {
    final creds = await _credentials();
    if (refresh) await _cache.evictCard(creds.cardNo);
    return _remote.fetchPayslips(cardNo: creds.cardNo, token: creds.token);
  }

  /// The payslip PDF for [period], from the cache when available.
  Future<File> getPayslipPdf(int period, {bool forceRefresh = false}) async {
    final creds = await _credentials();

    if (forceRefresh) {
      await _cache.evict(creds.cardNo, period);
    } else {
      final cached = await _cache.find(creds.cardNo, period);
      if (cached != null) return cached;
    }

    final pdf = await _remote.downloadPdf(
      cardNo: creds.cardNo,
      period: period,
      token: creds.token,
    );
    final fileName = pdf.fileName ?? 'payslip_${creds.cardNo}_$period.pdf';
    return _cache.store(creds.cardNo, period, fileName, pdf.bytes);
  }

  Future<void> clearCache() => _cache.clearAll();
}
