part of 'profile_bloc.dart';

enum ProfileStatus { initial, loading, success, failure }

class ProfileState extends Equatable {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.errorMessage,
    this.passwordChangeSuccess = false,
  });

  final ProfileStatus status;
  final EnhancedProfileEntity? profile;
  final String? errorMessage;
  final bool passwordChangeSuccess;

  ProfileState copyWith({
    ProfileStatus? status,
    EnhancedProfileEntity? profile,
    String? errorMessage,
    bool? passwordChangeSuccess,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
      passwordChangeSuccess:
          passwordChangeSuccess ?? this.passwordChangeSuccess,
    );
  }

  @override
  List<Object?> get props => [
    status,
    profile,
    errorMessage,
    passwordChangeSuccess,
  ];
}

