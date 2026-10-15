import 'package:flutter/foundation.dart';

import '../services/update_service.dart';

/// Process-wide signal that the user must update before continuing.
///
/// Two writers fire this:
///   1. The launch-time `/app/version-check` call when the server returns
///      `force_update`.
///   2. The Dio interceptor when any request returns HTTP 426 with
///      `detail.code == "FORCE_UPDATE"`.
///
/// `UpdateGate` listens on this controller and overlays the blocking
/// `ForceUpdatePage` whenever [isLocked] flips to true. Singleton + plain
/// `ChangeNotifier` so the interceptor can fire it without needing a
/// `BuildContext` or `GetIt` lookup.
class ForceUpdateController extends ChangeNotifier {
  ForceUpdateController._();

  static final ForceUpdateController instance = ForceUpdateController._();

  bool _isLocked = false;
  String _message = '';
  String _updateUrl = kFallbackUpdateUrl;

  bool get isLocked => _isLocked;
  String get message => _message;
  String get updateUrl => _updateUrl;

  /// Activate the blocking overlay. Idempotent — repeated calls only emit
  /// a single change notification per state transition.
  void trigger({
    required String message,
    required String updateUrl,
  }) {
    final url = updateUrl.trim().isEmpty ? kFallbackUpdateUrl : updateUrl;
    final changed = !_isLocked || _message != message || _updateUrl != url;
    _isLocked = true;
    _message = message;
    _updateUrl = url;
    if (changed) notifyListeners();
  }
}
