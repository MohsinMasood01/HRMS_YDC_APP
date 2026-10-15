import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/face_verification_bloc.dart';

/// Widget to display captured images in a grid with retake functionality
class CapturedImagesGrid extends StatelessWidget {
  const CapturedImagesGrid({
    super.key,
    required this.capturedImages,
    required this.onRetake,
  });

  final List<CapturedImageInfo> capturedImages;
  final Function(int) onRetake;

  @override
  Widget build(BuildContext context) {
    if (capturedImages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 120.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: capturedImages.length,
        itemBuilder: (context, index) {
          final imageInfo = capturedImages[index];
          return _ImageThumbnail(
            imageInfo: imageInfo,
            index: index,
            onRetake: () => onRetake(index),
          );
        },
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.imageInfo,
    required this.index,
    required this.onRetake,
  });

  final CapturedImageInfo imageInfo;
  final int index;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRetake,
      child: Container(
        width: 100.w,
        height: 100.h,
        margin: EdgeInsets.only(right: 12.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: imageInfo.isValid ? AppColors.success : AppColors.error,
            width: 3,
          ),
        ),
        child: Stack(
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(9.r),
              child: Image.file(
                File(imageInfo.imagePath),
                width: 100.w,
                height: 100.h,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade300,
                    child: Icon(
                      Icons.broken_image,
                      size: 40.sp,
                      color: Colors.grey.shade600,
                    ),
                  );
                },
              ),
            ),
            // Status overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9.r),
                  color: imageInfo.isValid
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                ),
              ),
            ),
            // Status icon
            Positioned(
              top: 4.h,
              right: 4.w,
              child: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: imageInfo.isValid
                      ? AppColors.success
                      : AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  imageInfo.isValid ? Icons.check : Icons.close,
                  size: 16.sp,
                  color: Colors.white,
                ),
              ),
            ),
            // Image number
            Positioned(
              bottom: 4.h,
              left: 4.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Retake hint
            if (!imageInfo.isValid)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9.r),
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 24.sp),
                        SizedBox(height: 4.h),
                        Text(
                          'Tap to retake',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
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
    );
  }
}






