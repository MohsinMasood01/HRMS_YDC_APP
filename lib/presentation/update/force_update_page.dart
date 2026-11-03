import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/services/apk_updater.dart';
import '../../di/service_locator.dart';
import '../../core/widgets/responsive.dart';

/// Non-dismissible full-screen "Update Required" page.
///
/// Wrapped in `PopScope(canPop: false)` so the system back button can't
/// dismiss it, and rendered as an overlay by `UpdateGate` so navigator
/// back-stack tricks can't get behind it either.
///
/// Tapping "Update Now" opens the app's store listing (Google Play / App
/// Store). The page stays up until the store update is installed and the
/// version check passes; a non-store `update_url` from the backend is
/// replaced with the store listing (see [ApkUpdater.openStore]).
class ForceUpdatePage extends StatefulWidget {
  const ForceUpdatePage({
    super.key,
    required this.message,
    required this.updateUrl,
  });

  final String message;
  final String updateUrl;

  @override
  State<ForceUpdatePage> createState() => _ForceUpdatePageState();
}

enum _Phase { idle, error }

class _ForceUpdatePageState extends State<ForceUpdatePage> {
  _Phase _phase = _Phase.idle;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    // Stay on this page: the app remains blocked until the store update is
    // installed and the version check passes.
    final opened = await getIt<ApkUpdater>().openStore(widget.updateUrl);
    if (!mounted) return;
    setState(() {
      _phase = opened ? _Phase.idle : _Phase.error;
      _errorMessage =
          opened ? null : 'Couldn’t open the store. Tap retry to try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: ResponsiveBody(child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 96.w,
                    height: 96.w,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      size: 52.sp,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Update Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  widget.message.isEmpty
                      ? 'A newer version of LMS is required to continue.'
                      : widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                const Spacer(),
                _buildActionArea(theme),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildActionArea(ThemeData theme) {
    switch (_phase) {
      case _Phase.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.colorScheme.error,
              ),
            ),
            SizedBox(height: 12.h),
            FilledButton.icon(
              onPressed: _startUpdate,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry', style: TextStyle(fontSize: 16.sp)),
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(52.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ],
        );

      case _Phase.idle:
        return FilledButton.icon(
          onPressed: _startUpdate,
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(
            'Update Now',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(52.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
        );
    }
  }
}
