import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/errors/error_messages.dart';

void main() {
  final options = RequestOptions(path: '/auth/profile/123');

  group('ErrorMessages', () {
    test('offline connection errors read as a network problem', () {
      final message = ErrorMessages.from(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(message, ErrorMessages.offline);
    });

    test('a raw SocketException never reaches the user verbatim', () {
      final message = ErrorMessages.from(
        Exception('SocketException: Failed host lookup: hrms.d-tech.com.pk'),
      );
      expect(message, ErrorMessages.offline);
    });

    test('timeouts say the server is slow, not that the app failed', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          ErrorMessages.from(
            DioException(requestOptions: options, type: type),
          ),
          ErrorMessages.timeout,
        );
      }
    });

    test('the backend message wins when it sent a readable one', () {
      final message = ErrorMessages.from(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 400,
            data: {'message': 'Leave balance is not enough.'},
          ),
        ),
      );
      expect(message, 'Leave balance is not enough.');
    });

    test('401 asks the user to sign in again', () {
      final message = ErrorMessages.from(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 401,
          ),
        ),
      );
      expect(message, ErrorMessages.sessionExpired);
    });

    test('an HTML error page is not shown as the message', () {
      final message = ErrorMessages.from(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 500,
            data: '<html><body>Internal Server Error</body></html>',
          ),
        ),
        fallback: 'Could not load your profile. Please try again.',
      );
      expect(message, contains('server is unavailable'));
    });

    test('validation messages we raise ourselves pass through unchanged', () {
      expect(
        ErrorMessages.from(Exception('Select First Half or Second Half')),
        'Select First Half or Second Half',
      );
    });

    test('type errors fall back instead of leaking Dart internals', () {
      const fallback = 'Could not load your profile. Please try again.';
      expect(
        ErrorMessages.from(
          Exception("type 'Null' is not a subtype of type 'String'"),
          fallback: fallback,
        ),
        fallback,
      );
    });
  });
}
