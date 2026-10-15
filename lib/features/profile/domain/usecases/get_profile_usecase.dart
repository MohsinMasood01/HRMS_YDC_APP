import '../entities/enhanced_profile_entity.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase {
  GetProfileUseCase(this._repository);

  final EnhancedProfileRepository _repository;

  Future<EnhancedProfileEntity> call() => _repository.fetchProfile();
}






