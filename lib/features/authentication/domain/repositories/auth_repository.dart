import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String username, String password);
  Future<UserEntity?> currentUser();
  Future<void> logout();
  Future<void> cacheUser(UserEntity user);
  Future<void> setRememberMe(bool value, {String? username, String? password});
  Future<String?> rememberedUsername();
  Future<String?> rememberedPassword();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> isBiometricEnabled();
}

