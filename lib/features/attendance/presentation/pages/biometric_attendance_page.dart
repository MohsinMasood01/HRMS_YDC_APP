import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
// tracelet_doctor is a dev_dependency (excluded from release builds by
// Flutter's own tooling). Every reference to it below is ALSO guarded by
// kDebugMode, so this import and the code that uses it are tree-shaken out
// of release builds twice over -- see the long-press handler on
// _TodayStatusCard.
import 'package:tracelet_doctor/tracelet_doctor.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/tracelet_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../di/service_locator.dart';
import '../bloc/biometric_attendance_bloc.dart';

class BiometricAttendancePage extends StatelessWidget {
  const BiometricAttendancePage({super.key});

  /// Prompt at most once per app run so a missing grant is surfaced without
  /// nagging on every check-in.
  static bool _backgroundPromptShown = false;

  /// After a check-in that started tracking, verify the app can actually
  /// capture location in the background.
  ///
  /// While-in-use permission is enough to open the attendance screen but NOT
  /// enough for scheduled capture once the app is minimised -- Android 11+
  /// will not even prompt for the upgrade, so without this the tracking would
  /// simply produce nothing and nobody would know why.
  Future<void> _maybePromptBackgroundLocation(BuildContext context) async {
    if (_backgroundPromptShown) return;

    // Only relevant when HR actually has tracking switched on for this user.
    final isTracking = await getIt<LocationTrackingService>().isTracking;
    if (!isTracking) return;

    final permissions = getIt<PermissionService>();
    if (await permissions.isBackgroundLocationGranted()) return;

    final result = await permissions.requestBackgroundLocation();
    if (result.isUsable) return;

    _backgroundPromptShown = true;
    if (!context.mounted) return;

    final openSettings = await PermissionService.showPermissionDialog(
      context,
      title: 'Allow location all the time',
      message:
          'Your work session is being tracked. For it to keep recording while '
          'the app is closed or your screen is locked, set location access to '
          '"Allow all the time" in app settings.',
      settingsButtonText: 'Open Settings',
      cancelButtonText: 'Not now',
    );
    if (openSettings) await permissions.openSettings();
  }

  static bool _batteryPromptShown = false;
  static const String _batteryPromptAckKey = 'battery_restrictions_prompt_ack';

  /// After a check-in that started tracking, make sure the phone's own battery
  /// management will not kill it.
  ///
  /// Seen in production: on Xiaomi phones hourly capture never ran after
  /// check-in. Xiaomi/Oppo/Vivo/Huawei kill background work unless Autostart
  /// is on and battery saver is set to "No restrictions", and neither setting
  /// can be changed by the app itself -- only the user can, so we explain and
  /// open the right screen.
  ///
  /// Shown once per app run while the app is still battery-optimised (which
  /// is detectable). If the app is already exempt, it is shown only once ever,
  /// for the Autostart part, which Android gives no way to read back.
  Future<void> _maybePromptBatteryRestrictions(BuildContext context) async {
    if (_batteryPromptShown || !Platform.isAndroid) return;
    if (!await getIt<LocationTrackingService>().isTracking) return;

    final tracelet = getIt<TraceletService>();
    final Map<String, Object?> health;
    try {
      health = await tracelet.batteryHealth();
    } catch (_) {
      return;
    }
    if (health['isAggressiveOem'] != true) return;

    final exempt = health['isIgnoringBatteryOptimizations'] == true;
    final prefs = await SharedPreferences.getInstance();
    if (exempt && (prefs.getBool(_batteryPromptAckKey) ?? false)) return;

    _batteryPromptShown = true;
    if (!context.mounted) return;

    final brand = (health['manufacturer']?.toString() ?? 'this phone').trim();
    final openSettings = await PermissionService.showPermissionDialog(
      context,
      title: 'Keep work tracking running',
      message:
          '$brand phones can stop location tracking when the app is closed. '
          'On the next screen please:\n\n'
          '• turn ON Autostart for LMS\n'
          '• set Battery saver to "No restrictions"\n\n'
          'Without this, your location may not be recorded during your shift.',
      settingsButtonText: 'Open Settings',
      cancelButtonText: 'Not now',
    );
    if (!openSettings) return;
    await prefs.setBool(_batteryPromptAckKey, true);
    await tracelet.openBatterySettings();
  }

  Future<void> _onMarkAttendance(BuildContext context, String type) async {
    final bloc = context.read<BiometricAttendanceBloc>();

    // Checking out must be a deliberate choice, never a side effect of tapping
    // the button a second time: the server converts a repeat punch into a
    // check-out once an hour has passed, which is how employees ended up with
    // 60–150 minute "work days". Confirm before sending.
    if (type == 'check_out') {
      final confirmed = await _confirmCheckOut(
        context,
        checkInTime: bloc.state.todayCheckInTime,
      );
      if (!confirmed) return;
      if (!context.mounted) return;
    }

    bloc.add(BiometricAttendanceTypeChanged(type));
    bloc.add(const BiometricAttendanceMarkRequested());
  }

  /// Confirm sheet shown before any punch that would check the employee out.
  /// [checkInTime] comes from the check-in the server confirmed, so the sheet
  /// states a fact rather than a guess.
  Future<bool> _confirmCheckOut(
    BuildContext context, {
    String? checkInTime,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Check out now?',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                (checkInTime != null && checkInTime.isNotEmpty)
                    ? 'You checked in at $checkInTime. Checking out ends your '
                        'work session for now.'
                    : 'Checking out ends your work session for now.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 22.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text('Cancel', style: TextStyle(fontSize: 15.sp)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Check out',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Dismissing the sheet is a cancel: nothing is sent.
    return result ?? false;
  }

  void _showSuccessDialog(
    BuildContext context,
    String message, {
    required bool hrSyncPending,
    String? action,
    DateTime? markedAt,
  }) {
    // What happened comes from the server's `action`; the message text is only
    // a fallback for a backend that does not report it.
    final serverAction = action?.toLowerCase().trim();
    final isNoop = serverAction == 'noop';
    final isCheckOut = serverAction == 'check_out' ||
        (serverAction == null &&
            (message.toLowerCase().contains('check-out') ||
                message.toLowerCase().contains('checked out')));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // The HR-sync note needs to be read, so it stays up longer.
        Future.delayed(
          Duration(seconds: hrSyncPending ? 8 : 3),
          () {
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
        );
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isNoop
                        ? Icons.info_rounded
                        : Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 56.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  isNoop
                      ? (isCheckOut
                          ? 'Already Checked Out'
                          : 'Already Checked In')
                      : (isCheckOut
                          ? 'Successfully Checked Out!'
                          : 'Successfully Checked In!'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  // The server's timestamp for the punch, not the phone clock.
                  DateFormatter.formatTime(markedAt ?? DateTime.now()),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : AppColors.textSecondary,
                  ),
                ),
                // Saved, but the ERP roster did not take it. Deliberately a
                // note on a SUCCESS screen: the punch is fine, and the
                // employee should raise it with HR today rather than discover
                // it at month-end.
                if (hrSyncPending) ...[
                  SizedBox(height: 14.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16.sp,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Attendance saved. HR sync pending — please '
                            'confirm with HR if today shows as absent.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text('OK', style: TextStyle(fontSize: 16.sp)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_rounded,
                  color: AppColors.error,
                  size: 56.sp,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Attendance Failed',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text('OK', style: TextStyle(fontSize: 16.sp)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Biometric Attendance'), elevation: 0),
      body: BlocConsumer<BiometricAttendanceBloc, BiometricAttendanceState>(
        listenWhen: (previous, current) {
          // Only listen to status and message changes
          return previous.status != current.status ||
              previous.successMessage != current.successMessage ||
              previous.errorMessage != current.errorMessage;
        },
        listener: (context, state) {
          if (state.status == BiometricAttendanceStatus.success &&
              state.successMessage != null) {
            _showSuccessDialog(
              context,
              state.successMessage!,
              hrSyncPending: state.hrSyncPending,
              action: state.markedAction,
              markedAt: state.markedAt,
            );
            // The success dialog self-dismisses after 3s; wait for it so the
            // permission guidance is not stacked on top of it.
            Future.delayed(const Duration(milliseconds: 3200), () async {
              if (!context.mounted) return;
              await _maybePromptBackgroundLocation(context);
              if (context.mounted) await _maybePromptBatteryRestrictions(context);
            });
          } else if ((state.status == BiometricAttendanceStatus.error ||
                  state.status == BiometricAttendanceStatus.faceNotRegistered ||
                  state.status ==
                      BiometricAttendanceStatus.faceVerificationFailed) &&
              state.errorMessage != null) {
            _showErrorDialog(context, state.errorMessage!);
          } else if (state.status ==
                  BiometricAttendanceStatus.faceVerificationFailed &&
              state.faceVerificationMessage != null) {
            _showErrorDialog(context, state.faceVerificationMessage!);
          }
        },
        buildWhen: (previous, current) {
          // Only rebuild when UI-relevant state changes
          return previous.status != current.status ||
              previous.isLocationServiceEnabled !=
                  current.isLocationServiceEnabled ||
              previous.locationInfo != current.locationInfo ||
              previous.errorMessage != current.errorMessage;
        },
        builder: (context, state) {
          // Show loading for initial states
          if (state.status == BiometricAttendanceStatus.checkingFaceStatus ||
              state.status == BiometricAttendanceStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          // Show error for face not registered
          if (state.status == BiometricAttendanceStatus.faceNotRegistered) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.0.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.face_unlock_outlined,
                      size: 64.sp,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Face Not Registered',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      state.errorMessage ??
                          'Please register your face first before marking attendance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Location Service Warning
                if (!state.isLocationServiceEnabled) ...[
                  _LocationServiceWarning(isDark: isDark, theme: theme),
                  SizedBox(height: 16.h),
                ],

                // Today's Status Card
                _TodayStatusCard(state: state, isDark: isDark, theme: theme),
                SizedBox(height: 16.h),

                // Location Information Card
                _LocationInfoCard(state: state, isDark: isDark, theme: theme),
                SizedBox(height: 24.h),

                // Action Buttons
                if (state.status ==
                        BiometricAttendanceStatus.capturingFaceFrames ||
                    state.status == BiometricAttendanceStatus.verifyingFace ||
                    state.status == BiometricAttendanceStatus.markingAttendance)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          if (state.status ==
                              BiometricAttendanceStatus.capturingFaceFrames)
                            Padding(
                              padding: EdgeInsets.only(top: 16.h),
                              child: Text(
                                'Capturing frames: ${state.capturedFramesCount}/${state.totalFramesToCapture}',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            )
                          else if (state.status ==
                              BiometricAttendanceStatus.verifyingFace)
                            Padding(
                              padding: EdgeInsets.only(top: 16.h),
                              child: Text(
                                'Verifying face...',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            )
                          else if (state.status ==
                              BiometricAttendanceStatus.markingAttendance)
                            Padding(
                              padding: EdgeInsets.only(top: 16.h),
                              child: Text(
                                'Marking attendance...',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  _ActionButtons(
                    state: state,
                    onMarkAttendance: _onMarkAttendance,
                    isDark: isDark,
                    theme: theme,
                  ),

                // Error Message Display
                if (state.errorMessage != null &&
                    state.status != BiometricAttendanceStatus.error &&
                    state.status !=
                        BiometricAttendanceStatus.faceNotRegistered &&
                    state.status !=
                        BiometricAttendanceStatus.faceVerificationFailed) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: AppColors.error,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  const _TodayStatusCard({
    required this.state,
    required this.isDark,
    required this.theme,
  });

  final BiometricAttendanceState state;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: kDebugMode ? () => TraceletDoctor.show(context) : null,
      child: Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.secondary : theme.primaryColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: isDark ? AppColors.secondary : theme.primaryColor,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Status',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      DateFormatter.formatDate(DateTime.now()),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.white60
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    state,
                    isDark,
                    theme,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  state.todayStatusText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(state, isDark, theme),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: _StatusItem(
                  icon: Icons.login_rounded,
                  label: 'Check In',
                  value: state.todayCheckInTime ?? '--',
                  color: state.hasCheckedInToday
                      ? AppColors.success
                      : Colors.grey,
                  isDark: isDark,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _StatusItem(
                  icon: Icons.logout_rounded,
                  label: 'Check Out',
                  value: state.todayCheckOutTime ?? '--',
                  color: state.hasCheckedOutToday
                      ? AppColors.error
                      : Colors.grey,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (!state.todayFromServer &&
              (state.hasCheckedInToday || state.hasCheckedOutToday)) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.warning,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Not yet confirmed with the server',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (state.markedAt != null) ...[
            SizedBox(height: 16.h),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Last marked: ${DateFormatter.formatDateTime(state.markedAt!)}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  Color _getStatusColor(
    BiometricAttendanceState state,
    bool isDark,
    ThemeData theme,
  ) {
    if (state.hasCheckedOutToday && !state.hasCheckedInToday) {
      return AppColors.warning;
    } else if (state.hasCheckedOutToday) {
      return AppColors.success;
    } else if (state.hasCheckedInToday) {
      return AppColors.warning;
    }
    return isDark ? AppColors.secondary : theme.primaryColor;
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16.sp, color: color),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: color == Colors.grey
                ? (isDark ? Colors.white38 : Colors.grey.shade400)
                : color,
          ),
        ),
      ],
    );
  }
}

class _LocationInfoCard extends StatelessWidget {
  const _LocationInfoCard({
    required this.state,
    required this.isDark,
    required this.theme,
  });

  final BiometricAttendanceState state;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.secondary : theme.primaryColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: isDark ? AppColors.secondary : theme.primaryColor,
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Information',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    if (state.isLoadingLocation)
                      Text(
                        'Fetching location...',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark
                              ? Colors.white60
                              : AppColors.textSecondary,
                        ),
                      )
                    else if (state.locationError != null)
                      Text(
                        'Location error',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.error,
                        ),
                      )
                    else
                      Text(
                        'Current location',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark
                              ? Colors.white60
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (state.isLoadingLocation)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: const CircularProgressIndicator(),
              ),
            )
          else if (state.locationError != null)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      state.locationError!,
                      style: TextStyle(color: AppColors.error, fontSize: 12.sp),
                    ),
                  ),
                ],
              ),
            )
          else if (state.locationInfo != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coordinates
                _LocationDetailItem(
                  icon: Icons.my_location_rounded,
                  label: 'Coordinates',
                  value:
                      '${state.locationInfo!.latitude.toStringAsFixed(6)}, ${state.locationInfo!.longitude.toStringAsFixed(6)}',
                  isDark: isDark,
                ),
                SizedBox(height: 12.h),

                // Accuracy
                _LocationDetailItem(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Accuracy',
                  value:
                      '${state.locationInfo!.accuracy.toStringAsFixed(1)} meters',
                  isDark: isDark,
                ),
                SizedBox(height: 12.h),

                // Address
                if (state.locationInfo!.formattedAddress != null &&
                    state.locationInfo!.formattedAddress!.isNotEmpty) ...[
                  _LocationDetailItem(
                    icon: Icons.home_rounded,
                    label: 'Address',
                    value: state.locationInfo!.formattedAddress!,
                    isDark: isDark,
                    isMultiline: true,
                  ),
                  SizedBox(height: 12.h),
                ],

                // Nearest Landmark
                if (state.locationInfo!.nearestLandmark != null &&
                    state.locationInfo!.nearestLandmark!.isNotEmpty) ...[
                  _LocationDetailItem(
                    icon: Icons.place_rounded,
                    label: 'Nearest Landmark',
                    value: state.locationInfo!.nearestLandmark!,
                    isDark: isDark,
                    highlight: true,
                  ),
                  if (state.locationInfo!.distanceToLandmark != null) ...[
                    SizedBox(height: 4.h),
                    Padding(
                      padding: EdgeInsets.only(left: 28.w),
                      child: Text(
                        '${state.locationInfo!.distanceToLandmark!.toStringAsFixed(0)} meters away',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 12.h),
                ],

                // Famous Place
                if (state.locationInfo!.famousPlace != null &&
                    state.locationInfo!.famousPlace!.isNotEmpty) ...[
                  _LocationDetailItem(
                    icon: Icons.star_rounded,
                    label: 'Famous Place',
                    value: state.locationInfo!.famousPlace!,
                    isDark: isDark,
                  ),
                  SizedBox(height: 12.h),
                ],

                // Area/City
                if (state.locationInfo!.subLocality != null ||
                    state.locationInfo!.locality != null) ...[
                  _LocationDetailItem(
                    icon: Icons.location_city_rounded,
                    label: 'Area',
                    value: [
                      state.locationInfo!.subLocality,
                      state.locationInfo!.locality,
                    ].where((e) => e != null && e.isNotEmpty).join(', '),
                    isDark: isDark,
                  ),
                ],
              ],
            )
          else
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Location information not available',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationDetailItem extends StatelessWidget {
  const _LocationDetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.isMultiline = false,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool isMultiline;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18.sp,
          color: highlight
              ? (isDark ? AppColors.secondary : theme.primaryColor)
              : (isDark ? Colors.white54 : AppColors.textSecondary),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: highlight
                      ? (isDark ? AppColors.secondary : theme.primaryColor)
                      : (isDark ? Colors.white : AppColors.textPrimary),
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationServiceWarning extends StatelessWidget {
  const _LocationServiceWarning({required this.isDark, required this.theme});

  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_off_rounded,
                color: AppColors.warning,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Location Services Disabled',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Please turn on your mobile location or GPS to mark attendance.',
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<BiometricAttendanceBloc>().add(
                  const BiometricAttendanceOpenLocationSettings(),
                );
              },
              icon: Icon(Icons.settings_rounded, size: 18.sp),
              label: Text(
                'Open Location Settings',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.state,
    required this.onMarkAttendance,
    required this.isDark,
    required this.theme,
  });

  final BiometricAttendanceState state;
  final Function(BuildContext, String) onMarkAttendance;
  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isLocationEnabled = state.isLocationServiceEnabled;

    // Determine which action to show
    final isComplete = state.hasCheckedInToday && state.hasCheckedOutToday;
    final needsCheckOut = state.hasCheckedInToday && !state.hasCheckedOutToday;
    final needsCheckIn = !state.hasCheckedInToday;

    final canAct = isLocationEnabled && state.canMarkAttendance;

    void showLocationSnack() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please turn on your mobile GPS / location services.',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () {
              context.read<BiometricAttendanceBloc>().add(
                const BiometricAttendanceOpenLocationSettings(),
              );
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Single smart action button ----
        if (isComplete)
          _DoneCard(isDark: isDark, theme: theme)
        else if (needsCheckOut)
          ElevatedButton.icon(
            onPressed: canAct
                ? () => onMarkAttendance(context, 'check_out')
                : showLocationSnack,
            icon: Icon(Icons.logout_rounded, size: 22.sp),
            label: Text(
              'Check Out',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 18.h),
              backgroundColor: canAct ? AppColors.error : Colors.grey.shade300,
              foregroundColor: canAct ? Colors.white : Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              elevation: canAct ? 4 : 0,
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: canAct
                ? () => onMarkAttendance(context, 'check_in')
                : showLocationSnack,
            icon: Icon(Icons.login_rounded, size: 22.sp),
            label: Text(
              needsCheckIn ? 'Check In' : 'Mark Attendance',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 18.h),
              backgroundColor:
                  canAct ? AppColors.success : Colors.grey.shade300,
              foregroundColor: canAct ? Colors.white : Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
              elevation: canAct ? 4 : 0,
            ),
          ),

        // Info hint
        if (!isComplete) ...[
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.secondary : theme.primaryColor)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 16.sp,
                  color: isDark ? AppColors.secondary : theme.primaryColor,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    needsCheckOut
                        ? 'Face scan required to check out'
                        : 'Face scan required to check in',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color:
                          isDark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.isDark, required this.theme});

  final bool isDark;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 28.sp),
          SizedBox(width: 12.w),
          Text(
            'Attendance Complete for Today',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
