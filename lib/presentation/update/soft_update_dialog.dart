import 'package:flutter/material.dart';

import '../../core/services/apk_updater.dart';
import '../../di/service_locator.dart';

/// Dismissible "A new version is available" prompt.
///
/// Tapping "Update" starts an in-dialog APK download with a progress bar.
/// While downloading the dialog is non-dismissible so the user doesn't
/// accidentally interrupt — once the installer is launched (or an error
/// shows), normal dismissal returns. "Later" is always available before
/// the download starts.
///
/// Returns the future of the underlying `showDialog`. Callers usually
/// fire-and-forget it.
Future<void> showSoftUpdateDialog(
  BuildContext context, {
  required String message,
  required String updateUrl,
  String? latestVersion,
}) {
  final title = latestVersion != null && latestVersion.isNotEmpty
      ? 'New version $latestVersion available'
      : 'A new version is available';
  final body = message.isEmpty
      ? 'An updated version of LMS is available. Update for the latest features and fixes.'
      : message;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _SoftUpdateDialog(
      title: title,
      body: body,
      updateUrl: updateUrl,
    ),
  );
}

enum _Phase { idle, downloading, installing, permissionDenied, error }

class _SoftUpdateDialog extends StatefulWidget {
  const _SoftUpdateDialog({
    required this.title,
    required this.body,
    required this.updateUrl,
  });

  final String title;
  final String body;
  final String updateUrl;

  @override
  State<_SoftUpdateDialog> createState() => _SoftUpdateDialogState();
}

class _SoftUpdateDialogState extends State<_SoftUpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _errorMessage;

  bool get _isWorking =>
      _phase == _Phase.downloading || _phase == _Phase.installing;

  Future<void> _startUpdate() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _errorMessage = null;
    });
    final updater = getIt<ApkUpdater>();
    try {
      final file = await updater.download(
        widget.updateUrl,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.installing);

      final result = await updater.install(file);
      if (!mounted) return;
      switch (result) {
        case ApkInstallStatus.launched:
          // Installer popped — close ourselves so we're not lingering behind it.
          Navigator.of(context).pop();
          break;
        case ApkInstallStatus.permissionDenied:
          setState(() => _phase = _Phase.permissionDenied);
          break;
        case ApkInstallStatus.installerFailed:
          setState(() {
            _phase = _Phase.error;
            _errorMessage =
                'Couldn’t open the installer. Tap retry to try again.';
          });
          break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Download failed. Check your connection and retry.';
      });
    }
  }

  Future<void> _openInstallSettings() async {
    await getIt<ApkUpdater>().openInstallPermissionSettings();
  }

  @override
  Widget build(BuildContext context) {
    // Block back-button dismissal while a download is in flight so a stray
    // back press doesn't abandon a half-completed update.
    return PopScope(
      canPop: !_isWorking,
      child: AlertDialog(
        title: Text(widget.title),
        content: _buildContent(),
        actions: _buildActions(context),
      ),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case _Phase.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.body),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: _progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Text('Downloading… ${(_progress * 100).round()}%'),
          ],
        );
      case _Phase.installing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            LinearProgressIndicator(minHeight: 8),
            SizedBox(height: 8),
            Text('Opening installer…'),
          ],
        );
      case _Phase.permissionDenied:
        return const Text(
          'To install the update, allow LMS to install unknown apps in '
          'system settings, then tap Retry.',
        );
      case _Phase.error:
        return Text(
          _errorMessage ?? 'Something went wrong.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      case _Phase.idle:
        return Text(widget.body);
    }
  }

  List<Widget> _buildActions(BuildContext ctx) {
    switch (_phase) {
      case _Phase.idle:
        return [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: _startUpdate,
            child: const Text('Update'),
          ),
        ];
      case _Phase.downloading:
      case _Phase.installing:
        // Single non-interactive disabled button keeps the dialog footer
        // stable while work is in flight.
        return [
          TextButton(
            onPressed: null,
            child: const Text('Please wait…'),
          ),
        ];
      case _Phase.permissionDenied:
        return [
          TextButton(
            onPressed: _openInstallSettings,
            child: const Text('Open Settings'),
          ),
          FilledButton(
            onPressed: _startUpdate,
            child: const Text('Retry'),
          ),
        ];
      case _Phase.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: _startUpdate,
            child: const Text('Retry'),
          ),
        ];
    }
  }
}
