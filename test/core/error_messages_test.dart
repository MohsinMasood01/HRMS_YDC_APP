import 'dart:async';
import 'dart:io';

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

    test('face server unreachable shows the offline message, not the dump',
        () {
      // Seen in the field when face.<host> could not be resolved.
      final message = ErrorMessages.from(
        Exception(
          "Failed to identify face: The connection errored: Failed host "
          "lookup: 'face.sysnovix.com' This indicates an error which most "
          'likely cannot be solved by the library.',
        ),
      );
      expect(message, ErrorMessages.offline);
    });

    test('raw socket and timeout exceptions are worded for the user', () {
      expect(
        ErrorMessages.from(const SocketException('Failed host lookup')),
        ErrorMessages.offline,
      );
      expect(
        ErrorMessages.from(TimeoutException('no fix')),
        ErrorMessages.timeout,
      );
    });

    test('isNetworkError separates "unreachable" from server answers', () {
      DioException dio(DioExceptionType type, {Object? error}) =>
          DioException(requestOptions: options, type: type, error: error);

      expect(
        ErrorMessages.isNetworkError(dio(DioExceptionType.connectionError)),
        isTrue,
      );
      expect(
        ErrorMessages.isNetworkError(dio(DioExceptionType.receiveTimeout)),
        isTrue,
      );
      expect(
        ErrorMessages.isNetworkError(
          dio(
            DioExceptionType.unknown,
            error: const SocketException('Network is unreachable'),
          ),
        ),
        isTrue,
      );
      expect(
        ErrorMessages.isNetworkError(dio(DioExceptionType.badResponse)),
        isFalse,
      );
      expect(ErrorMessages.isNetworkError(Exception('bad input')), isFalse);
    });
  });
}
