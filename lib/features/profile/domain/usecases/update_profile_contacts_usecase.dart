import '../entities/enhanced_profile_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileContactsUseCase {
  UpdateProfileContactsUseCase(this._repository);

  final EnhancedProfileRepository _repository;

  Future<EnhancedProfileEntity> call({
    required String emergencyName,
    required String emergencyPhone,
    required String emergencyRelation,
  }) {
    return _repository.updateEmergencyContact(
      name: emergencyName,
      phone: emergencyPhone,
      relationship: emergencyRelation,
    );
  }
}
