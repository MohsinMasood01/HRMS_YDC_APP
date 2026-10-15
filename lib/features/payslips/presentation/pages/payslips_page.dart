import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../di/service_locator.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../domain/entities/payslip_summary.dart';
import '../../domain/payslip_exception.dart';
import '../cubit/payslips_cubit.dart';
import '../payslip_session.dart';
import 'payslip_detail_page.dart';

/// "My Payslips": every month HR has finalised for the signed-in employee,
/// newest first, exactly as `GET /auth/payslips/:card_no` returns them.
class PayslipsPage extends StatelessWidget {
  const PayslipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (_) => getIt<PayslipsCubit>()..load(),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : AppColors.backgroundPurple,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: const Text('My Payslips'),
        ),
        body: BlocConsumer<PayslipsCubit, PayslipsState>(
          listenWhen: (previous, current) =>
              current.error?.kind == PayslipErrorKind.session &&
              previous.error?.kind != PayslipErrorKind.session,
          listener: (context, state) => PayslipSession.expire(context),
          builder: (context, state) {
            final cubit = context.read<PayslipsCubit>();
            Future<void> refresh() => cubit.load(refresh: true);

            switch (state.status) {
              case PayslipsStatus.loading:
                return const LoadingIndicator();
              case PayslipsStatus.failure:
                return _MessageView(
                  onRefresh: refresh,
                  icon: state.error?.kind == PayslipErrorKind.notFound
                      ? Icons.receipt_long_outlined
                      : Icons.cloud_off_rounded,
                  message:
                      state.error?.message ??
                      'Could not load your payslips. Please try again.',
                  onRetry: state.error?.kind == PayslipErrorKind.session
                      ? null
                      : cubit.load,
                );
              case PayslipsStatus.success:
                if (state.items.isEmpty) {
                  return _MessageView(
                    onRefresh: refresh,
                    icon: Icons.receipt_long_outlined,
                    message:
                        'No payslips yet. Your payslip appears here once HR '
                        "finalises the month's salary.",
                  );
                }
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16.w),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) =>
                        _PayslipTile(item: state.items[index]),
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

class _PayslipTile extends StatelessWidget {
  const _PayslipTile({required this.item});

  final PayslipSummary item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.secondary : theme.primaryColor;
    final secondaryText = isDark ? Colors.white54 : AppColors.textSecondary;
    final range = PayslipFormat.range(item.periodFrom, item.periodTo);

    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PayslipDetailPage(item: item),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 22.sp,
                      color: primary,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (range.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            range,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Net Payable',
                        style: TextStyle(fontSize: 11.sp, color: secondaryText),
                      ),
                      Text(
                        PayslipFormat.money(item.netPayable),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22.sp,
                    color: secondaryText,
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                'Earnings ${PayslipFormat.money(item.totalEarning)}'
                '  ·  Deductions ${PayslipFormat.money(item.totalDeduction)}',
                style: TextStyle(fontSize: 12.sp, color: secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty / error state. Stays scrollable so pull-to-refresh works on it too.
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.onRefresh,
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final Future<void> Function() onRefresh;
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 64.sp, color: Colors.grey.shade400),
                    SizedBox(height: 16.h),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    if (onRetry != null) ...[
                      SizedBox(height: 16.h),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
