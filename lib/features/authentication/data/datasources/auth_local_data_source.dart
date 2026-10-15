import '../../../../core/services/local_storage_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getCachedUser();
  Future<void> clear();
  Future<void> setRememberMe(bool value, {String? username, String? password});
  Future<String?> rememberedUsername();
  Future<String?> rememberedPassword();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> isBiometricEnabled();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._storage, this._secureStorage);

  static const _userKey = 'auth_user';
  static const _rememberKey = 'remember_me';
  static const _rememberedUsernameKey = 'remembered_username';
  static const _rememberedPasswordKey = 'remembered_password';
  static const _biometricKey = 'biometric_enabled';

  final LocalStorageService _storage;
  final SecureStorageService _secureStorage;

  @override
  Future<void> cacheUser(UserModel user) async {
    await _storage.writeJson(_userKey, user.toJson());
    // Cache userid from response for later API calls
    await _secureStorage.write('userid', user.id);
  }

  @override
  Future<UserModel?> getCachedUser() async {
    // First check if cached user exists
    final data = _storage.readJson(_userKey);
    if (data != null) {
      return UserModel.fromJson(data);
    }

    // If no cached user, check if userid exists (user was logged in before)
    final userid = await _secureStorage.read('userid');
    if (userid == null || userid.isEmpty) {
      return null;
    }

    // Try to restore user from profile cache if available
    // Profile is cached with key 'profile_cache' in LmsLocalDataSource
    final profileData = _storage.readJson('profile_cache');
    if (profileData != null) {
      try {
        // Create user model from profile data
        final user = UserModel(
          id: userid,
          name: profileData['name']?.toString() ?? '',
          employeeCode: profileData['employeeCode']?.toString() ?? '',
          department: profileData['department']?.toString() ?? '',
          designation: profileData['designation']?.toString() ?? '',
          location: profileData['location']?.toString() ?? '',
          cardNumber: profileData['cardNumber']?.toString() ?? '',
        );
        // Cache the restored user for future use
        await cacheUser(user);
        return user;
      } catch (e) {
        // If profile parsing fails, return null
        return null;
      }
    }

    return null;
  }

  @override
  Future<void> clear() async {
    await _storage.remove(_userKey);
    await _secureStorage.delete('userid');
  }

  @override
  Future<void> setRememberMe(bool value, {String? username, String? password}) async {
    await _storage.writeString(_rememberKey, value.toString());
    if (value) {
      if (username != null) {
        await _storage.writeString(_rememberedUsernameKey, username);
      }
      if (password != null) {
        await _secureStorage.write(_rememberedPasswordKey, password);
      }
    } else {
      await _storage.remove(_rememberedUsernameKey);
      await _secureStorage.delete(_rememberedPasswordKey);
    }
  }

  @override
  Future<String?> rememberedUsername() async {
    return _storage.readString(_rememberedUsernameKey);
  }

  @override
  Future<String?> rememberedPassword() async {
    return _secureStorage.read(_rememberedPasswordKey);
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.writeString(_biometricKey, enabled.toString());
  }

  @override
  Future<bool> isBiometricEnabled() async {
    final value = _storage.readString(_biometricKey);
    return value == 'true';
  }
}
