import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'login_form_event.dart';
part 'login_form_state.dart';

/// BLoC for managing login form state
/// 
/// This bloc handles:
/// - Username and password input validation
/// - Password visibility toggle
/// - Remember me functionality
/// - Form submission state
class LoginFormBloc extends Bloc<LoginFormEvent, LoginFormState> {
  LoginFormBloc() : super(const LoginFormState()) {
    on<LoginFormInitialized>(_onFormInitialized);
    on<LoginUsernameChanged>(_onUsernameChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginPasswordVisibilityToggled>(_onPasswordVisibilityToggled);
    on<LoginRememberMeToggled>(_onRememberMeToggled);
    on<LoginFormSubmitted>(_onFormSubmitted);
  }

  void _onFormInitialized(
    LoginFormInitialized event,
    Emitter<LoginFormState> emit,
  ) {
    if (event.rememberedUsername != null && event.rememberedUsername!.isNotEmpty) {
      emit(state.copyWith(
        username: event.rememberedUsername,
        password: event.rememberedPassword ?? '',
        rememberMe: true,
        status: LoginFormStatus.initial,
      ));
    }
  }

  void _onUsernameChanged(
    LoginUsernameChanged event,
    Emitter<LoginFormState> emit,
  ) {
    final username = event.username;
    String? usernameError;

    // Validate username
    if (username.isEmpty) {
      usernameError = null; // Don't show error while typing
    } else if (username.length < 3) {
      usernameError = 'Username must be at least 3 characters';
    }

    final newState = state.copyWith(
      username: username,
      usernameError: usernameError,
      clearErrors: usernameError == null,
    );

    emit(newState.copyWith(
      status: newState.isValid ? LoginFormStatus.valid : LoginFormStatus.invalid,
      usernameError: usernameError,
    ));
  }

  void _onPasswordChanged(
    LoginPasswordChanged event,
    Emitter<LoginFormState> emit,
  ) {
    final password = event.password;
    String? passwordError;

    // Validate password
    if (password.isEmpty) {
      passwordError = null; // Don't show error while typing
    } else if (password.length < 4) {
      passwordError = 'Password must be at least 4 characters';
    }

    final newState = state.copyWith(
      password: password,
      passwordError: passwordError,
      clearErrors: passwordError == null,
    );

    emit(newState.copyWith(
      status: newState.isValid ? LoginFormStatus.valid : LoginFormStatus.invalid,
      passwordError: passwordError,
    ));
  }

  void _onPasswordVisibilityToggled(
    LoginPasswordVisibilityToggled event,
    Emitter<LoginFormState> emit,
  ) {
    emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible));
  }

  void _onRememberMeToggled(
    LoginRememberMeToggled event,
    Emitter<LoginFormState> emit,
  ) {
    emit(state.copyWith(rememberMe: !state.rememberMe));
  }

  void _onFormSubmitted(
    LoginFormSubmitted event,
    Emitter<LoginFormState> emit,
  ) {
    // Validate before submission
    String? usernameError;
    String? passwordError;

    if (state.username.isEmpty) {
      usernameError = 'Please enter your username';
    } else if (state.username.length < 3) {
      usernameError = 'Username must be at least 3 characters';
    }

    if (state.password.isEmpty) {
      passwordError = 'Please enter your password';
    } else if (state.password.length < 4) {
      passwordError = 'Password must be at least 4 characters';
    }

    if (usernameError != null || passwordError != null) {
      emit(state.copyWith(
        status: LoginFormStatus.invalid,
        usernameError: usernameError,
        passwordError: passwordError,
      ));
      return;
    }

    // Form is valid, emit submitting state
    emit(state.copyWith(
      status: LoginFormStatus.submitting,
      clearErrors: true,
    ));
  }

  /// Call this when login succeeds
  void loginSuccess() {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(status: LoginFormStatus.success));
  }

  /// Call this when login fails
  void loginFailure(String message) {
    // ignore: invalid_use_of_visible_for_testing_member
    emit(state.copyWith(
      status: LoginFormStatus.failure,
      errorMessage: message,
    ));
  }
}

