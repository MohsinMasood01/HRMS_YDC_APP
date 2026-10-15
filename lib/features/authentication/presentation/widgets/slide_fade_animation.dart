import 'package:flutter/material.dart';

/// Direction for slide animation
enum SlideDirection {
  fromBottom,
  fromTop,
  fromLeft,
  fromRight,
}

/// A widget that combines slide and fade animations for smooth entrance effects
/// 
/// Use this to create staggered animations for login form elements
class SlideFadeAnimation extends StatefulWidget {
  const SlideFadeAnimation({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.slideDirection = SlideDirection.fromBottom,
    this.slideOffset = 30.0,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final SlideDirection slideDirection;
  final double slideOffset;

  @override
  State<SlideFadeAnimation> createState() => _SlideFadeAnimationState();
}

class _SlideFadeAnimationState extends State<SlideFadeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    final startOffset = _getStartOffset();
    _slideAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  Offset _getStartOffset() {
    final offset = widget.slideOffset;
    switch (widget.slideDirection) {
      case SlideDirection.fromBottom:
        return Offset(0, offset);
      case SlideDirection.fromTop:
        return Offset(0, -offset);
      case SlideDirection.fromLeft:
        return Offset(-offset, 0);
      case SlideDirection.fromRight:
        return Offset(offset, 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

