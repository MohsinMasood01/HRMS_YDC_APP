import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A modern glassmorphism card widget with blur effect
/// 
/// This widget creates a frosted glass effect that works beautifully
/// over both light and dark backgrounds.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.blurAmount = 20,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurAmount;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Adaptive colors for light/dark mode
    final bgColor = backgroundColor ?? 
        (isDark 
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.75));
    
    final border = borderColor ?? 
        (isDark 
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.5));
    
    final shadow = shadowColor ?? 
        Colors.black.withValues(alpha: isDark ? 0.3 : 0.1);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurAmount,
            sigmaY: blurAmount,
          ),
          child: Container(
            padding: padding ?? EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: border,
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

