import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/payslips/data/datasources/payslip_remote_data_source.dart';
import 'package:lms/features/payslips/domain/payslip_exception.dart';
import 'package:lms/features/payslips/presentation/payslip_session.dart';

/// Records the last request and replies with a canned response.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.bytes, {this.headers = const {}});

  final int status;
  final List<int> bytes;
  final Map<String, List<String>> headers;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromBytes(bytes, status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

_FakeAdapter _json(int status, Object body) => _FakeAdapter(
  status,
  utf8.encode(jsonEncode(body)),
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

PayslipRemoteDataSource _source(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
    ..httpClientAdapter = adapter;
  return PayslipRemoteDataSource(dio: dio);
}

void main() {
  group('list', () {
    test('sends the Bearer token to the card-scoped path and parses items',
        () async {
      final adapter = _json(200, {
        'items': [
          {
            'period': 97,
            'period_frm': '2026-08-01',
            'period_to': '2026-08-31',
            'label': 'AUG - 2026',
            'total_earning': 136500,
            'total_deduction': 4515,
            'net_payable': 131985,
          },
        ],
      });

      final items = await _source(
        adapter,
      ).fetchPayslips(cardNo: '100002.1', token: 'tok');

      expect(adapter.lastRequest!.path, '/auth/payslips/100002.1');
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer tok');
      expect(items, hasLength(1));
      expect(items.single.period, 97);
      expect(items.single.label, 'AUG - 2026');
      expect(items.single.periodFrom, DateTime(2026, 8, 1));
      expect(items.single.netPayable, 131985);
    });

    test('empty list stays empty', () async {
      final items = await _source(
        _json(200, {'items': []}),
      ).fetchPayslips(cardNo: '1', token: 't');
      expect(items, isEmpty);
    });

    for (final (status, code) in [
      (401, 'SESSION_REQUIRED'),
      (403, 'CARD_MISMATCH'),
    ]) {
      test('$status $code is a session error', () async {
        final call = _source(_json(status, {
          'detail': {'code': code},
        })).fetchPayslips(cardNo: '1', token: 't');
        await expectLater(
          call,
          throwsA(
            isA<PayslipException>().having(
              (e) => e.kind,
              'kind',
              PayslipErrorKind.session,
            ),
          ),
        );
      });
    }

    test('500 is a retryable network error', () async {
      final call = _source(
        _json(500, {'detail': 'boom'}),
      ).fetchPayslips(cardNo: '1', token: 't');
      await expectLater(
        call,
        throwsA(
          isA<PayslipException>().having(
            (e) => e.kind,
            'kind',
            PayslipErrorKind.network,
          ),
        ),
      );
    });
  });

  group('pdf', () {
    final pdfBytes = utf8.encode('%PDF-1.7\n...');

    test('downloads bytes and takes the server file name', () async {
      final adapter = _FakeAdapter(
        200,
        pdfBytes,
        headers: {
          'content-type': ['application/pdf'],
          'content-disposition': [
            'attachment; filename="payslip_100002.1_AUG-2026.pdf"',
          ],
        },
      );

      final pdf = await _source(
        adapter,
      ).downloadPdf(cardNo: '100002.1', period: 97, token: 'tok');

      expect(adapter.lastRequest!.path, '/auth/payslips/100002.1/97/pdf');
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer tok');
      expect(pdf.fileName, 'payslip_100002.1_AUG-2026.pdf');
      expect(pdf.bytes, pdfBytes);
    });

    test('404 means the payslip is not available', () async {
      final call = _source(
        _json(404, {'detail': 'not found'}),
      ).downloadPdf(cardNo: '1', period: 1, token: 't');
      await expectLater(
        call,
        throwsA(
          isA<PayslipException>().having(
            (e) => e.kind,
            'kind',
            PayslipErrorKind.notFound,
          ),
        ),
      );
    });

    test('401 is a session error even with a bytes response type', () async {
      final call = _source(_json(401, {
        'detail': {'code': 'SESSION_REQUIRED'},
      })).downloadPdf(cardNo: '1', period: 1, token: 't');
      await expectLater(
        call,
        throwsA(
          isA<PayslipException>().having(
            (e) => e.kind,
            'kind',
            PayslipErrorKind.session,
          ),
        ),
      );
    });

    test('a 200 that is not a PDF is rejected', () async {
      final call = _source(
        _FakeAdapter(200, utf8.encode('<html>proxy error</html>')),
      ).downloadPdf(cardNo: '1', period: 1, token: 't');
      await expectLater(call, throwsA(isA<PayslipException>()));
    });
  });

  group('Content-Disposition', () {
    String? name(String? h) =>
        PayslipRemoteDataSource.fileNameFromContentDisposition(h);

    test('quoted, unquoted and RFC 5987 forms', () {
      expect(name('attachment; filename="a b.pdf"'), 'a b.pdf');
      expect(name('attachment; filename=x.pdf'), 'x.pdf');
      expect(
        name("attachment; filename*=UTF-8''payslip_1_AUG-2026.pdf"),
        'payslip_1_AUG-2026.pdf',
      );
    });

    test('strips path separators and adds a .pdf extension', () {
      expect(name('attachment; filename="../../evil"'), '.._.._evil.pdf');
      expect(name(null), isNull);
      expect(name('inline'), isNull);
    });
  });

  group('formatting', () {
    test('money is rounded with thousands separators', () {
      expect(PayslipFormat.money(131985), '131,985');
      expect(PayslipFormat.money(4514.6), '4,515');
      expect(PayslipFormat.money(0), '0');
    });

    test('period range', () {
      expect(
        PayslipFormat.range(DateTime(2026, 8, 1), DateTime(2026, 8, 31)),
        '1 Aug 2026 – 31 Aug 2026',
      );
      expect(PayslipFormat.range(null, null), '');
    });
  });
}
