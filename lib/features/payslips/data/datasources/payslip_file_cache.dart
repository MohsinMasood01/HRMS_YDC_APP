import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloaded payslip PDFs, one folder per `card_no + period`:
///
///   `<app cache>/payslips/<card>_<period>/<server file name>.pdf`
///
/// The app cache directory is private to the app and excluded from backups on
/// both platforms. A finalised payslip never changes, so entries are kept
/// until the list is pulled to refresh or the user signs out ([clearAll]).
class PayslipFileCache {
  static const _folder = 'payslips';

  Future<Directory> _root() async {
    final base = await getApplicationCacheDirectory();
    return Directory(p.join(base.path, _folder));
  }

  Future<Directory> _entryDir(String cardNo, int period) async =>
      Directory(p.join((await _root()).path, '${_safe(cardNo)}_$period'));

  /// The cached PDF for this payslip, or null if it was never downloaded.
  Future<File?> find(String cardNo, int period) async {
    final dir = await _entryDir(cardNo, period);
    if (!await dir.exists()) return null;
    await for (final entity in dir.list()) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith('.pdf') &&
          await entity.length() > 0) {
        return entity;
      }
    }
    return null;
  }

  /// Replaces whatever is cached for this payslip with [bytes].
  Future<File> store(
    String cardNo,
    int period,
    String fileName,
    Uint8List bytes,
  ) async {
    final dir = await _entryDir(cardNo, period);
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    // Write then rename, so an interrupted write never leaves a truncated
    // file that [find] would serve as a valid payslip.
    final tmp = File(p.join(dir.path, '.download'));
    await tmp.writeAsBytes(bytes, flush: true);
    return tmp.rename(p.join(dir.path, fileName));
  }

  Future<void> evict(String cardNo, int period) async {
    final dir = await _entryDir(cardNo, period);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Drops every cached payslip of [cardNo] (pull-to-refresh).
  Future<void> evictCard(String cardNo) async {
    final root = await _root();
    if (!await root.exists()) return;
    final prefix = '${_safe(cardNo)}_';
    await for (final entity in root.list()) {
      if (entity is Directory && p.basename(entity.path).startsWith(prefix)) {
        await entity.delete(recursive: true);
      }
    }
  }

  /// Removes every cached payslip. Called on sign-out / session expiry
  /// because payslips are private.
  ///
  /// Also clears share_plus' Android staging folder (`<cache>/share_plus`),
  /// where it copies files handed to the share sheet -- that is the only
  /// other place a payslip copy can linger inside the app.
  Future<void> clearAll() async {
    try {
      final root = await _root();
      if (await root.exists()) await root.delete(recursive: true);

      if (Platform.isAndroid) {
        final tmp = await getTemporaryDirectory();
        final shareDir = Directory(p.join(tmp.path, 'share_plus'));
        if (await shareDir.exists()) await shareDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[Payslips] Could not clear payslip cache: $e');
    }
  }

  static String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
