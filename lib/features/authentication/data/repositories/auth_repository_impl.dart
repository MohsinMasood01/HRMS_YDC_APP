import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource, this._localDataSource);

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<UserEntity> login(String username, String password) async {
    final user = await _remoteDataSource.login(username, password);
    await _localDataSource.cacheUser(user);
    return user;
  }

  @override
  Future<UserEntity?> currentUser() {
    return _localDataSource.getCachedUser();
  }

  @override
  Future<void> logout() {
    return _localDataSource.clear();
  }

  @override
  Future<void> cacheUser(UserEntity user) {
    return _localDataSource.cacheUser(
      UserModelAdapter.fromEntity(user),
    );
  }

  @override
  Future<void> setRememberMe(bool value, {String? username, String? password}) async {
    await _localDataSource.setRememberMe(value, username: username, password: password);
  }

  @override
  Future<String?> rememberedUsername() {
    return _localDataSource.rememberedUsername();
  }

  @override
  Future<String?> rememberedPassword() {
    return _localDataSource.rememberedPassword();
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) {
    return _localDataSource.setBiometricEnabled(enabled);
  }

  @override
  Future<bool> isBiometricEnabled() {
    return _localDataSource.isBiometricEnabled();
  }
}

class UserModelAdapter {
  const UserModelAdapter._();

  static UserModel fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      employeeCode: entity.employeeCode,
      department: entity.department,
      designation: entity.designation,
      location: entity.location,
      cardNumber: entity.cardNumber,
    );
  }
}

