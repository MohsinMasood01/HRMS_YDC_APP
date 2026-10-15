import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Turns any thrown object into a sentence that is safe and useful to show to
/// an employee.
///
/// Blocs used to surface `e.toString()` directly, which leaked things like
/// `DioException [connection error]: SocketException: Failed host lookup...`
/// into the UI. Everything now goes through [ErrorMessages.from], so the user
/// sees what went wrong and what to do about it.
class ErrorMessages {
  const ErrorMessages._();

  static const String generic =
      'Something went wrong. Please try again in a moment.';
  static const String offline =
      'No internet connection. Please check your network and try again.';
  static const String timeout =
      'The server is taking too long to respond. Please try again.';
  static const String sessionExpired =
      'Your session has expired. Please sign in again.';

  /// Human-readable message for [error].
  ///
  /// [fallback] is used when nothing more specific can be determined, so a
  /// caller can say e.g. 'Could not load your profile.' instead of the generic
  /// sentence.
  static String from(Object? error, {String fallback = generic}) {
    if (error == null) return fallback;
    if (error is DioException) return _fromDio(error, fallback);
    if (error is AppException) return _clean(error.message, fallback);
    return _clean(error.toString(), fallback);
  }

  static String _fromDio(DioException error, String fallback) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return timeout;
      case DioExceptionType.connectionError:
        return offline;
      case DioExceptionType.cancel:
        return 'The request was cancelled. Please try again.';
      case DioExceptionType.badCertificate:
        return 'Could not establish a secure connection to the server.';
      case DioExceptionType.badResponse:
        return _fromResponse(error.response, fallback);
      case DioExceptionType.unknown:
        // Dio reports offline sockets as `unknown` on some platforms.
        final text = error.error?.toString() ?? error.message ?? '';
        if (_looksOffline(text)) return offline;
        return _clean(error.message, fallback);
    }
  }

  static String _fromResponse(Response<dynamic>? response, String fallback) {
    final status = response?.statusCode ?? 0;

    // Prefer whatever the backend said, when it said something readable.
    final serverMessage = _serverMessage(response?.data);
    if (serverMessage != null) return serverMessage;

    if (status == 401 || status == 403) return sessionExpired;
    if (status == 404) {
      return 'That information is not available on the server yet.';
    }
    if (status == 408 || status == 429) {
      return 'The server is busy right now. Please try again shortly.';
    }
    if (status >= 500) {
      return 'The server is unavailable right now. Please try again later.';
    }
    if (status >= 400) return fallback;
    return fallback;
  }

  /// Digs a `message` / `error` string out of the common response shapes.
  static String? _serverMessage(dynamic data) {
    if (data is String) {
      final text = data.trim();
      // Guard against an HTML error page being shown as a message.
      if (text.isEmpty ||
          text.startsWith('<') ||
          text.length > 300) {
        return null;
      }
      return text;
    }
    if (data is! Map) return null;

    for (final key in const ['message', 'error', 'detail', 'msg', 'title']) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        final text = value.trim();
        if (text.length <= 300 && !text.startsWith('<')) return text;
      }
    }
    // ORDS-style bodies nest the payload one level down.
    final body = data['body'];
    if (body != null && body != data) return _serverMessage(body);
    return null;
  }

  /// Strips Dart exception noise; returns [fallback] when nothing readable is
  /// left or the text is clearly a developer-facing stack/type dump.
  static String _clean(String? raw, String fallback) {
    var text = (raw ?? '').trim();
    if (text.isEmpty || text == 'null') return fallback;

    for (final prefix in const [
      'Exception: ',
      'AppException: ',
      'NetworkException: ',
      'CacheException: ',
      'FormatException: ',
      'StateError: ',
      'Bad state: ',
    ]) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
      }
    }

    if (text.isEmpty) return fallback;
    if (_looksOffline(text)) return offline;

    // Anything that still reads like a developer message is not shown.
    const devMarkers = [
      'DioException',
      'SocketException',
      'HandshakeException',
      'TimeoutException',
      'type \'',
      'is not a subtype',
      'NoSuchMethodError',
      'Null check operator',
      '#0 ',
      'package:',
    ];
    for (final marker in devMarkers) {
      if (text.contains(marker)) return fallback;
    }

    if (text.length > 300) return fallback;
    return text;
  }

  static bool _looksOffline(String text) {
    final t = text.toLowerCase();
    return t.contains('socketexception') ||
        t.contains('failed host lookup') ||
        t.contains('network is unreachable') ||
        t.contains('connection refused') ||
        t.contains('connection closed') ||
        t.contains('no address associated') ||
        t.contains('nodename nor servname');
  }
}
