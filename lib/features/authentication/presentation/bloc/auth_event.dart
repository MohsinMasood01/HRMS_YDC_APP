part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class LoginRequested extends AuthEvent {
  const LoginRequested({
    required this.username,
    required this.password,
    required this.rememberMe,
  });

  final String username;
  final String password;
  final bool rememberMe;

  @override
  List<Object?> get props => [username, password, rememberMe];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// The server rejected the stored session (401/403). Returns to the login
/// page with a "session expired" message.
class SessionExpired extends AuthEvent {
  const SessionExpired();
}

class BiometricToggled extends AuthEvent {
  const BiometricToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class BiometricLoginRequested extends AuthEvent {
  const BiometricLoginRequested();
}