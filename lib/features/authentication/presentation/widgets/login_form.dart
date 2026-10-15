import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/login_form/login_form_bloc.dart';
import 'gradient_button.dart';
import 'login_text_field.dart';
import 'slide_fade_animation.dart';

/// A complete login form widget with BLoC integration
///
/// This widget can be used standalone with its own BLoC provider
/// or within a parent that provides the LoginFormBloc
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    this.usernameController,
    this.passwordController,
    this.rememberMe = true,
    this.onRememberMeChanged,
    this.onLoginPressed,
    this.isLoading = false,
    this.onForgotPassword,
    this.showAnimations = true,
  });

  final TextEditingController? usernameController;
  final TextEditingController? passwordController;
  final bool rememberMe;
  final ValueChanged<bool>? onRememberMeChanged;
  final VoidCallback? onLoginPressed;
  final bool isLoading;
  final VoidCallback? onForgotPassword;
  final bool showAnimations;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _ownsUsernameController = false;
  bool _ownsPasswordController = false;

  @override
  void initState() {
    super.initState();
    if (widget.usernameController != null) {
      _usernameController = widget.usernameController!;
    } else {
      _usernameController = TextEditingController();
      _ownsUsernameController = true;
    }

    if (widget.passwordController != null) {
      _passwordController = widget.passwordController!;
    } else {
      _passwordController = TextEditingController();
      _ownsPasswordController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsUsernameController) {
      _usernameController.dispose();
    }
    if (_ownsPasswordController) {
      _passwordController.dispose();
    }
    super.dispose();
  }

  void _handleLogin() {
    if (widget.onLoginPressed != null) {
      widget.onLoginPressed!();
    } else {
      // Use BLoC if available
      final loginFormBloc = context.read<LoginFormBloc?>();
      if (loginFormBloc != null) {
        loginFormBloc.add(const LoginFormSubmitted());

        final formState = loginFormBloc.state;
        if (formState.username.isNotEmpty && formState.password.isNotEmpty) {
          context.read<AuthBloc>().add(
            LoginRequested(
              username: formState.username,
              password: formState.password,
              rememberMe: formState.rememberMe,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Check if LoginFormBloc is available
    final loginFormBloc = context.watch<LoginFormBloc?>();

    if (loginFormBloc != null) {
      return _buildBlocForm(context, isDark);
    }

    // Fallback to simple form without BLoC
    return _buildSimpleForm(context, isDark);
  }

  Widget _buildBlocForm(BuildContext context, bool isDark) {
    return BlocBuilder<LoginFormBloc, LoginFormState>(
      builder: (context, formState) {
        return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final isLoading =
                authState.status == AuthStatus.loading ||
                formState.isSubmitting ||
                widget.isLoading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username Field
                _wrapWithAnimation(
                  delay: const Duration(milliseconds: 100),
                  child: LoginTextField(
                    hintText: 'Username / Employee Code',
                    controller: _usernameController,
                    prefixIcon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.text,
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

                SizedBox(height: 16.h),

                // Password Field
                _wrapWithAnimation(
                  delay: const Duration(milliseconds: 150),
                  child: LoginTextField(
                    hintText: 'Password',
                    controller: _passwordController,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: !formState.isPasswordVisible,
                    textInputAction: TextInputAction.done,
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

                SizedBox(height: 12.h),

                // Remember Me & Forgot Password
                _wrapWithAnimation(
                  delay: const Duration(milliseconds: 200),
                  child: _buildRememberMeRow(
                    context,
                    isDark,
                    formState.rememberMe,
                    isLoading,
                    () => context.read<LoginFormBloc>().add(
                      const LoginRememberMeToggled(),
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // Login Button
                _wrapWithAnimation(
                  delay: const Duration(milliseconds: 250),
                  child: GradientButton(
                    label: 'Sign In',
                    icon: Icons.login_rounded,
                    isLoading: isLoading,
                    isEnabled: formState.isSubmitEnabled && !isLoading,
                    onPressed: _handleLogin,
                    height: 54.h,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSimpleForm(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Username Field
        _wrapWithAnimation(
          delay: const Duration(milliseconds: 100),
          child: LoginTextField(
            hintText: 'Username / Employee Code',
            controller: _usernameController,
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            enabled: !widget.isLoading,
          ),
        ),

        SizedBox(height: 16.h),

        // Password Field
        _wrapWithAnimation(
          delay: const Duration(milliseconds: 150),
          child: LoginTextField(
            hintText: 'Password',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            enabled: !widget.isLoading,
            onSubmitted: (_) => _handleLogin(),
          ),
        ),

        SizedBox(height: 12.h),

        // Remember Me & Forgot Password
        _wrapWithAnimation(
          delay: const Duration(milliseconds: 200),
          child: _buildRememberMeRow(
            context,
            isDark,
            widget.rememberMe,
            widget.isLoading,
            () => widget.onRememberMeChanged?.call(!widget.rememberMe),
          ),
        ),

        SizedBox(height: 24.h),

        // Login Button
        _wrapWithAnimation(
          delay: const Duration(milliseconds: 250),
          child: GradientButton(
            label: 'Sign In',
            icon: Icons.login_rounded,
            isLoading: widget.isLoading,
            isEnabled: !widget.isLoading,
            onPressed: _handleLogin,
            height: 54.h,
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeRow(
    BuildContext context,
    bool isDark,
    bool rememberMe,
    bool isLoading,
    VoidCallback onToggle,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Remember Me
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24.h,
              width: 24.w,
              child: Checkbox(
                value: rememberMe,
                onChanged: isLoading ? null : (_) => onToggle(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.r),
                ),
                side: BorderSide(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  width: 1.5,
                ),
                activeColor: theme.primaryColor,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Remember me',
              style: TextStyle(
                fontSize: 13.sp,
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
              : widget.onForgotPassword ??
                    () {
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
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 13.sp,
              color: theme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _wrapWithAnimation({required Widget child, required Duration delay}) {
    if (!widget.showAnimations) {
      return child;
    }

    return SlideFadeAnimation(delay: delay, child: child);
  }
}
