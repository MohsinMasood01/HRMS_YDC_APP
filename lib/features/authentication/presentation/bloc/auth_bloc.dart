import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/network/force_update_controller.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/services/update_service.dart';
import '../../../../di/service_locator.dart';
import '../../../payslips/data/datasources/payslip_file_cache.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/authenticate_user_usecase.dart';
import '../../domain/usecases/get_cached_user_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/toggle_biometric_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthenticateUserUseCase authenticateUserUseCase,
    required GetCachedUserUseCase getCachedUserUseCase,
    required LogoutUseCase logoutUseCase,
    required ToggleBiometricUseCase toggleBiometricUseCase,
    required AuthRepository authRepository,
    required BiometricService biometricService,
  }) : _authenticateUserUseCase = authenticateUserUseCase,
       _getCachedUserUseCase = getCachedUserUseCase,
       _logoutUseCase = logoutUseCase,
       _toggleBiometricUseCase = toggleBiometricUseCase,
       _authRepository = authRepository,
       _biometricService = biometricService,
       super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionExpired>(_onSessionExpired);
    on<BiometricToggled>(_onBiometricToggled);
    on<BiometricLoginRequested>(_onBiometricLoginRequested);
  }

  final AuthenticateUserUseCase _authenticateUserUseCase;
  final GetCachedUserUseCase _getCachedUserUseCase;
  final LogoutUseCase _logoutUseCase;
  final ToggleBiometricUseCase _toggleBiometricUseCase;
  final AuthRepository _authRepository;
  final BiometricService _biometricService;

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final user = await _getCachedUserUseCase();
    final rememberedUsername = await _authRepository.rememberedUsername();
    final rememberedPassword = await _authRepository.rememberedPassword();
    final biometricEnabled = await _authRepository.isBiometricEnabled();
    if (user != null) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          biometricEnabled: biometricEnabled,
          rememberedUsername: rememberedUsername,
          rememberedPassword: rememberedPassword,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          biometricEnabled: biometricEnabled,
          rememberedUsername: rememberedUsername,
          rememberedPassword: rememberedPassword,
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Clear previous errors and set loading state
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    debugPrint('AuthBloc: Starting login for username: ${event.username}');

    try {
      final user = await _authenticateUserUseCase(
        event.username,
        event.password,
      );

      debugPrint('AuthBloc: Login successful, user ID: ${user.id}');

      // Store phone number (username) in secure storage for API calls
      final secureStorage = getIt<SecureStorageService>();
      await secureStorage.write('phone_number', event.username);

      // Set remember me before emitting authenticated state
      await _authRepository.setRememberMe(
        event.rememberMe,
        username: event.username,
        password: event.password,
      );

      // Get biometric enabled state
      final biometricEnabled = await _authRepository.isBiometricEnabled();
      final rememberedUsername = event.rememberMe
          ? event.username
          : state.rememberedUsername;

      // Emit authenticated state - this should trigger navigation
      final authenticatedState = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        biometricEnabled: biometricEnabled,
        rememberedUsername: rememberedUsername,
        clearErrorMessage: true, // Explicitly clear errors
      );

      debugPrint(
        'AuthBloc: Emitting authenticated state - User: ${user.id}, Status: authenticated',
      );

      emit(authenticatedState);

      // Fire-and-forget post-login version check. Login itself already
      // surfaces a 426 via the global ForceUpdateInterceptor — this extra
      // check catches the rarer case where MIN_BUILD was raised between
      // login starting and finishing. Failures are silent (fails open).
      _runPostLoginVersionCheck();
    } catch (error, stackTrace) {
      // Extract clean error message with detailed logging
      debugPrint('AuthBloc: Login error caught - $error');
      debugPrint('AuthBloc: Stack trace: $stackTrace');

      String errorMsg = error.toString();
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring('Exception: '.length);
      }

      // Clean up error message - remove verbose Dio error messages
      if (errorMsg.contains('404')) {
        errorMsg =
            'Login endpoint not found. Please check your network connection or contact support.';
      } else if (errorMsg.contains('status code of 404')) {
        errorMsg =
            'Invalid credentials or endpoint not found. Please check your phone number and password.';
      } else if (errorMsg.contains('Network error') ||
          errorMsg.contains('SocketException')) {
        errorMsg = 'Network error. Please check your internet connection.';
      } else if (errorMsg.length > 200) {
        // If error message is too long (like Dio's verbose errors), extract meaningful part
        if (errorMsg.contains('message')) {
          // Try to extract a shorter message
          // Look for pattern like: message: "actual message" or message: 'actual message'
          // Use a simpler regex that avoids complex character classes
          final doubleQuoteMatch = RegExp(
            r'message\s*:\s*"([^"]+)"',
          ).firstMatch(errorMsg);
          final singleQuoteMatch = RegExp(
            r"message\s*:\s*'([^']+)'",
          ).firstMatch(errorMsg);

          if (doubleQuoteMatch != null && doubleQuoteMatch.group(1) != null) {
            errorMsg = doubleQuoteMatch.group(1)!;
          } else if (singleQuoteMatch != null &&
              singleQuoteMatch.group(1) != null) {
            errorMsg = singleQuoteMatch.group(1)!;
          } else {
            errorMsg =
                'Login failed. Please check your credentials and try again.';
          }
        } else {
          errorMsg =
              'Login failed. Please check your credentials and try again.';
        }
      }

      // Ensure we always have an error message
      if (errorMsg.isEmpty || errorMsg == 'null') {
        errorMsg = 'Login failed. Please check your credentials and try again.';
      }

      debugPrint('AuthBloc: Final error message - $errorMsg');

      // Emit failure state with error message
      emit(state.copyWith(status: AuthStatus.failure, errorMessage: errorMsg));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Flush queued location points while the auth token is still valid, then
    // end the tracking session. Anything that fails to upload stays in SQLite
    // and syncs later under its ORIGINAL card number -- never the next user's.
    try {
      final tracking = getIt<LocationTrackingService>();
      await tracking.syncPendingLocations();
      await tracking.stopTracking();
    } catch (e) {
      debugPrint('AuthBloc: tracking teardown on logout failed: $e');
    }

    // Payslips are private: never leave downloaded PDFs behind a sign-out.
    await getIt<PayslipFileCache>().clearAll();

    await _logoutUseCase();
    emit(state.copyWith(status: AuthStatus.unauthenticated, user: null));
  }

  /// Unlike [LogoutRequested] this leaves location tracking alone: an expired
  /// token says nothing about whether the employee's work session has ended,
  /// and queued points sync once they sign back in. The dead token is dropped
  /// so nothing keeps sending it.
  Future<void> _onSessionExpired(
    SessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    await getIt<PayslipFileCache>().clearAll();
    await getIt<SecureStorageService>().delete('token');
    await _logoutUseCase();

    // failure -> unauthenticated, as for a failed biometric login, so the
    // login page shows the message.
    emit(
      state.copyWith(
        status: AuthStatus.failure,
        errorMessage: ErrorMessages.sessionExpired,
      ),
    );
    emit(state.copyWith(status: AuthStatus.unauthenticated));
  }

  Future<void> _onBiometricToggled(
    BiometricToggled event,
    Emitter<AuthState> emit,
  ) async {
    await _toggleBiometricUseCase(event.enabled);
    emit(state.copyWith(biometricEnabled: event.enabled));
  }

  Future<void> _onBiometricLoginRequested(
    BiometricLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    // The device only has to SUPPORT a secure lock here. Whether a fingerprint
    // or face is actually enrolled is decided by the platform prompt below,
    // which returns a message telling the user how to enroll.
    final isSupported = await _biometricService.isDeviceSupported();
    if (!isSupported) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage:
              'Biometric authentication is not available on this device.',
        ),
      );
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }

    // Authenticate with biometrics. `biometricOnly: false` lets the device
    // screen lock stand in when no biometric is enrolled, instead of the
    // prompt failing outright.
    final result = await _biometricService.authenticate(
      reason: 'Please authenticate to login',
      biometricOnly: false,
    );

    if (result.success) {
      // Prefer a REAL re-login with the saved credentials: logging out clears
      // the cached user, and a restored cache alone leaves the session without
      // a fresh token / card_no, so every API call afterwards would fail.
      final username = await _authRepository.rememberedUsername();
      final password = await _authRepository.rememberedPassword();
      if (username != null &&
          username.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        emit(state.copyWith(status: AuthStatus.loading, clearErrorMessage: true));
        add(
          LoginRequested(
            username: username,
            password: password,
            rememberMe: true,
          ),
        );
        return;
      }

      // No saved credentials: fall back to restoring the cached session.
      final user = await _getCachedUserUseCase();
      if (user != null) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      } else {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            errorMessage:
                'Sign in with your password once and keep "Remember me" on. '
                'After that you can use your fingerprint or Face ID.',
          ),
        );
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: result.message,
        ),
      );
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  /// Fire-and-forget version check after a successful login. The launch-time
  /// check in `UpdateGate` covers the common case; this catches users who
  /// launched the app before `MIN_BUILD` was raised but logged in after. A
  /// force_update result routes through the same global
  /// [ForceUpdateController] that the Dio 426 interceptor uses.
  void _runPostLoginVersionCheck() {
    () async {
      try {
        final result = await getIt<UpdateService>().check();
        if (result.isForce) {
          ForceUpdateController.instance.trigger(
            message: result.message,
            updateUrl: result.updateUrl,
          );
        }
      } catch (e) {
        debugPrint('AuthBloc: post-login version check failed (ignored): $e');
      }
    }();
  }
}
