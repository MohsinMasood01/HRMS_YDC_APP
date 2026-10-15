import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/location_tracking_service.dart';
import '../../di/service_locator.dart';
import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/leaves/presentation/pages/leave_page.dart';
import '../../features/payslips/presentation/payslip_session.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardPage(),
    AttendancePage(),
    LeavePage(),
    ProfilePage(),
    SettingsPage(),
  ];

  final _titles = const [
    'Dashboard',
    'Attendance',
    'Leave',
    'Profile',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    // Back from a "session expired" sign-in that started on My Payslips:
    // take the employee straight back there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PayslipSession.resumeIfPending(context);
    });
  }

  /// Signs out after a confirmation.
  ///
  /// The confirmation matters because this button sits in the header, where
  /// it is easy to hit by accident, and signing out also ends location
  /// tracking for the current work session (see AuthBloc's logout handler).
  /// The warning about tracking is shown only when a session is running.
  Future<void> _confirmSignOut(BuildContext context) async {
    final tracking = await getIt<LocationTrackingService>().isTracking;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text('Sign out?'),
        content: Text(
          tracking
              ? 'Location tracking for your current work session will stop. '
                    'You will need to sign in again to use the app.'
              : 'You will need to sign in again to use the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    // Navigation back to login is handled by the app-level AuthBloc listener
    // reacting to AuthStatus.unauthenticated, exactly as for Settings > Sign
    // Out.
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : AppColors.backgroundPurple,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    isDark ? AppColors.secondary : theme.primaryColor,
                    (isDark ? AppColors.secondary : theme.primaryColor)
                        .withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.timelapse_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),

            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Management System',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  _titles[_currentIndex],
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8.w),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Sign out',
              icon: Icon(
                Icons.logout_rounded,
                // Same red as the Sign Out button in Settings.
                color: isDark ? Colors.red.shade300 : Colors.red.shade600,
                size: 22.sp,
              ),
              onPressed: () => _confirmSignOut(context),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 20.r,
              offset: Offset(0, -5.r),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  icon: Icons.access_time_outlined,
                  activeIcon: Icons.access_time_filled,
                  label: 'Attendance',
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  icon: Icons.beach_access_outlined,
                  activeIcon: Icons.beach_access,
                  label: 'Leave',
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                ),
                _buildNavItem(
                  context,
                  index: 4,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.w : 12.w,
          vertical: 8.h,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24.sp,
              color: isSelected
                  ? (isDark ? AppColors.secondary : theme.primaryColor)
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.secondary : theme.primaryColor)
                    : (isDark ? Colors.white60 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
