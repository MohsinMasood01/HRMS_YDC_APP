import '../../../../core/services/local_storage_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._storage);

  static const _settingsKey = 'app_settings';

  final LocalStorageService _storage;

  @override
  Future<AppSettings> load() async {
    final data = _storage.readJson(_settingsKey);
    if (data == null) {
      return const AppSettings(
        biometricEnabled: false,
        notificationsEnabled: true,
        darkMode: false,
      );
    }
    return AppSettings(
      biometricEnabled: data['biometric'] as bool,
      notificationsEnabled: data['notifications'] as bool,
      darkMode: data['darkMode'] as bool,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _storage.writeJson(_settingsKey, {
      'biometric': settings.biometricEnabled,
      'notifications': settings.notificationsEnabled,
      'darkMode': settings.darkMode,
    });
  }
}

