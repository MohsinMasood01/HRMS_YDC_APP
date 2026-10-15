import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repository) : super(const SettingsState.loading()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    final settings = await _repository.load();
    emit(SettingsState.loaded(settings));
  }

  Future<void> toggleBiometric(bool value) async {
    final current = state.settings.copyWith(biometricEnabled: value);
    emit(SettingsState.loaded(current));
    await _repository.save(current);
  }

  Future<void> toggleNotifications(bool value) async {
    final current = state.settings.copyWith(notificationsEnabled: value);
    emit(SettingsState.loaded(current));
    await _repository.save(current);
  }

  Future<void> toggleDarkMode(bool value) async {
    final current = state.settings.copyWith(darkMode: value);
    emit(SettingsState.loaded(current));
    await _repository.save(current);
  }
}

class SettingsState extends Equatable {
  const SettingsState({
    required this.settings,
    required this.isLoading,
  });

  const SettingsState.loading()
      : settings = const AppSettings(
          biometricEnabled: false,
          notificationsEnabled: true,
          darkMode: false,
        ),
        isLoading = true;

  const SettingsState.loaded(this.settings) : isLoading = false;

  final AppSettings settings;
  final bool isLoading;

  @override
  List<Object?> get props => [settings, isLoading];
}

