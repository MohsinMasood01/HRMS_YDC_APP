import 'package:package_info_plus/package_info_plus.dart';

/// Single source of truth for this app's installed version + build.
///
/// Reads from `package_info_plus` once and caches the result so the platform
/// channel isn't hit on every login / attendance / version-check call.
class AppVersionService {
  PackageInfo? _cache;

  Future<PackageInfo> _info() async {
    return _cache ??= await PackageInfo.fromPlatform();
  }

  /// e.g. "1.4.2"
  Future<String> version() async => (await _info()).version;

  /// e.g. 48 — coerced from `buildNumber` which the platform returns as a String.
  /// Falls back to 0 if the value isn't a valid int (shouldn't happen on
  /// Android / iOS but defensive).
  Future<int> build() async {
    final raw = (await _info()).buildNumber;
    return int.tryParse(raw) ?? 0;
  }
}
