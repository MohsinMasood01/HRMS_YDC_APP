import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/dio_client.dart';
import 'apk_updater.dart';
import 'app_version_service.dart';

/// Platform identifier the server expects in `?platform=`.
String get _platform => Platform.isIOS ? 'ios' : 'android';

/// Play Store listing for this app.
const String kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.yousufdewan.hrms';

/// PLACEHOLDER: the App Store app does not exist yet. Replace the id with the
/// real one (`https://apps.apple.com/app/id<NUMBER>`) once it is published.
const String kAppStoreUrl = 'https://apps.apple.com/app/id0000000000';

/// Store listing for the running platform -- used whenever the server's
/// `update_url` is missing or is not a store listing (store builds must never
/// download and install an APK themselves).
String get kFallbackUpdateUrl => Platform.isIOS ? kAppStoreUrl : kPlayStoreUrl;

/// [url] when it is a store listing, otherwise [kFallbackUpdateUrl].
String storeUpdateUrl(String? url) {
  final trimmed = url?.trim() ?? '';
  if (trimmed.isNotEmpty && ApkUpdater.isStoreUrl(trimmed)) return trimmed;
  if (trimmed.isNotEmpty) {
    debugPrint(
      '[UpdateService] update_url is not a store listing ($trimmed); '
      'using $kFallbackUpdateUrl',
    );
  }
  return kFallbackUpdateUrl;
}

/// What the server tells us about the installed version.
enum UpdateStatus { ok, soft, force }

class UpdateCheckResult {
  UpdateCheckResult({
    required this.status,
    required this.message,
    required this.updateUrl,
    this.latestVersion,
  });

  final UpdateStatus status;
  final String message;
  final String updateUrl;
  final String? latestVersion;

  bool get isForce => status == UpdateStatus.force;
  bool get isSoft => status == UpdateStatus.soft;

  /// Builder for the "no update needed" / unknown case — used on network
  /// errors so callers can treat the result as a no-op.
  factory UpdateCheckResult.ok() => UpdateCheckResult(
        status: UpdateStatus.ok,
        message: '',
        updateUrl: kFallbackUpdateUrl,
      );

  /// Builder for an HTTP 426 response payload — used by the interceptor.
  factory UpdateCheckResult.forced({
    required String message,
    required String updateUrl,
  }) =>
      UpdateCheckResult(
        status: UpdateStatus.force,
        message: message,
        updateUrl: storeUpdateUrl(updateUrl),
      );
}

/// Calls the backend `/app/version-check` endpoint and parses the response.
///
/// Fails open on network/parse errors — returns `UpdateCheckResult.ok()` so a
/// transient outage of the version-check endpoint never blocks the app on
/// launch. The HTTP 426 enforcement on login/attendance is the safety net.
class UpdateService {
  UpdateService(this._versions, {Dio? dio}) : _dio = dio ?? DioClient.instance;

  final AppVersionService _versions;
  final Dio _dio;

  Future<UpdateCheckResult> check() async {
    try {
      final version = await _versions.version();
      final build = await _versions.build();

      final response = await _dio.get<Map<String, dynamic>>(
        '/app/version-check',
        queryParameters: {
          'platform': _platform,
          'version': version,
          'build': build,
        },
      );

      final data = response.data ?? const <String, dynamic>{};
      return _parse(data);
    } catch (e) {
      debugPrint('[UpdateService] check failed (failing open): $e');
      return UpdateCheckResult.ok();
    }
  }

  UpdateCheckResult _parse(Map<String, dynamic> data) {
    final statusStr = (data['status'] as String?)?.toLowerCase() ?? 'ok';
    final force = data['force'] == true || statusStr == 'force_update';
    final soft = !force && statusStr == 'soft_update';

    final UpdateStatus status = force
        ? UpdateStatus.force
        : (soft ? UpdateStatus.soft : UpdateStatus.ok);

    return UpdateCheckResult(
      status: status,
      message: (data['message'] as String?) ?? '',
      updateUrl: storeUpdateUrl(data['update_url'] as String?),
      latestVersion: data['latest_version'] as String?,
    );
  }
}
