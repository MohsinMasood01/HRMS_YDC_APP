import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Face guide overlay widget
///
/// Displays a guide showing where the user should position their face.
/// Shows visual feedback for face positioning (centered, too close, too far).
class FaceGuideOverlay extends StatelessWidget {
  const FaceGuideOverlay({
    super.key,
    required this.isFaceDetected,
    required this.isFacePositioned,
    this.autoCaptureCountdown,
  });

  final bool isFaceDetected;
  final bool isFacePositioned;
  final int? autoCaptureCountdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned.fill(
      child: CustomPaint(
        painter: FaceGuidePainter(
          isFaceDetected: isFaceDetected,
          isFacePositioned: isFacePositioned,
          autoCaptureCountdown: autoCaptureCountdown,
          isDark: isDark,
        ),
        child: Container(),
      ),
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  FaceGuidePainter({
    required this.isFaceDetected,
    required this.isFacePositioned,
    this.autoCaptureCountdown,
    required this.isDark,
  });

  final bool isFaceDetected;
  final bool isFacePositioned;
  final int? autoCaptureCountdown;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate guide oval size (approximately 60% of screen width)
    final guideWidth = size.width * 0.6;
    final guideHeight = size.height * 0.4;
    final guideRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: guideWidth,
      height: guideHeight,
    );

    // Draw dark overlay outside guide area
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(guideRect)
      ..fillType = PathFillType.evenOdd;

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // Draw guide oval border
    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = isFacePositioned
          ? AppColors.success
          : isFaceDetected
          ? Colors.orange
          : Colors.white.withValues(alpha: 0.6);

    // Add dashed effect
    final dashWidth = 8.0;
    final dashSpace = 4.0;
    final path = Path();
    final oval = Path()..addOval(guideRect);

    // Draw dashed oval
    final metrics = oval.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        path.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(path, guidePaint);

    // Draw corner guides for better alignment
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = isFacePositioned
          ? AppColors.success
          : isFaceDetected
          ? Colors.orange
          : Colors.white.withValues(alpha: 0.6);

    // Top-left corner
    canvas.drawLine(
      Offset(guideRect.left, guideRect.top),
      Offset(guideRect.left + cornerLength, guideRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideRect.left, guideRect.top),
      Offset(guideRect.left, guideRect.top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(guideRect.right, guideRect.top),
      Offset(guideRect.right - cornerLength, guideRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideRect.right, guideRect.top),
      Offset(guideRect.right, guideRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(guideRect.left, guideRect.bottom),
      Offset(guideRect.left + cornerLength, guideRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideRect.left, guideRect.bottom),
      Offset(guideRect.left, guideRect.bottom - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(guideRect.right, guideRect.bottom),
      Offset(guideRect.right - cornerLength, guideRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideRect.right, guideRect.bottom),
      Offset(guideRect.right, guideRect.bottom - cornerLength),
      cornerPaint,
    );

    // Draw auto-capture countdown if active
    if (autoCaptureCountdown != null && autoCaptureCountdown! > 0) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$autoCaptureCountdown',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
            shadows: [
              Shadow(
                offset: const Offset(0, 2),
                blurRadius: 4,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, guideRect.top - 80),
      );
    }
  }

  @override
  bool shouldRepaint(FaceGuidePainter oldDelegate) {
    return oldDelegate.isFaceDetected != isFaceDetected ||
        oldDelegate.isFacePositioned != isFacePositioned ||
        oldDelegate.autoCaptureCountdown != autoCaptureCountdown ||
        oldDelegate.isDark != isDark;
  }
}






