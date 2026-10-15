import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class AuthenticateUserUseCase {
  AuthenticateUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<UserEntity> call(String username, String password) {
    return _repository.login(username, password);
  }
}

