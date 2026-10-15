import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/payslip_summary.dart';
import '../../domain/payslip_exception.dart';

/// A payslip PDF as served by the backend.
class PayslipPdf {
  const PayslipPdf({required this.bytes, this.fileName});

  final Uint8List bytes;

  /// From `Content-Disposition`, e.g. `payslip_100002.1_AUG-2026.pdf`.
  final String? fileName;
}

/// Talks to the payslip endpoints. All of them require the login
/// `session_token` as a Bearer token and only ever serve months HR has
/// finalised -- the server does that filtering, never the app.
///
///   GET /auth/payslips/:card_no                -> { items: [...] }
///   GET /auth/payslips/:card_no/:period/pdf    -> application/pdf
///
/// Salary figures, PDF bytes and the token are deliberately never logged.
class PayslipRemoteDataSource {
  PayslipRemoteDataSource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static String listPath(String cardNo) =>
      '/auth/payslips/${Uri.encodeComponent(cardNo)}';

  static String pdfPath(String cardNo, int period) =>
      '${listPath(cardNo)}/$period/pdf';

  Future<List<PayslipSummary>> fetchPayslips({
    required String cardNo,
    required String token,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        listPath(cardNo),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return parseItems(response.data);
    } on DioException catch (e) {
      throw _map(e, 'Could not load your payslips.');
    }
  }

  Future<PayslipPdf> downloadPdf({
    required String cardNo,
    required int period,
    required String token,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        pdfPath(cardNo, period),
        options: Options(
          responseType: ResponseType.bytes,
          // The server renders the PDF on demand; allow it more time than a
          // JSON call.
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/pdf',
          },
        ),
      );

      final data = response.data;
      final bytes = data == null ? Uint8List(0) : Uint8List.fromList(data);
      if (!_looksLikePdf(bytes)) {
        debugPrint('[Payslips] PDF response for period $period is not a PDF');
        throw const PayslipException(
          PayslipErrorKind.network,
          'The payslip could not be downloaded. Please try again.',
        );
      }

      return PayslipPdf(
        bytes: bytes,
        fileName: fileNameFromContentDisposition(
          response.headers.value('content-disposition'),
        ),
      );
    } on DioException catch (e) {
      throw _map(e, 'The payslip could not be downloaded.');
    }
  }

  /// Parses `{ items: [...] }` (tolerating the `body` envelope used by other
  /// endpoints of this API).
  @visibleForTesting
  static List<PayslipSummary> parseItems(dynamic data) {
    var map = _asMap(data);
    if (map != null && map['items'] == null && map['body'] != null) {
      map = _asMap(map['body']);
    }
    final items = map?['items'];
    if (items is! List) return const [];

    final result = <PayslipSummary>[];
    for (final raw in items) {
      final row = _asMap(raw);
      final period = _asNum(row?['period'])?.toInt();
      if (row == null || period == null) continue;
      result.add(
        PayslipSummary(
          period: period,
          label: row['label']?.toString() ?? '',
          periodFrom: DateTime.tryParse(row['period_frm']?.toString() ?? ''),
          periodTo: DateTime.tryParse(row['period_to']?.toString() ?? ''),
          totalEarning: _asNum(row['total_earning']) ?? 0,
          totalDeduction: _asNum(row['total_deduction']) ?? 0,
          netPayable: _asNum(row['net_payable']) ?? 0,
        ),
      );
    }
    return result;
  }

  /// Extracts the file name from a `Content-Disposition` header, preferring
  /// the RFC 5987 `filename*=` form. Path separators are stripped so the
  /// value is safe to use as a local file name.
  @visibleForTesting
  static String? fileNameFromContentDisposition(String? header) {
    if (header == null || header.isEmpty) return null;

    String? name;
    final extended = RegExp(
      r"filename\*\s*=\s*(?:[\w-]+)?'[^']*'([^;]+)",
      caseSensitive: false,
    ).firstMatch(header);
    if (extended != null) {
      try {
        name = Uri.decodeComponent(extended.group(1)!.trim());
      } catch (_) {
        name = null;
      }
    }
    name ??= RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(header)?.group(1)?.trim();

    if (name == null) return null;
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (name.isEmpty) return null;
    return name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf';
  }

  PayslipException _map(DioException e, String fallback) {
    final status = e.response?.statusCode;
    final code = _errorCode(e.response?.data);
    debugPrint('[Payslips] Request failed: HTTP ${status ?? '-'} ${code ?? ''}');

    if (status == 401 || status == 403) {
      return const PayslipException.session();
    }
    if (status == 404) return const PayslipException.notFound();
    return PayslipException(
      PayslipErrorKind.network,
      ErrorMessages.from(e, fallback: fallback),
    );
  }

  /// `detail.code` from `{ detail: { code: "..." } }`. With a bytes response
  /// type the error body arrives as raw bytes, so decode those too.
  static String? _errorCode(dynamic data) {
    dynamic decoded = data;
    if (data is List<int>) {
      try {
        decoded = jsonDecode(utf8.decode(data));
      } catch (_) {
        return null;
      }
    }
    final detail = _asMap(_asMap(decoded)?['detail']);
    return detail?['code']?.toString();
  }

  static bool _looksLikePdf(Uint8List bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

  static Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }
}
