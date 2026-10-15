import '../repositories/profile_repository.dart';

/// Use case for changing user password
class ChangePasswordUseCase {
  ChangePasswordUseCase(this._repository);

  final EnhancedProfileRepository _repository;

  Future<bool> call({
    required String oldPassword,
    required String newPassword,
  }) async {
    return _repository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }
}

