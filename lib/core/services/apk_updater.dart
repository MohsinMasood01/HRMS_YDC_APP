import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Result of an [ApkUpdater.install] attempt that wasn't outright a Dart
/// exception. Lets the UI distinguish "user must grant install permission"
/// from a generic plugin failure.
enum ApkInstallStatus {
  /// Installer was successfully launched.
  launched,

  /// REQUEST_INSTALL_PACKAGES denied even after the system prompt — caller
  /// should send the user to system settings.
  permissionDenied,

  /// OpenFilex returned a non-success result (e.g. no app to handle apk).
  installerFailed,
}

/// Downloads the latest APK from the backend and hands it to the Android
/// package installer.
///
/// Used by [ForceUpdatePage] and [SoftUpdateDialog] in place of opening a
/// Play Store URL — this app is distributed as a signed APK from the
/// backend, not via the Play Store.
class ApkUpdater {
  /// Constant filename so repeated downloads overwrite each other and the
  /// app's documents dir doesn't grow unbounded.
  static const String _kApkFileName = 'lms-update.apk';

  /// Resolved path where the downloaded APK lives.
  Future<File> _targetFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _kApkFileName));
  }

  /// Stream the APK to local storage, calling [onProgress] with values in
  /// `0.0..1.0` as bytes arrive.
  ///
  /// Throws on network / IO failure — callers should `try/catch` and show a
  /// retry affordance.
  Future<File> download(
    String url, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = await _targetFile();
    // Dedicated Dio instance with a generous receive timeout — the global
    // singleton's 20s would otherwise kill a 30 MB download mid-stream.
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ));
    // Keep the display on while downloading — if the screen times out, the
    // app is backgrounded and Android drops the in-flight download.
    await _setWakelock(true);
    try {
      await dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
        cancelToken: cancelToken,
      );
    } finally {
      await _setWakelock(false);
    }
    return file;
  }

  /// Hand [apk] to Android's package installer.
  ///
  /// Returns [ApkInstallStatus.launched] on success, [permissionDenied]
  /// when the user refused the REQUEST_INSTALL_PACKAGES permission (callers
  /// should then deep-link to the install-unknown-apps settings page), or
  /// [installerFailed] for other plugin errors.
  Future<ApkInstallStatus> install(File apk) async {
    if (Platform.isAndroid) {
      final granted = await _ensureInstallPermission();
      if (!granted) return ApkInstallStatus.permissionDenied;
    }
    final result = await OpenFilex.open(apk.path);
    debugPrint(
      '[ApkUpdater] OpenFilex result: type=${result.type} message=${result.message}',
    );
    return result.type == ResultType.done
        ? ApkInstallStatus.launched
        : ApkInstallStatus.installerFailed;
  }

  /// Convenience wrapper: download then install. Returns the install status;
  /// download errors propagate as exceptions.
  Future<ApkInstallStatus> downloadAndInstall(
    String url, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = await download(url,
        onProgress: onProgress, cancelToken: cancelToken);
    return install(file);
  }

  /// Deep-link to the system "Install unknown apps" settings page for this
  /// app. Use after [install] returns [ApkInstallStatus.permissionDenied]
  /// so the user can manually toggle the switch.
  Future<void> openInstallPermissionSettings() async {
    await openAppSettings();
  }

  /// Wakelock failures must never break the update itself.
  Future<void> _setWakelock(bool enable) async {
    try {
      await WakelockPlus.toggle(enable: enable);
    } catch (e) {
      debugPrint('[ApkUpdater] wakelock toggle failed: $e');
    }
  }

  Future<bool> _ensureInstallPermission() async {
    final current = await Permission.requestInstallPackages.status;
    if (current.isGranted) return true;
    final result = await Permission.requestInstallPackages.request();
    return result.isGranted;
  }
}
