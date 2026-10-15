part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfileRequested extends ProfileEvent {
  const ProfileRequested();
}

class ProfileContactUpdated extends ProfileEvent {
  const ProfileContactUpdated({
    required this.emergencyName,
    required this.emergencyPhone,
    required this.emergencyRelation,
  });

  final String emergencyName;
  final String emergencyPhone;
  final String emergencyRelation;

  @override
  List<Object?> get props => [emergencyName, emergencyPhone, emergencyRelation];
}

class PasswordChangeRequested extends ProfileEvent {
  const PasswordChangeRequested({
    required this.oldPassword,
    required this.newPassword,
  });

  final String oldPassword;
  final String newPassword;

  @override
  List<Object?> get props => [oldPassword, newPassword];
}
