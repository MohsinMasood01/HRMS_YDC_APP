part of 'login_form_bloc.dart';

/// Events for the login form
abstract class LoginFormEvent extends Equatable {
  const LoginFormEvent();

  @override
  List<Object?> get props => [];
}

/// Event when username field changes
class LoginUsernameChanged extends LoginFormEvent {
  const LoginUsernameChanged(this.username);

  final String username;

  @override
  List<Object?> get props => [username];
}

/// Event when password field changes
class LoginPasswordChanged extends LoginFormEvent {
  const LoginPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

/// Event to toggle password visibility
class LoginPasswordVisibilityToggled extends LoginFormEvent {
  const LoginPasswordVisibilityToggled();
}

/// Event when remember me is toggled
class LoginRememberMeToggled extends LoginFormEvent {
  const LoginRememberMeToggled();
}

/// Event when form is submitted
class LoginFormSubmitted extends LoginFormEvent {
  const LoginFormSubmitted();
}

/// Event to initialize form with remembered credentials
class LoginFormInitialized extends LoginFormEvent {
  const LoginFormInitialized({this.rememberedUsername, this.rememberedPassword});

  final String? rememberedUsername;
  final String? rememberedPassword;

  @override
  List<Object?> get props => [rememberedUsername, rememberedPassword];
}

