part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, failure }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.biometricEnabled = false,
    this.rememberedUsername,
    this.rememberedPassword,
  });

  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;
  final bool biometricEnabled;
  final String? rememberedUsername;
  final String? rememberedPassword;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
    bool? clearErrorMessage,
    bool? biometricEnabled,
    String? rememberedUsername,
    String? rememberedPassword,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearErrorMessage == true
          ? null
          : (errorMessage ?? this.errorMessage),
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      rememberedUsername: rememberedUsername ?? this.rememberedUsername,
      rememberedPassword: rememberedPassword ?? this.rememberedPassword,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    errorMessage,
    biometricEnabled,
    rememberedUsername,
    rememberedPassword,
  ];
}
