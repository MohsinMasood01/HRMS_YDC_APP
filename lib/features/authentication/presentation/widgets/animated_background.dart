import 'dart:ui';
import 'package:flutter/material.dart';

/// An animated background widget with image and gradient overlay
/// 
/// Features:
/// - Background image with blur effect
/// - Gradient overlay for contrast
/// - Support for dark mode
/// - Customizable overlay colors
class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({
    required this.child,
    super.key,
    this.imagePath,
    this.blurAmount = 3.0,
    this.overlayGradient,
    this.overlayColor,
  });

  final Widget child;
  final String? imagePath;
  final double blurAmount;
  final Gradient? overlayGradient;
  final Color? overlayColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Default gradient overlay
    final defaultGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.95),
            ]
          : [
              Colors.black.withValues(alpha: 0.15),
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.55),
            ],
      stops: const [0.0, 0.5, 1.0],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        if (imagePath != null)
          Image.asset(
            imagePath!,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              // Fallback gradient if image doesn't load
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF1A1A2E),
                            const Color(0xFF16213E),
                            const Color(0xFF0F3460),
                          ]
                        : [
                            const Color(0xFF667eea),
                            const Color(0xFF764ba2),
                            const Color(0xFFf093fb),
                          ],
                  ),
                ),
              );
            },
          )
        else
          // Default gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1A2E),
                        const Color(0xFF16213E),
                        const Color(0xFF0F3460),
                      ]
                    : [
                        const Color(0xFF667eea),
                        const Color(0xFF764ba2),
                        const Color(0xFFf093fb),
                      ],
              ),
            ),
          ),

        // Blur effect on background
        if (imagePath != null && blurAmount > 0)
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurAmount,
              sigmaY: blurAmount,
            ),
            child: Container(
              color: Colors.transparent,
            ),
          ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: overlayGradient ?? defaultGradient,
          ),
        ),

        // Additional color overlay if specified
        if (overlayColor != null)
          Container(
            color: overlayColor,
          ),

        // Content
        child,
      ],
    );
  }
}

