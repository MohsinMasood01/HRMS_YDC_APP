part of 'login_form_bloc.dart';

/// Status of the login form
enum LoginFormStatus {
  initial,
  valid,
  invalid,
  submitting,
  success,
  failure,
}

/// State for the login form
class LoginFormState extends Equatable {
  const LoginFormState({
    this.status = LoginFormStatus.initial,
    this.username = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.rememberMe = true,
    this.errorMessage,
    this.usernameError,
    this.passwordError,
  });

  final LoginFormStatus status;
  final String username;
  final String password;
  final bool isPasswordVisible;
  final bool rememberMe;
  final String? errorMessage;
  final String? usernameError;
  final String? passwordError;

  /// Check if the form is valid
  bool get isValid => 
      username.isNotEmpty && 
      password.isNotEmpty && 
      usernameError == null && 
      passwordError == null;

  /// Check if the submit button should be enabled
  bool get isSubmitEnabled => 
      isValid && status != LoginFormStatus.submitting;

  /// Check if form is currently submitting
  bool get isSubmitting => status == LoginFormStatus.submitting;

  LoginFormState copyWith({
    LoginFormStatus? status,
    String? username,
    String? password,
    bool? isPasswordVisible,
    bool? rememberMe,
    String? errorMessage,
    String? usernameError,
    String? passwordError,
    bool clearErrors = false,
  }) {
    return LoginFormState(
      status: status ?? this.status,
      username: username ?? this.username,
      password: password ?? this.password,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      rememberMe: rememberMe ?? this.rememberMe,
      errorMessage: clearErrors ? null : (errorMessage ?? this.errorMessage),
      usernameError: clearErrors ? null : (usernameError ?? this.usernameError),
      passwordError: clearErrors ? null : (passwordError ?? this.passwordError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        username,
        password,
        isPasswordVisible,
        rememberMe,
        errorMessage,
        usernameError,
        passwordError,
      ];
}

