import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';

/// Instruction overlay for face verification
///
/// Shows step-by-step instructions during enrollment or verification.
class FaceInstructionOverlay extends StatelessWidget {
  const FaceInstructionOverlay({
    super.key,
    required this.instruction,
    required this.stepNumber,
    required this.totalSteps,
    this.showLivenessHint = false,
  });

  final String instruction;
  final int stepNumber;
  final int totalSteps;
  final bool showLivenessHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalSteps,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < stepNumber
                      ? (isDark ? AppColors.secondary : theme.primaryColor)
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Instruction text
          Text(
            instruction,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (showLivenessHint) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Turn your head slightly left or right',
                    style: TextStyle(fontSize: 12.sp, color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}






