import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'features/authentication/presentation/bloc/auth_bloc.dart';
import 'features/authentication/presentation/pages/login_page.dart';
import 'presentation/home/home_shell.dart';
import 'presentation/splash/splash_page.dart';
import 'presentation/update/update_gate.dart';
import 'shared/bloc/app_bloc.dart';

class LmsApp extends StatelessWidget {
  const LmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider<AppBloc>(create: (_) => getIt<AppBloc>()..loadTheme()),
            BlocProvider<AuthBloc>(
              create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
            ),
          ],
          child: BlocBuilder<AppBloc, AppState>(
            builder: (context, appState) {
              return MaterialApp(
                title: AppStrings.appTitle,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                // Use system theme mode - this will automatically follow device settings
                themeMode: appState.themeMode,
                // UpdateGate runs the launch-time /app/version-check and
                // overlays a blocking "Update Required" page whenever any
                // 426 response or the launch check triggers
                // ForceUpdateController. The rest of the app continues to
                // render normally underneath until then.
                home: const UpdateGate(child: _AppRouter()),
              );
            },
          ),
        );
      },
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  static const _loginPageKey = ValueKey('login_page');
  static const _splashPageKey = ValueKey('splash_page');
  static const _homeShellKey = ValueKey('home_shell');  

  // Track if we've already shown the login page (to prevent refresh on first login attempt)
  bool _hasShownLoginPage = false;
  AuthStatus? _previousStatus;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (previous, current) {
        // Rebuild when status changes OR when user changes (important for authenticated state)
        final shouldRebuild =
            previous.status != current.status || previous.user != current.user;

        // Track if we've transitioned to unauthenticated (means login page was shown)
        if (current.status == AuthStatus.unauthenticated &&
            !_hasShownLoginPage) {
          _hasShownLoginPage = true;
        }

        // Track if we're transitioning from unauthenticated to loading (user clicked login)
        if (_previousStatus == AuthStatus.unauthenticated &&
            current.status == AuthStatus.loading) {
          _hasShownLoginPage = true; // Ensure we keep showing login page
        }

        _previousStatus = current.status;
        return shouldRebuild;
      },
      builder: (context, state) {
        // Debug: Print state changes
        debugPrint(
          '_AppRouter: Status=${state.status}, User=${state.user?.id}, '
          'Error=${state.errorMessage}, RememberedUsername=${state.rememberedUsername}, '
          'HasShownLoginPage=$_hasShownLoginPage',
        );

        switch (state.status) {
          case AuthStatus.initial:
            debugPrint('_AppRouter: Showing SplashPage (initial)');
            return const SplashPage(key: _splashPageKey);
          case AuthStatus.loading:
            // CRITICAL FIX: Only show SplashPage on VERY FIRST app load (initial check)
            // If we've already shown login page OR have rememberedUsername, keep LoginPage
            // This prevents page refresh and ensures BlocListener stays active
            final isVeryFirstLoad =
                !_hasShownLoginPage &&
                state.user == null &&
                state.rememberedUsername == null &&
                state.errorMessage == null;
            if (isVeryFirstLoad) {
              debugPrint(
                '_AppRouter: Showing SplashPage (very first app load)',
              );
              return const SplashPage(key: _splashPageKey);
            }
            // During login loading, ALWAYS keep showing LoginPage
            // This preserves the widget instance and BlocListener
            debugPrint(
              '_AppRouter: Keeping LoginPage visible during login loading',
            );
            return const LoginPage(key: _loginPageKey);
          case AuthStatus.authenticated:
            // CRITICAL: Only navigate to HomeShell if we have a user
            if (state.user != null) {
              debugPrint(
                '_AppRouter: Navigating to HomeShell - User ID: ${state.user!.id}',
              );
              return const HomeShell(key: _homeShellKey);
            } else {
              // If authenticated but no user, something went wrong - go back to login
              debugPrint(
                '_AppRouter: ERROR - Authenticated but no user! Returning to login.',
              );
              return const LoginPage(key: _loginPageKey);
            }
          case AuthStatus.unauthenticated:
          case AuthStatus.failure:
            // Show LoginPage with same key to preserve state
            _hasShownLoginPage = true; // Mark that we've shown login page
            debugPrint(
              '_AppRouter: Showing LoginPage - Status: ${state.status}, '
              'Error: ${state.errorMessage}',
            );
            return const LoginPage(key: _loginPageKey);
        }
      },
    );
  }
}
