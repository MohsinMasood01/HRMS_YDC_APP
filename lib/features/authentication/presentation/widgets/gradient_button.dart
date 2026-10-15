import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A beautiful gradient button with loading state and animations
/// 
/// Features:
/// - Gradient background
/// - Smooth press animation
/// - Loading spinner
/// - Disabled state
/// - Shadow effects
class GradientButton extends StatefulWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.gradient,
    this.height,
    this.width,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final Gradient? gradient;
  final double? height;
  final double? width;
  final double? borderRadius;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isEnabled && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = !widget.isEnabled || widget.isLoading;
    
    // Default gradient using theme colors
    final defaultGradient = LinearGradient(
      colors: [
        theme.primaryColor,
        theme.primaryColor.withValues(alpha: 0.85),
        const Color(0xFF4338CA), // Indigo accent
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final disabledGradient = LinearGradient(
      colors: [
        Colors.grey.shade400,
        Colors.grey.shade500,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.height ?? 56.h,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            gradient: isDisabled 
                ? disabledGradient 
                : (widget.gradient ?? defaultGradient),
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 16.r),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: _isPressed ? 0.4 : 0.3),
                      blurRadius: _isPressed ? 8 : 16,
                      spreadRadius: 0,
                      offset: Offset(0, _isPressed ? 4 : 8),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius ?? 16.r),
              onTap: null, // Handled by GestureDetector
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        height: 24.h,
                        width: 24.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            SizedBox(width: 10.w),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
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

