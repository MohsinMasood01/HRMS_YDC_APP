import 'package:flutter/material.dart';

import '../../core/network/force_update_controller.dart';
import '../../core/services/update_service.dart';
import '../../di/service_locator.dart';
import 'force_update_page.dart';
import 'soft_update_dialog.dart';

/// Wraps the rest of the app and gates it on the version-check result.
///
/// Responsibilities:
///   * On first build, fires `UpdateService.check()` once. If the server
///     returns `force_update`, [ForceUpdateController] is triggered.
///     If `soft_update`, a dismissible dialog is shown (once per session).
///   * Listens to [ForceUpdateController] and overlays [ForceUpdatePage]
///     on top of [child] whenever the controller is locked — so any 426
///     caught later by the Dio interceptor also routes here.
///
/// The launch check fails open: a network error there is ignored. The 426
/// interceptor is the safety net that catches users who got past the
/// launch check.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _launchCheckStarted = false;
  bool _softShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runLaunchCheck());
  }

  Future<void> _runLaunchCheck() async {
    if (_launchCheckStarted) return;
    _launchCheckStarted = true;

    final result = await getIt<UpdateService>().check();
    if (!mounted) return;

    if (result.isForce) {
      ForceUpdateController.instance.trigger(
        message: result.message,
        updateUrl: result.updateUrl,
      );
    } else if (result.isSoft && !_softShown) {
      _softShown = true;
      // Use the root navigator's context so the dialog isn't bound to a
      // child route that may be replaced (e.g. splash → login).
      showSoftUpdateDialog(
        context,
        message: result.message,
        updateUrl: result.updateUrl,
        latestVersion: result.latestVersion,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ForceUpdateController.instance,
      builder: (context, _) {
        if (ForceUpdateController.instance.isLocked) {
          return ForceUpdatePage(
            message: ForceUpdateController.instance.message,
            updateUrl: ForceUpdateController.instance.updateUrl,
          );
        }
        return widget.child;
      },
    );
  }
}
