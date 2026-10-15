import 'package:dio/dio.dart';

import 'force_update_interceptor.dart';

/// Shared Dio client configured for the LMS APIs.
class DioClient {
  DioClient._()
    : dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          contentType: 'application/json',
          responseType: ResponseType.json,
        ),
      ) {
    // Global 426 → force-update routing for any request through this client.
    dio.interceptors.add(ForceUpdateInterceptor());
  }

  // static const String _baseUrl =
  //     'http://lms.yousufdewan.com:8080/ords/ws_tms/empdata';
  // NOTE: Use your PC's LAN IP — 127.0.0.1 only works on emulator, not physical devices.
  // Run `ipconfig` on Windows to find it (look for IPv4 Address).
  // static const String _baseUrl = 'http://10.0.0.120:8001';
  // static const String _baseUrl = 'http://apps.d-tech.com.pk:8001';
  // static const String _baseUrl = 'http://163.61.91.221:8001';
  // Ports 8001/8002 are firewalled off from the public internet. The only
  // reachable path is Apache (443) → Next.js → /api/* rewrite → backend 8001.
  // static const String _baseUrl = 'http://169.58.96.211:8001'; // LAN/server-local only
  static const String _baseUrl = 'https://hrms.d-tech.com.pk/api';

  /// Public read of the API origin.
  ///
  /// The WorkManager background isolate cannot reuse [instance] — its
  /// [ForceUpdateInterceptor] drives UI that does not exist there — so it
  /// builds a plain Dio against this same origin instead of re-declaring the
  /// URL and drifting out of sync with it.
  static const String baseUrl = _baseUrl;

  static final DioClient _instance = DioClient._();

  /// Access the configured Dio client.
  static Dio get instance => _instance.dio;

  final Dio dio;
}
