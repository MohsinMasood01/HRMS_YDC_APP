import 'package:flutter/material.dart';

import '../../core/services/apk_updater.dart';
import '../../di/service_locator.dart';

/// Dismissible "A new version is available" prompt.
///
/// Tapping "Update" opens the app's store listing (Google Play / App Store)
/// and closes the dialog; "Later" dismisses it. A non-store `update_url` from
/// the backend is replaced with the store listing (see
/// [ApkUpdater.openStore]).
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

enum _Phase { idle, error }

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
  String? _errorMessage;

  Future<void> _startUpdate() async {
    final opened = await getIt<ApkUpdater>().openStore(widget.updateUrl);
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Couldn’t open the store. Tap retry to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: _buildContent(),
      actions: _buildActions(context),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
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
