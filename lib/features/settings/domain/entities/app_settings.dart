import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.biometricEnabled,
    required this.notificationsEnabled,
    required this.darkMode,
  });

  final bool biometricEnabled;
  final bool notificationsEnabled;
  final bool darkMode;

  AppSettings copyWith({
    bool? biometricEnabled,
    bool? notificationsEnabled,
    bool? darkMode,
  }) {
    return AppSettings(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  @override
  List<Object?> get props => [biometricEnabled, notificationsEnabled, darkMode];
}

