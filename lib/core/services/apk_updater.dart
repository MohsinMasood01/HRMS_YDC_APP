import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';

/// Sends the user to the store listing to update the app.
///
/// Used by [ForceUpdatePage] and [SoftUpdateDialog]. Store builds must not
/// download or self-install APKs (REQUEST_INSTALL_PACKAGES is stripped from
/// the manifest), so every update goes through Google Play / the App Store.
/// A non-store `update_url` from the backend is replaced with
/// [kFallbackUpdateUrl].
class ApkUpdater {
  /// True when [url] points at a store listing rather than a downloadable APK.
  static bool isStoreUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.host == 'play.google.com' ||
        uri.host == 'apps.apple.com' ||
        uri.scheme == 'market' ||
        uri.scheme == 'itms-apps';
  }

  /// True when [url] is a listing in this platform's own store.
  static bool _isOwnStoreUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (Platform.isIOS) {
      return uri.host == 'apps.apple.com' || uri.scheme == 'itms-apps';
    }
    return uri.host == 'play.google.com' || uri.scheme == 'market';
  }

  /// Open the store listing in the store app (or browser fallback). [url] is
  /// used when it is a listing in this platform's store, otherwise
  /// [kFallbackUpdateUrl].
  Future<bool> openStore(String url) async {
    final target = _isOwnStoreUrl(url) ? url : kFallbackUpdateUrl;
    try {
      return await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('[ApkUpdater] openStore failed: $e');
      return false;
    }
  }
}
