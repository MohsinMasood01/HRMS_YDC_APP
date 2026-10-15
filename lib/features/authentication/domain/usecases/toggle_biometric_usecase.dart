import '../repositories/auth_repository.dart';

class ToggleBiometricUseCase {
  ToggleBiometricUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(bool enabled) => _repository.setBiometricEnabled(enabled);
}

