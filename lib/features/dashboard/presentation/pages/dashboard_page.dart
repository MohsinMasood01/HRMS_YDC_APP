import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/designation_formatter.dart';
import '../../../../di/service_locator.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../authentication/presentation/widgets/animated_background.dart';
import '../../../payslips/presentation/pages/payslips_page.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<DashboardBloc>()..add(const DashboardRequested()),
      child: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.loading) {
            return const LoadingIndicator();
          }
          if (state.summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard_outlined,
                    size: 64.sp,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No dashboard data yet',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }
          return AnimatedBackground(
            // imagePath: 'lib/assets/images/login-bgg.jpg',
            imagePath: 'lib/assets/images/bg.png',
            blurAmount: 3.5,
            child: RefreshIndicator(
              onRefresh: () async =>
                  context.read<DashboardBloc>().add(const DashboardRequested()),
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  _WelcomeCard(summary: state.summary!),
                  SizedBox(height: 20.h),
                  _QuickStatsRow(summary: state.summary!),
                  SizedBox(height: 20.h),
                  const _PayslipsTile(),
                  SizedBox(height: 20.h),
                  _SectionHeader(
                    title: 'Leave Balances',
                    icon: Icons.calendar_today_rounded,
                  ),
                  SizedBox(height: 12.h),
                  _LeaveBalanceGrid(summary: state.summary!),
                  SizedBox(height: 20.h),
                  _SectionHeader(
                    title: 'Leave Distribution',
                    icon: Icons.pie_chart_rounded,
                  ),
                  SizedBox(height: 12.h),
                  _LeavePieChart(summary: state.summary!),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 18.sp, color: theme.primaryColor),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

Widget _buildProfileAvatar(
  String? profilePictureUrl,
  String userName,
  bool isDark,
) {
  final initials = userName.isNotEmpty
      ? userName.split(' ').take(2).map((n) => n[0]).join().toUpperCase()
      : 'U';

  return Container(
    width: 56.w,
    height: 56.w,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
    ),
    child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: profilePictureUrl,
              width: 56.w,
              height: 56.w,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.white.withValues(alpha: 0.1),
                child: Center(
                  child: SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        : Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
  );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor.withValues(alpha: isDark ? 0.25 : 0.4),
                theme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.35),
                const Color(0xFF4338CA).withValues(alpha: isDark ? 0.2 : 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildProfileAvatar(
                      summary.profilePictureUrl,
                      summary.userName,
                      isDark,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            summary.userName,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.work_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          '${DesignationFormatter.shortenDesignation(summary.designation)} • ${summary.department}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 16.w,
                  runSpacing: 10.h,
                  children: [
                    _InfoChip(
                      icon: Icons.badge_outlined,
                      label: 'ID',
                      value: summary.employeeCode,
                    ),
                    _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: summary.location,
                    ),
                    _InfoChip(
                      icon: Icons.credit_card_outlined,
                      label: 'Card',
                      value: summary.cardNumber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: Colors.white.withValues(alpha: 0.7)),
        SizedBox(width: 4.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final totalLeaves = summary.balances.fold<int>(
      0,
      (sum, b) => sum + (b.balance < 0 ? 0 : b.balance),
    );

    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            icon: Icons.event_available_rounded,
            label: 'Total Leave',
            value: '$totalLeaves days',
            color: AppColors.success,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _QuickStatCard(
            icon: Icons.trending_up_rounded,
            label: 'Leave Types',
            value: '${summary.balances.length}',
            color: AppColors.info,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _QuickStatCard(
            icon: Icons.star_rounded,
            label: 'Cadre',
            value: summary.cadre,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 18.sp, color: color),
              ),
              SizedBox(height: 10.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens My Payslips. Same frosted-glass card as [_QuickStatCard].
class _PayslipsTile extends StatelessWidget {
  const _PayslipsTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? AppColors.secondary : theme.primaryColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PayslipsPage()),
            ),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 18.sp,
                      color: color,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Payslips',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'View and download your salary slips',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark
                                ? Colors.white54
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveBalanceGrid extends StatelessWidget {
  const _LeaveBalanceGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define colors for different leave types
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.secondary,
      AppColors.accent,
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 1.8, // Adjusted for better fit
      ),
      itemCount: summary.balances.length,
      itemBuilder: (context, index) {
        final balance = summary.balances[index];
        final color = colors[index % colors.length];

        return ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 6.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            balance.code,
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${balance.balance < 0 ? 0 : balance.balance}',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: balance.balance <= 0
                                ? (isDark ? Colors.white38 : Colors.grey)
                                : (isDark ? Colors.white : AppColors.textPrimary),
                            height: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(width: 2.w),
                        Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: Text(
                            'days',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Expanded(
                      child: Text(
                        balance.name,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeavePieChart extends StatelessWidget {
  const _LeavePieChart({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Only show leave types with positive balance in the pie chart
    final positiveBalances = summary.balances.where((b) => b.balance > 0).toList();

    if (positiveBalances.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.all(40.w),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                'No data to display',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.secondary,
      AppColors.accent,
    ];

    final total = positiveBalances.fold<int>(
      0,
      (prev, element) => prev + element.balance,
    );

    final sections = positiveBalances.asMap().entries.map((entry) {
      final index = entry.key;
      final balance = entry.value;
      final value = total == 0 ? 0.0 : balance.balance / total;
      return PieChartSectionData(
        value: value,
        title: '${(value * 100).toStringAsFixed(0)}%',
        titleStyle: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 50.r,
        color: colors[index % colors.length],
      );
    }).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 30,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180.h,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 3,
                    centerSpaceRadius: 40.r,
                    startDegreeOffset: -90,
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Wrap(
                spacing: 16.w,
                runSpacing: 10.h,
                alignment: WrapAlignment.center,
                children: positiveBalances.asMap().entries.map((entry) {
                  final index = entry.key;
                  final balance = entry.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 10.w,
                        width: 10.w,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        '${balance.code}: ${balance.balance}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark
                              ? Colors.white70
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
