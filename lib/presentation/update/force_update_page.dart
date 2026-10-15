import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/services/apk_updater.dart';
import '../../di/service_locator.dart';

/// Non-dismissible full-screen "Update Required" page.
///
/// Wrapped in `PopScope(canPop: false)` so the system back button can't
/// dismiss it, and rendered as an overlay by `UpdateGate` so navigator
/// back-stack tricks can't get behind it either.
///
/// Tapping "Update Now" downloads the signed APK from [updateUrl] (shown
/// with a progress bar in place of the button) and then hands the file to
/// the Android package installer. If the user denies the
/// REQUEST_INSTALL_PACKAGES permission, we deep-link them to the
/// "Install unknown apps" settings page.
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

enum _Phase { idle, downloading, installing, permissionDenied, error }

class _ForceUpdatePageState extends State<ForceUpdatePage> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _errorMessage;

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
          // Installer dialog is now on top of us; leave UI in installing state
          // so the user can return to a sensible screen if they cancel install.
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
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
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
        ),
      ),
    );
  }

  Widget _buildActionArea(ThemeData theme) {
    switch (_phase) {
      case _Phase.downloading:
        return _ProgressBlock(
          progress: _progress,
          label: 'Downloading update… ${(_progress * 100).round()}%',
        );

      case _Phase.installing:
        return _ProgressBlock(
          progress: null,
          label: 'Opening installer…',
        );

      case _Phase.permissionDenied:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'To install the update, allow LMS to install unknown apps in '
              'system settings, then tap Retry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            SizedBox(height: 12.h),
            OutlinedButton(
              onPressed: _openInstallSettings,
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(48.h),
              ),
              child: Text('Open Settings', style: TextStyle(fontSize: 15.sp)),
            ),
            SizedBox(height: 10.h),
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
          icon: const Icon(Icons.download_rounded),
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

/// Shared progress UI used during download (`progress` 0..1) and during the
/// brief installer-launch step (`progress: null` → indeterminate bar).
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.progress, required this.label});

  final double? progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8.h,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.sp),
        ),
      ],
    );
  }
}
