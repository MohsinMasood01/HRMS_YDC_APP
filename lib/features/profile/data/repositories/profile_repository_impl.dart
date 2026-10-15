import 'package:flutter/foundation.dart';

import '../../../../core/services/secure_storage_service.dart';
import '../../../../data/datasources/lms_local_data_source.dart';
import '../../../../data/datasources/lms_remote_data_source.dart';
import '../../../../di/service_locator.dart';
import '../../domain/entities/enhanced_profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/emergency_contact_store.dart';

class ProfileRepositoryImpl implements EnhancedProfileRepository {
  ProfileRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
    this._emergencyContactStore,
  );

  final LmsRemoteDataSource _remoteDataSource;
  final LmsLocalDataSource _localDataSource;
  final EmergencyContactStore _emergencyContactStore;

  Future<String?> _cardNo() async {
    try {
      return await getIt<SecureStorageService>().read('card_no');
    } catch (e) {
      debugPrint('ProfileRepository: could not read card_no: $e');
      return null;
    }
  }

  /// The server's emergency contact wins; the locally saved one fills the gap
  /// while the backend has nowhere to store it.
  Future<EnhancedProfileEntity> _withSavedEmergencyContact(
    EnhancedProfileEntity profile,
  ) async {
    if (profile.emergencyContact != null) return profile;
    final saved = _emergencyContactStore.read(
      profile.cardNumber.trim().isNotEmpty && profile.cardNumber != '-'
          ? profile.cardNumber
          : await _cardNo(),
    );
    return saved == null ? profile : profile.copyWith(emergencyContact: saved);
  }

  @override
  Future<EnhancedProfileEntity> fetchProfile() async {
    // ALWAYS fetch fresh from API - NO caching across users
    // This ensures data integrity and prevents showing previous user's data
    try {
      final profile = await _remoteDataSource.profile();
      // Keep the employee's own schedule from HRMS; only fill in the default
      // when the backend sent none at all.
      final withSchedule = profile.workSchedule != null
          ? profile
          : profile.copyWith(workSchedule: WorkSchedule.defaultSchedule);
      return _withSavedEmergencyContact(withSchedule);
    } catch (e) {
      // If profile API fails, try to get basic info from dashboard cache
      // This is only a fallback for display purposes
      final dashboardData = _localDataSource.dashboard();
      if (dashboardData != null) {
        return _withSavedEmergencyContact(
          _createProfileFromDashboard(dashboardData),
        );
      }

      // Last resort: return minimal profile
      return EnhancedProfileEntity(
        id: '0',
        employeeCode: '-',
        name: 'Loading...',
        email: '',
        phoneNumber: '',
        gender: 'M',
        dateOfBirth: '-',
        joiningDate: '-',
        department: '-',
        designation: '-',
        cadre: '-',
        location: '-',
        branch: '-',
        cardNumber: '-',
        workSchedule: WorkSchedule.defaultSchedule,
      );
    }
  }

  DateTime _parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      // Try alternative formats
      try {
        // Handle "27-oct-2025" format
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final months = {
            'jan': 1,
            'feb': 2,
            'mar': 3,
            'apr': 4,
            'may': 5,
            'jun': 6,
            'jul': 7,
            'aug': 8,
            'sep': 9,
            'oct': 10,
            'nov': 11,
            'dec': 12,
          };
          final month = months[parts[1].toLowerCase()] ?? 1;
          final day = int.tryParse(parts[0]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;
          return DateTime(year, month, day);
        }
      } catch (e2) {
        // Ignore
      }
      return DateTime.now();
    }
  }

  EnhancedProfileEntity _createProfileFromDashboard(dashboardData) {
    return EnhancedProfileEntity(
      id: dashboardData.empPk.toString(),
      employeeCode: dashboardData.empNo,
      name: dashboardData.empName,
      email: '',
      phoneNumber: '',
      gender: 'M',
      dateOfBirth: '-',
      joiningDate: dashboardData.dateOfJoin,
      department: dashboardData.department,
      designation: dashboardData.designation,
      cadre: dashboardData.designation,
      location: dashboardData.brnchnm,
      branch: dashboardData.brnchnm,
      cardNumber: dashboardData.cardNo1,
      workSchedule: WorkSchedule.defaultSchedule, // dashboard carries no roster
    );
  }

  @override
  Future<EnhancedProfileEntity> updateEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    // Fetch fresh profile first, then update emergency contact
    final current = await fetchProfile();
    final emergencyContact = EmergencyContact(
      name: name,
      phoneNumber: phone,
      relationship: relationship,
    );

    // Persist BEFORE returning. Previously the edit lived only in the bloc's
    // state, so logging out and back in silently discarded it.
    final cardNo =
        current.cardNumber.trim().isNotEmpty && current.cardNumber != '-'
            ? current.cardNumber
            : await _cardNo();
    await _emergencyContactStore.write(cardNo, emergencyContact);

    // Best effort push to the server. The endpoint may not exist yet, so a
    // failure must not lose the employee's edit -- it is already saved above.
    try {
      await _remoteDataSource.updateEmergencyContact(
        name: name,
        phone: phone,
        relationship: relationship,
      );
    } catch (e) {
      debugPrint('ProfileRepository: emergency contact not saved remotely: $e');
    }

    return current.copyWith(emergencyContact: emergencyContact);
  }

  @override
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return await _remoteDataSource.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }
}
