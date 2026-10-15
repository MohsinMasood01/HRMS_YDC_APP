import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/services/app_version_service.dart';
import '../../core/services/permission_service.dart';
import '../../di/service_locator.dart';

/// A beautiful animated splash screen with rotating logo
///
/// Features:
/// - Full-screen background image with blur overlay
/// - Continuously rotating/spinning logo with glow effects
/// - 3D flip animation on the logo
/// - Smooth entrance animations
/// - Responsive design for all screen sizes
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // Rotation animation controller
  late AnimationController _rotationController;

  // Pulse/glow animation controller
  late AnimationController _pulseController;

  // Scale entrance animation controller
  late AnimationController _entranceController;

  // 3D flip animation controller
  late AnimationController _flipController;

  // Loading indicator pulse
  late AnimationController _loadingController;

  late Animation<double> _entranceScaleAnimation;
  late Animation<double> _entranceFadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();

    // Continuous rotation controller - spins forever
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Pulse animation for glow effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 3D flip effect
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Loading indicator
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Entrance scale animation
    _entranceScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    // Entrance fade animation
    _entranceFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Pulse animation for scale
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Glow animation
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3D flip animation (subtle)
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _flipController, curve: Curves.linear));

    // Start entrance animation
    _entranceController.forward();

    // Request permissions after a short delay
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final permissionService = getIt<PermissionService>();
    await permissionService.requestAllPermissions();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _entranceController.dispose();
    _flipController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive logo size
    final logoSize = isTablet
        ? 200.w.clamp(180.0, 250.0)
        : (screenHeight < 700 ? 140.w : 170.w).clamp(120.0, 200.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          _buildBackground(),

          // Gradient Overlay
          _buildGradientOverlay(),

          // Animated particles (decorative)
          _buildParticles(),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.1),

                        // Rotating Animated Logo
                        _buildRotatingLogo(logoSize),

                        SizedBox(height: 24.h),

                        // App Title with fade-in
                        _buildAppTitle(),

                        SizedBox(height: constraints.maxHeight * 0.15),

                        // Loading Indicator
                        _buildLoadingIndicator(),

                        SizedBox(height: 12.h),

                        // Loading Text
                        _buildLoadingText(),

                        SizedBox(height: constraints.maxHeight * 0.12),

                        // Version Info
                        _buildVersionInfo(),

                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Image.asset(
      // 'lib/assets/images/login-bgg.jpg',
      'lib/assets/images/bg.png',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlesPainter(
            animationValue: _rotationController.value,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildRotatingLogo(double logoSize) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _rotationController,
        _pulseController,
        _flipController,
      ]),
      builder: (context, child) {
        // Calculate subtle 3D perspective
        final flipValue = math.sin(_flipAnimation.value) * 0.05;

        return Transform.scale(
          scale: _entranceScaleAnimation.value * _pulseAnimation.value,
          child: Opacity(
            opacity: _entranceFadeAnimation.value,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(flipValue),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    // Inner glow
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: _glowAnimation.value * 0.4,
                      ),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    // Outer colored glow
                    BoxShadow(
                      color: const Color(
                        0xFF006778,
                      ).withValues(alpha: _glowAnimation.value * 0.6),
                      blurRadius: 50,
                      spreadRadius: 15,
                    ),
                    // Secondary glow
                    BoxShadow(
                      color: const Color(
                        0xFF00A8CC,
                      ).withValues(alpha: _glowAnimation.value * 0.3),
                      blurRadius: 80,
                      spreadRadius: 25,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: _buildLogoContainer(logoSize),
    );
  }

  Widget _buildLogoContainer(double logoSize) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * math.pi,
          child: child,
        );
      },
      child: Container(
        width: logoSize,
        height: logoSize,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          padding: EdgeInsets.all(12.w),
          child: Image.asset(
            'lib/assets/images/YDC-HD.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.timelapse_rounded,
                size: logoSize * 0.4,
                color: Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        final delay = Curves.easeOut.transform(
          (_entranceController.value - 0.4).clamp(0.0, 1.0) / 0.6,
        );
        return Opacity(
          opacity: delay,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - delay)),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withValues(alpha: 0.8),
                Colors.white,
              ],
            ).createShader(bounds),
            child: Text(
              'Leave Management',
              style: TextStyle(
                fontSize: 30.sp.clamp(20.0, 30.0),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'SYSTEM',
            style: TextStyle(
              fontSize: 18.sp.clamp(14.0, 18.0),
              fontWeight: FontWeight.w300,
              color: Colors.white.withValues(alpha: 0.9),
              letterSpacing: 12.0.clamp(4.0, 12.0),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_loadingController.value * 0.2),
          child: Opacity(
            opacity: 0.6 + (_loadingController.value * 0.4),
            child: child,
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ),
          // Spinning indicator
          SizedBox(
            width: 44.w,
            height: 44.w,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingText() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (_loadingController.value * 0.5),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Initializing',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 3,
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(width: 8.w),
          _buildDots(),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        final dotCount = ((_loadingController.value * 3).floor() % 4);
        return SizedBox(
          width: 30.w,
          child: Text(
            '.' * (dotCount + 1),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 2,
              fontWeight: FontWeight.w300,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionInfo() {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, child) {
        final delay = Curves.easeOut.transform(
          (_entranceController.value - 0.6).clamp(0.0, 1.0) / 0.4,
        );
        return Opacity(opacity: delay, child: child);
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              'LMS',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FutureBuilder<String>(
            future: getIt<AppVersionService>().version(),
            builder: (context, snapshot) {
              final version = snapshot.data ?? '';
              return Text(
                version.isEmpty ? 'Version' : 'Version $version',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom painter for background particles
class _ParticlesPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _ParticlesPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent particles

    for (int i = 0; i < 30; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final particleSize = random.nextDouble() * 3 + 1;
      final speed = random.nextDouble() * 0.5 + 0.5;

      // Animate particle position
      final offset = (animationValue * speed * 100) % size.height;
      final y = (baseY + offset) % size.height;

      // Fade based on position
      final alpha = (1 - (y / size.height)) * 0.5;
      paint.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(baseX, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
