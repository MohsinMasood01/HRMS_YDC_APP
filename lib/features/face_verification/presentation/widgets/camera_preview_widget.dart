import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';

/// Camera preview widget for face capture
///
/// Displays camera feed with face detection overlay.
/// Shows instructions and face detection status.
class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.isFaceDetected,
    required this.instructionText,
    this.showProgress = false,
    this.progress = 0.0,
  });

  final CameraController controller;
  final bool isFaceDetected;
  final String instructionText;
  final bool showProgress;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview - CameraPreview handles its own lifecycle
        SizedBox.expand(child: CameraPreview(controller)),

        // Face detection overlay - only rebuilds when isFaceDetected changes
        if (isFaceDetected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.success, width: 3.w),
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
          ),

        // Note: Instruction overlay removed to avoid overlap with buttons
        // Instructions are shown in the top overlay instead
      ],
    );
  }
}




