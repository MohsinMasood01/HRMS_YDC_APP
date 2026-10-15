import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../di/service_locator.dart';
import '../bloc/face_verification_bloc.dart';
import '../widgets/camera_preview_widget.dart';

/// Face verification page
///
/// Verifies user's face against enrolled face for attendance marking.
/// Shows verification result and similarity score.
class FaceVerificationPage extends StatelessWidget {
  const FaceVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider(
      create: (_) => getIt<FaceVerificationBloc>()
        ..add(const FaceVerificationInitialized())
        ..add(const StartFaceVerification()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Face Verification'), elevation: 0),
        body: BlocConsumer<FaceVerificationBloc, FaceVerificationState>(
          listener: (context, state) {
            if (state.status == FaceVerificationStatus.verificationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.successMessage ?? 'Face verified successfully',
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
              // Return verification result to caller
              Navigator.of(context).pop(true);
            } else if (state.status ==
                FaceVerificationStatus.verificationFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage ?? 'Face verification failed',
                  ),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (state.status == FaceVerificationStatus.error &&
                state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          builder: (context, state) {
            final bloc = context.read<FaceVerificationBloc>();
            final controller = bloc.cameraController;

            if (state.status == FaceVerificationStatus.initial ||
                state.status == FaceVerificationStatus.processing) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 64.sp,
                      color: isDark ? Colors.white54 : Colors.grey.shade400,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show result screen if verification completed
            if (state.status == FaceVerificationStatus.verificationSuccess ||
                state.status == FaceVerificationStatus.verificationFailure) {
              return _buildResultScreen(context, state, isDark, theme);
            }

            return Stack(
              children: [
                // Camera preview
                CameraPreviewWidget(
                  controller: controller,
                  isFaceDetected: state.isFaceDetected,
                  instructionText: state.isFaceDetected
                      ? 'Face detected. Tap verify to continue.'
                      : 'Center your face in the frame',
                ),

                // Bottom action buttons
                Positioned(
                  bottom: 40.h,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Verify button
                        ElevatedButton.icon(
                          onPressed: state.isFaceDetected
                              ? () {
                                  bloc.add(const VerifyFace());
                                }
                              : null,
                          icon: Icon(Icons.verified_user, size: 20.sp),
                          label: Text(
                            'Verify Face',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: 16.h,
                              horizontal: 24.w,
                            ),
                            backgroundColor: state.isFaceDetected
                                ? (isDark
                                      ? AppColors.secondary
                                      : theme.primaryColor)
                                : Colors.grey.shade300,
                            foregroundColor: state.isFaceDetected
                                ? Colors.white
                                : Colors.grey.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // Cancel button
                        TextButton(
                          onPressed: () {
                            bloc.add(const CancelOperation());
                            Navigator.of(context).pop(false);
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultScreen(
    BuildContext context,
    FaceVerificationState state,
    bool isDark,
    ThemeData theme,
  ) {
    final isSuccess =
        state.status == FaceVerificationStatus.verificationSuccess;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.cancel,
              size: 80.sp,
              color: isSuccess ? AppColors.success : AppColors.error,
            ),
            SizedBox(height: 24.h),
            Text(
              isSuccess ? 'Face Verified' : 'Verification Failed',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            if (state.similarityScore != null) ...[
              Text(
                'Similarity: ${(state.similarityScore! * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 8.h),
            ],
            Text(
              state.errorMessage ?? state.successMessage ?? '',
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(isSuccess);
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 32.w),
                backgroundColor: isDark
                    ? AppColors.secondary
                    : theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}






