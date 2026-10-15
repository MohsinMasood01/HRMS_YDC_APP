import '../entities/enhanced_profile_entity.dart';

abstract class EnhancedProfileRepository {
  Future<EnhancedProfileEntity> fetchProfile();
  Future<EnhancedProfileEntity> updateEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  });
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  });
}

