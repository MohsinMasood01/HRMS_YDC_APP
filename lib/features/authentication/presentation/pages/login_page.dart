import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ignore_for_file: todo

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../di/service_locator.dart';
import '../../../attendance/presentation/bloc/biometric_attendance_bloc.dart';
import '../../../attendance/presentation/pages/biometric_attendance_page.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/login_form/login_form_bloc.dart';
import '../widgets/animated_background.dart';
import '../widgets/animated_logo.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/login_text_field.dart';
import '../widgets/slide_fade_animation.dart';

/// A beautiful, modern login page with glassmorphism design
///
/// Features:
/// - Responsive layout for all devices
/// - Smooth animations
/// - Glassmorphism card design
/// - BLoC state management
/// - Dark mode support
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginFormBloc _loginFormBloc;

  @override
  void initState() {
    super.initState();
    // Create LoginFormBloc once and preserve it
    _loginFormBloc = LoginFormBloc();
  }

  @override
  void dispose() {
    _loginFormBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _loginFormBloc,
      child: const _LoginPageContent(),
    );
  }
}

/// Input formatter that ensures the phone number starts with '3'.
class _StartWithThreeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;

    if (newText.isEmpty) return newValue;

    // If user is typing the first character, only allow '3'
    if (newText.length == 1) {
      if (newText[0] != '3') {
        return oldValue;
      }
      return newValue;
    }

    // For longer input ensure the first character remains '3'
    if (newText[0] != '3') return oldValue;

    return newValue;
  }
}

class _LoginPageContent extends StatefulWidget {
  const _LoginPageContent();

  @override
  State<_LoginPageContent> createState() => _LoginPageContentState();
}

class _LoginPageContentState extends State<_LoginPageContent> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    // Check biometric availability
    _checkBiometricAvailability();

    // Initialize form with remembered credentials if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState.rememberedUsername != null) {
        _usernameController.text = authState.rememberedUsername!;
        if (authState.rememberedPassword != null) {
          _passwordController.text = authState.rememberedPassword!;
        }
        context.read<LoginFormBloc>().add(
          LoginFormInitialized(
            rememberedUsername: authState.rememberedUsername,
            rememberedPassword: authState.rememberedPassword,
          ),
        );
      }
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final biometricService = getIt<BiometricService>();
    // Device support is enough to offer the option -- enrollment is checked by
    // the platform prompt, which explains what to do when nothing is enrolled.
    final isAvailable = await biometricService.isBiometricAvailable() ||
        await biometricService.isDeviceSupported();
    if (mounted) {
      setState(() {
        _biometricAvailable = isAvailable;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Validate that fields are not empty
    if (username.isEmpty || password.isEmpty) {
      final loginFormBloc = context.read<LoginFormBloc>();
      loginFormBloc.add(const LoginFormSubmitted());
      return;
    }

    // Update LoginFormBloc with current values to keep state in sync
    final loginFormBloc = context.read<LoginFormBloc>();
    if (loginFormBloc.state.username != username) {
      loginFormBloc.add(LoginUsernameChanged(username));
    }
    if (loginFormBloc.state.password != password) {
      loginFormBloc.add(LoginPasswordChanged(password));
    }

    // Get remember me state from LoginFormBloc
    final formState = loginFormBloc.state;

    // Trigger actual login with controller values
    context.read<AuthBloc>().add(
      LoginRequested(
        username: username,
        password: password,
        rememberMe: formState.rememberMe,
      ),
    );
  }

  Future<void> _handleMarkAttendance() async {
    if (!mounted) return;
    // Directly navigate to BiometricAttendancePage in identify mode
    // Camera opens → face identified → attendance marked automatically
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => BiometricAttendanceBloc(
            biometricService: getIt(),
            geocodingService: getIt(),
            attendanceFileService: getIt(),
            validationService: getIt(),
            appConfig: getIt(),
            employeeId: '', // Will be resolved by face identification
            identifyMode: true,
            locationService: getIt(),
            authRepository: getIt(),
            markBiometricAttendanceUseCase: getIt(),
            faceStatusUseCase: getIt(),
            verifyFaceUseCase: getIt(),
            identifyFaceUseCase: getIt(),
            faceCameraDataSource: getIt(),
          )..add(const BiometricAttendanceInitialized()),
          child: const BiometricAttendancePage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) {
          // Always listen to state changes to catch all transitions
          final shouldListen =
              previous.status != current.status ||
              previous.errorMessage != current.errorMessage ||
              previous.user != current.user;

          if (shouldListen) {
            debugPrint(
              'LoginPage BlocListener: Status changed from ${previous.status} to ${current.status}, '
              'Error: ${current.errorMessage}, User: ${current.user?.id}',
            );
          }

          return shouldListen;
        },
        listener: (context, state) {
          debugPrint(
            'LoginPage BlocListener: Handling state - Status: ${state.status}, '
            'Error: ${state.errorMessage}, User: ${state.user?.id}',
          );

          // Sync LoginFormBloc with AuthBloc state changes
          final loginFormBloc = context.read<LoginFormBloc>();

          // Handle login failure - show error message AND update LoginFormBloc
          if (state.status == AuthStatus.failure) {
            final errorMessage =
                state.errorMessage ?? 'Login failed. Please try again.';

            debugPrint('LoginPage: Login failed - $errorMessage');

            // Update LoginFormBloc to reflect failure
            loginFormBloc.loginFailure(errorMessage);

            // Show error message immediately (don't wait for post frame)
            if (mounted) {
              // Clear any existing snackbars first
              final messenger = ScaffoldMessenger.of(context);
              messenger.clearSnackBars();

              // Capture theme/color values to avoid using BuildContext across async gap
              final bgColor = Theme.of(context).colorScheme.error;
              final snackMargin = EdgeInsets.all(16.w);
              final snackShape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              );

              // Use a small delay to ensure UI is ready
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: bgColor,
                      behavior: SnackBarBehavior.floating,
                      shape: snackShape,
                      margin: snackMargin,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Dismiss',
                        textColor: Colors.white,
                        onPressed: () {
                          messenger.hideCurrentSnackBar();
                        },
                      ),
                    ),
                  );
                }
              });
            }
          }

          // Handle loading state - update LoginFormBloc
          if (state.status == AuthStatus.loading) {
            // LoginFormBloc should already be in submitting state, but ensure it
            if (loginFormBloc.state.status != LoginFormStatus.submitting) {
              loginFormBloc.add(const LoginFormSubmitted());
            }
          }

          // Handle successful login - update LoginFormBloc and navigate
          if (state.status == AuthStatus.authenticated) {
            debugPrint(
              'LoginPage: Login successful! User: ${state.user?.id}, '
              'Navigation should happen via _AppRouter',
            );
            // Update LoginFormBloc to reflect success
            loginFormBloc.loginSuccess();
            // Navigation is handled automatically by _AppRouter listening to AuthBloc
          }
        },
        child: AnimatedBackground(
          // imagePath: 'lib/assets/images/login-bgg.jpg',
          imagePath: 'lib/assets/images/bg.png',
          blurAmount: 3.5,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildResponsiveLayout(context, constraints);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final screenWidth = constraints.maxWidth;
    final screenHeight = constraints.maxHeight;
    final isTablet = screenWidth > 600;
    final isLandscape = screenWidth > screenHeight;
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final isSmallScreen = screenHeight < 700;

    // Responsive card width
    double cardWidth;
    if (isTablet) {
      cardWidth = isLandscape ? 450.w.clamp(400, 500) : 420.w.clamp(380, 480);
    } else {
      cardWidth = screenWidth - 48.w;
    }

    // Responsive padding
    final horizontalPadding = isTablet ? 40.w : 24.w;
    final verticalPadding = isTablet ? 32.h : 12.h;

    // Responsive logo size - smaller on small screens
    final logoSize = isTablet
        ? 140.w.clamp(100.0, 160.0)
        : isSmallScreen
        ? 60.w.clamp(50.0, 70.0)
        : 90.w.clamp(70.0, 100.0);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated Logo - hide when keyboard is visible on small screens
        if (!keyboardVisible || !isSmallScreen)
          SlideFadeAnimation(
            delay: const Duration(milliseconds: 100),
            slideDirection: SlideDirection.fromTop,
            child: AnimatedLogo(
              imagePath: 'lib/assets/images/YDC-HD.png',
              size: keyboardVisible ? logoSize * 0.6 : logoSize,
              duration: const Duration(milliseconds: 1000),
            ),
          ),

        SizedBox(
          height: keyboardVisible ? 12.h : (isSmallScreen ? 16.h : 24.h),
        ),

        // Glass Card with Form
        Center(
          child: SlideFadeAnimation(
            delay: const Duration(milliseconds: 300),
            child: SizedBox(
              width: cardWidth,
              child: GlassCard(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32.w : 20.w,
                  vertical: isTablet ? 32.h : (isSmallScreen ? 16.h : 20.h),
                ),
                child: _buildLoginForm(context, isTablet, isSmallScreen),
              ),
            ),
          ),
        ),

        // Footer - hide when keyboard is visible or small screen
        if (!keyboardVisible && !isSmallScreen) ...[
          SizedBox(height: 16.h),
          SlideFadeAnimation(
            delay: const Duration(milliseconds: 600),
            child: _buildFooter(context),
          ),
        ],
      ],
    );

    // Always use scrollable layout to prevent overflow
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight - verticalPadding * 2,
        ),
        child: Center(child: content),
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    bool isTablet,
    bool isSmallScreen,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<LoginFormBloc, LoginFormState>(
      buildWhen: (previous, current) {
        // Only rebuild when form state actually changes
        return previous.username != current.username ||
            previous.password != current.password ||
            previous.isPasswordVisible != current.isPasswordVisible ||
            previous.rememberMe != current.rememberMe ||
            previous.status != current.status ||
            previous.usernameError != current.usernameError ||
            previous.passwordError != current.passwordError;
      },
      builder: (context, formState) {
        return BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) {
            // Only rebuild when auth status changes
            return previous.status != current.status;
          },
          builder: (context, authState) {
            final isLoading =
                authState.status == AuthStatus.loading ||
                formState.isSubmitting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                SlideFadeAnimation(
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: isTablet
                          ? 28.sp
                          : (isSmallScreen ? 20.sp : 24.sp),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: isSmallScreen ? 4.h : 6.h),

                // Subtitle
                SlideFadeAnimation(
                  delay: const Duration(milliseconds: 450),
                  child: Text(
                    'Login to your account',
                    style: TextStyle(
                      fontSize: isTablet
                          ? 14.sp
                          : (isSmallScreen ? 11.sp : 13.sp),
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(
                  height: isTablet ? 28.h : (isSmallScreen ? 16.h : 24.h),
                ),

                // Username Field
                SlideFadeAnimation(
                  delay: const Duration(milliseconds: 500),
                  child: LoginTextField(
                    hintText: 'Phone Number',
                    controller: _usernameController,
                    prefixIcon: Icons.person_outline_rounded,
                    // Use number keyboard and restrict input via formatters
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      _StartWithThreeFormatter(),
                    ],
                    textInputAction: TextInputAction.next,

                    enabled: !isLoading,
                    errorText: formState.usernameError,

                    onChanged: (value) {
                      context.read<LoginFormBloc>().add(
                        LoginUsernameChanged(value),
                      );
                    },
                  ),
                ),

                SizedBox(height: isSmallScreen ? 10.h : 14.h),

                // Password Field
                SlideFadeAnimation(
                  delay: const Duration(milliseconds: 550),
                  child: LoginTextField(
                    hintText: 'Password',
                    controller: _passwordController,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: !formState.isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.text,
                    enabled: !isLoading,
                    errorText: formState.passwordError,
                    onChanged: (value) {
                      context.read<LoginFormBloc>().add(
                        LoginPasswordChanged(value),
                      );
                    },
                    onSubmitted: (_) => _handleLogin(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        context.read<LoginFormBloc>().add(
                          const LoginPasswordVisibilityToggled(),
                        );
                      },
                      icon: Icon(
                        formState.isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        size: 22.sp,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 8.h : 10.h),

                // Remember Me & Forgot Password Row
                SlideFadeAnimation(
                  delay: const Duration(milliseconds: 600),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Remember Me
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 22.h,
                            width: 22.w,
                            child: Checkbox(
                              value: formState.rememberMe,
                              onChanged: isLoading
                                  ? null
                                  : (_) {
                                      context.read<LoginFormBloc>().add(
                                        const LoginRememberMeToggled(),
                                      );
                                    },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                              activeColor: isDark
                                  ? AppColors.secondary
                                  : theme.primaryColor,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Remember me',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Forgot Password
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Forgot password feature coming soon',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                );
                              },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 4.h,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isDark
                                ? AppColors.secondary
                                : theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isSmallScreen ? 14.h : 20.h),

                // Login Button
                SlideFadeAnimation(
                  delay: const Duration(milliseconds: 650),
                  child: GradientButton(
                    label: 'Sign In',
                    icon: Icons.login_rounded,
                    isLoading: isLoading,
                    isEnabled: formState.isSubmitEnabled && !isLoading,
                    onPressed: _handleLogin,
                    height: isTablet ? 54.h : 50.h,
                  ),
                ),

                // Mark Attendance Button (no login required)
                SizedBox(height: isSmallScreen ? 10.h : 14.h),
                SlideFadeAnimation(
                  delay: const Duration(milliseconds: 675),
                  child: _buildMarkAttendanceButton(
                    context,
                    theme,
                    isLoading,
                  ),
                ),

                // Biometric Login Option - Show if biometric is available
                if (_biometricAvailable) ...[
                  SizedBox(height: isSmallScreen ? 12.h : 16.h),
                  SlideFadeAnimation(
                    delay: const Duration(milliseconds: 700),
                    child: _buildBiometricButton(
                      context,
                      theme,
                      isLoading,
                      authState,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBiometricButton(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
    AuthState authState,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.secondary : theme.primaryColor;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.1),
            const Color(0xFF4338CA).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading
              ? null
              : () {
                  context.read<AuthBloc>().add(const BiometricLoginRequested());
                },
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, const Color(0xFF4338CA)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login with Biometrics',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      'Use fingerprint or Face ID',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.sp,
                  color: accentColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkAttendanceButton(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? AppColors.success : const Color(0xFF16A34A);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : _handleMarkAttendance,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                          Icons.face_rounded,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark Attendance',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        'Scan face to check in / check out',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.sp,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '© ${DateTime.now().year} LMS. All rights reserved.',
          style: TextStyle(
            fontSize: 11.sp,
            color: isDark ? Colors.white38 : Colors.white70,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink(context, 'Privacy Policy'),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              width: 4.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.white54,
                shape: BoxShape.circle,
              ),
            ),
            _buildFooterLink(context, 'Terms of Service'),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to respective pages
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          color: isDark ? Colors.white54 : Colors.white70,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: isDark ? Colors.white54 : Colors.white70,
        ),
      ),
    );
  }
}
