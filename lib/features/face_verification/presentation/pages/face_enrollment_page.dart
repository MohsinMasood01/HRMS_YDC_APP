import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../di/service_locator.dart';
import '../bloc/face_verification_bloc.dart';
import '../widgets/camera_preview_widget.dart';

/// Face enrollment page
///
/// Allows users to enroll their face for attendance verification.
/// Captures multiple images and stores only the averaged embedding.
/// If [overrideCardNo] is provided (HR admin flow), it temporarily swaps
/// the stored card_no1 so the bloc enrols the target employee.
class FaceEnrollmentPage extends StatefulWidget {
  const FaceEnrollmentPage({super.key, this.overrideCardNo});

  /// When non-null, enroll this employee instead of the logged-in user.
  final String? overrideCardNo;

  @override
  State<FaceEnrollmentPage> createState() => _FaceEnrollmentPageState();
}

class _FaceEnrollmentPageState extends State<FaceEnrollmentPage> {
  // Cache theme to avoid repeated lookups
  late final ThemeData _theme;
  late final bool _isDark;
  String? _originalCardNo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = Theme.of(context);
    _isDark = _theme.brightness == Brightness.dark;
  }

  Future<void> _swapCardNo() async {
    if (widget.overrideCardNo == null) return;
    final storage = getIt<SecureStorageService>();
    _originalCardNo = await storage.read('card_no1');
    await storage.write('card_no1', widget.overrideCardNo!);
  }

  Future<void> _restoreCardNo() async {
    if (_originalCardNo == null) return;
    final storage = getIt<SecureStorageService>();
    await storage.write('card_no1', _originalCardNo!);
  }

  @override
  void dispose() {
    _restoreCardNo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _swapCardNo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildContent();
      },
    );
  }

  Widget _buildContent() {
    return BlocProvider(
      create: (_) => getIt<FaceVerificationBloc>()
        ..add(const FaceVerificationInitialized())
        ..add(const StartFaceEnrollment()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.overrideCardNo != null
              ? 'Enroll Employee Face'
              : 'Face Enrollment'),
          elevation: 0,
        ),
        body: BlocConsumer<FaceVerificationBloc, FaceVerificationState>(
          listenWhen: (previous, current) {
            // Only listen to status changes and error messages
            return previous.status != current.status ||
                previous.errorMessage != current.errorMessage ||
                previous.successMessage != current.successMessage;
          },
          listener: (context, state) {
            if (state.status == FaceVerificationStatus.enrollmentSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.successMessage ?? 'Face enrolled successfully',
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 3),
                ),
              );
              Navigator.of(context).pop(true);
            } else if (state.errorMessage != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 5),
                  ),
                );
              });
            }
            // Removed snackbar for intermediate messages (too many for 64 frames)
          },
          buildWhen: (previous, current) {
            // Only rebuild when UI-relevant state changes
            return previous.status != current.status ||
                previous.instructionText != current.instructionText ||
                previous.isFaceDetected != current.isFaceDetected;
          },
          builder: (context, state) {
            final bloc = context.read<FaceVerificationBloc>();
            final controller = bloc.cameraController;

            if (state.status == FaceVerificationStatus.initial) {
              return const Center(child: CircularProgressIndicator());
            }

            // Show processing state with instruction overlay
            if (state.status == FaceVerificationStatus.processing) {
              return Stack(
                children: [
                  if (controller != null)
                    SizedBox.expand(child: CameraPreview(controller)),
                  // Instruction overlay
                  if (state.instructionText != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                              SizedBox(height: 24.h),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24.w,
                                  vertical: 16.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Text(
                                  state.instructionText!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Indeterminate progress indicator (no numeric counts)
                              if (state.status ==
                                  FaceVerificationStatus.enrollmentInProgress)
                                Padding(
                                  padding: EdgeInsets.only(top: 16.h),
                                  child: SizedBox(
                                    width: 24.w,
                                    height: 24.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }

            if (controller == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 64.sp,
                      color: _isDark ? Colors.white54 : Colors.grey.shade400,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Initializing camera...',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: _isDark
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Camera preview - takes most of the screen
                Expanded(
                  child: Stack(
                    children: [
                      // Camera preview
                      CameraPreviewWidget(
                        controller: controller,
                        isFaceDetected: state.isFaceDetected,
                        instructionText: _getInstructionText(state),
                        showProgress: false,
                        progress: 0,
                      ),

                      // Instruction overlay with animation
                      if (state.instructionText != null)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Animated icon - use const child for better performance
                                  if (state.status ==
                                      FaceVerificationStatus.processing)
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(seconds: 1),
                                      builder: (context, value, child) {
                                        return Transform.rotate(
                                          angle: value * 2 * 3.14159,
                                          child: child,
                                        );
                                      },
                                      child: Icon(
                                        Icons.face,
                                        size: 80.sp,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.face,
                                      size: 80.sp,
                                      color: Colors.white,
                                    ),
                                  SizedBox(height: 24.h),
                                  // Instruction text
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24.w,
                                      vertical: 16.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                    child: Text(
                                      state.instructionText!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Indeterminate progress indicator (modern UX)
                                  // No numeric counts - just smooth animation
                                  if (state.status ==
                                      FaceVerificationStatus
                                          .enrollmentInProgress)
                                    Padding(
                                      padding: EdgeInsets.only(top: 24.h),
                                      child: SizedBox(
                                        width: 32.w,
                                        height: 32.h,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3.0,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.success,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Removed captured images grid - not needed for burst mode

                // Bottom action buttons
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    color: _isDark ? Colors.grey.shade900 : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Indeterminate progress indicator at bottom (modern UX)
                        if (state.status ==
                            FaceVerificationStatus.enrollmentInProgress)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 16.h,
                            ),
                            decoration: BoxDecoration(
                              color: _isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24.w,
                                  height: 24.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _theme.primaryColor,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                // Status text (no numeric counts) - use Flexible to prevent overflow
                                Flexible(
                                  child: Text(
                                    state.instructionText ??
                                        'Capturing face...',
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: _isDark
                                          ? Colors.white70
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 8.h),

                        // Cancel button
                        TextButton(
                          onPressed: () {
                            bloc.add(const CancelOperation());
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: _isDark
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

  String _getInstructionText(FaceVerificationState state) {
    // Use state instruction text if available, otherwise default
    return state.instructionText ?? 'Position your face in the center';
  }
}




