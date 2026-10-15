import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/update_service.dart';
import 'force_update_controller.dart';

/// Dio interceptor that catches HTTP 426 ("Upgrade Required") responses
/// from any endpoint, parses the `detail.code == "FORCE_UPDATE"` payload,
/// and routes the user to the blocking update page via
/// [ForceUpdateController].
///
/// Expected error body shape:
/// ```json
/// {
///   "detail": {
///     "code": "FORCE_UPDATE",
///     "message": "Your app version is no longer supported.",
///     "update_url": "https://play.google.com/store/apps/details?id=..."
///   }
/// }
/// ```
///
/// We still call `handler.next(err)` so individual call sites continue to
/// receive their `DioException` and can show their own error UX if they
/// want — the blocking page just overlays on top.
class ForceUpdateInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 426) {
      _handle426(err.response?.data);
    }
    super.onError(err, handler);
  }

  void _handle426(Object? data) {
    try {
      String message = 'An update is required to continue.';
      String updateUrl = kFallbackUpdateUrl;
      String code = '';

      if (data is Map) {
        final detail = data['detail'];
        if (detail is Map) {
          code = (detail['code'] as String?) ?? '';
          message = (detail['message'] as String?) ?? message;
          final rawUrl = (detail['update_url'] as String?) ?? '';
          if (rawUrl.trim().isNotEmpty) updateUrl = rawUrl;
        } else if (detail is String) {
          // Some endpoints send `detail` as a plain string — degrade gracefully.
          message = detail;
        }
      }

      // Be lenient: any 426 triggers the lock. If the server used the
      // expected code we honour the message it sent; otherwise we still
      // surface a generic update prompt rather than letting the user
      // bounce off a raw network error.
      debugPrint('[ForceUpdateInterceptor] 426 caught (code=$code)');
      ForceUpdateController.instance.trigger(
        message: message,
        updateUrl: updateUrl,
      );
    } catch (e) {
      debugPrint('[ForceUpdateInterceptor] failed to parse 426 body: $e');
      ForceUpdateController.instance.trigger(
        message: 'An update is required to continue.',
        updateUrl: kFallbackUpdateUrl,
      );
    }
  }
}
