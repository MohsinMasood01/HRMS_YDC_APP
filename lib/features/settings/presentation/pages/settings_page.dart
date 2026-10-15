import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_version_service.dart';
import '../../../../di/service_locator.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../../shared/bloc/app_bloc.dart';
import '../cubit/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsCubit>(),
      child: const _SettingsPageContent(),
    );
  }
}

class _SettingsPageContent extends StatelessWidget {
  const _SettingsPageContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (previous, current) {
        // Only rebuild when settings actually change
        return previous.settings != current.settings ||
            previous.isLoading != current.isLoading;
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Appearance Section
            _buildSectionHeader(context, 'Appearance', Icons.palette_outlined),
            SizedBox(height: 12.h),
            _buildThemeCard(context, isDark),

            SizedBox(height: 24.h),

            // Security Section
            _buildSectionHeader(context, 'Security', Icons.security_outlined),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              context,
              children: [
                _buildSwitchTile(
                  context,
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Login',
                  subtitle: 'Use fingerprint or face ID to login',
                  value: state.settings.biometricEnabled,
                  onChanged: (value) =>
                      context.read<SettingsCubit>().toggleBiometric(value),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // Notifications Section
            _buildSectionHeader(
              context,
              'Notifications',
              Icons.notifications_outlined,
            ),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              context,
              children: [
                _buildSwitchTile(
                  context,
                  icon: Icons.notifications_active_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Receive alerts for important updates',
                  value: state.settings.notificationsEnabled,
                  onChanged: (value) =>
                      context.read<SettingsCubit>().toggleNotifications(value),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // About Section
            _buildSectionHeader(context, 'About', Icons.info_outline),
            SizedBox(height: 12.h),
            _buildSettingsCard(
              context,
              children: [
                // Version + build come from the running package (pubspec
                // `version:`), so a release bump shows here automatically
                // instead of a hardcoded string.
                FutureBuilder<List<String>>(
                  future: Future.wait<String>([
                    getIt<AppVersionService>().version(),
                    getIt<AppVersionService>().build().then((b) => '$b'),
                  ]),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData ? snapshot.data![0] : '—';
                    final build = snapshot.hasData ? snapshot.data![1] : '—';
                    return Column(
                      children: [
                        _buildInfoTile(
                          context,
                          icon: Icons.apps_rounded,
                          title: 'App Version',
                          value: version,
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white12
                              : Colors.grey.shade200,
                        ),
                        _buildInfoTile(
                          context,
                          icon: Icons.build_rounded,
                          title: 'Build Number',
                          value: build,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 32.h),

            // Sign Out Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      context.read<AuthBloc>().add(const LogoutRequested()),
                  borderRadius: BorderRadius.circular(16.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20.sp, color: theme.primaryColor),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: theme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeCard(BuildContext context, bool isDark) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, appState) {
        return _buildSettingsCard(
          context,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_6_rounded,
                        size: 22.sp,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Theme',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Choose how the app looks',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // Theme Options
                  Row(
                    children: [
                      _buildThemeOption(
                        context,
                        icon: Icons.brightness_auto_rounded,
                        label: 'System',
                        isSelected: appState.themeMode == ThemeMode.system,
                        onTap: () => context.read<AppBloc>().add(
                          const AppThemeToggled(ThemeMode.system),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      _buildThemeOption(
                        context,
                        icon: Icons.light_mode_rounded,
                        label: 'Light',
                        isSelected: appState.themeMode == ThemeMode.light,
                        onTap: () => context.read<AppBloc>().add(
                          const AppThemeToggled(ThemeMode.light),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      _buildThemeOption(
                        context,
                        icon: Icons.dark_mode_rounded,
                        label: 'Dark',
                        isSelected: appState.themeMode == ThemeMode.dark,
                        onTap: () => context.read<AppBloc>().add(
                          const AppThemeToggled(ThemeMode.dark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.secondary : theme.primaryColor)
                      .withValues(alpha: isDark ? 0.3 : 0.1)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppColors.secondary : theme.primaryColor)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24.sp,
                color: isSelected
                    ? (isDark ? AppColors.secondary : theme.primaryColor)
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              SizedBox(height: 6.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? AppColors.secondary : theme.primaryColor)
                      : (isDark ? Colors.white70 : Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22.sp,
            color: isDark ? Colors.white70 : AppColors.textPrimary,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: isDark ? AppColors.secondary : theme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22.sp,
            color: isDark ? Colors.white70 : AppColors.textPrimary,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
