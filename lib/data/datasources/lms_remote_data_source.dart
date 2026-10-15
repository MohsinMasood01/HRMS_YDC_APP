import 'package:flutter/foundation.dart';
import 'package:lms/features/attendance/domain/entities/biometric_attendance.dart';

import '../../core/config/app_config.dart';
import '../../core/network/mock_api_service.dart';
import 'lms_local_data_source.dart';
import '../../core/network/network_client.dart';
import '../../core/services/secure_storage_service.dart';
import '../../di/service_locator.dart';
import '../../features/attendance/domain/entities/attendance_record.dart';
import '../../features/attendance/domain/entities/attendance_summary.dart';
import '../../features/dashboard/domain/entities/dashboard_summary.dart';
import '../../features/leaves/domain/entities/leave_balance.dart';
import '../../features/leaves/domain/entities/leave_request.dart';
import '../../features/notifications/domain/entities/notification_message.dart';
import '../../features/profile/domain/entities/enhanced_profile_entity.dart';
import '../../features/profile/domain/entities/profile_photo_url.dart';

abstract class LmsRemoteDataSource {
  Future<DashboardSummary> dashboard();
  Future<List<LeaveBalance>> leaveBalances();
  Future<List<LeaveRequest>> leaveRequests();
  Future<void> submitLeave(LeaveRequest request);
  Future<List<AttendanceRecord>> attendance(DateTime from, DateTime to);
  Future<AttendanceSummary> attendanceSummary(DateTime from, DateTime to);
  Future<EnhancedProfileEntity> profile();
  Future<List<NotificationMessage>> notifications();
  Future<void> markAttendance({required bool automatic, String? note});
  Future<BiometricAttendanceResponse> markBiometricAttendance(
    BiometricAttendanceRequest request,
  );
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  });

  /// Pushes the employee's emergency contact to HRMS.
  ///
  /// Throws when the backend has no such endpoint yet; callers must treat this
  /// as best-effort and keep their own copy.
  Future<void> updateEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  });
}

class LmsRemoteDataSourceImpl implements LmsRemoteDataSource {
  LmsRemoteDataSourceImpl(this._client, this._config, this._mockApiService);

  final NetworkClient _client;
  final AppConfig _config;
  final MockApiService _mockApiService;

  @override
  Future<DashboardSummary> dashboard() async {
    if (_config.useMockData) {
      return _mockApiService.fetchDashboard();
    }

    // Get card_no from secure storage (stored during login)
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no');

    if (cardNo1 == null || cardNo1.isEmpty) {
      throw Exception('Card number not found. Please login again.');
    }

    debugPrint('=== FETCHING DASHBOARD ===');
    debugPrint('Card number from storage: $cardNo1');
    debugPrint('API URL: /auth/dashboard/$cardNo1');

    try {
      // Call real API: /data/{card_no}
      final response = await _client.get<Map<String, dynamic>>(
        '/auth/dashboard/$cardNo1',
      );

      debugPrint('API Response received');
      final responseData = response.data;
      if (responseData == null) {
        debugPrint('ERROR: Response data is null');
        throw Exception('Invalid response from server');
      }
      debugPrint('Response data: $responseData');

      // API returns data in 'items' array format (ORDS REST API format)
      Map<String, dynamic>? body;

      // Check if response has 'items' array (ORDS format)
      if (responseData.containsKey('items')) {
        final items = responseData['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          body = items[0] as Map<String, dynamic>?;
          debugPrint(
            'Dashboard: Found items array with ${items.length} item(s), using first item',
          );
        } else {
          debugPrint('Dashboard: ERROR - Items array is empty');
          throw Exception('No dashboard data found in response');
        }
      } else if (responseData.containsKey('body')) {
        // Fallback to 'body' format if present
        body = responseData['body'] as Map<String, dynamic>?;
        debugPrint('Dashboard: Found body structure');
      } else {
        // If response is directly the data object
        body = responseData;
        debugPrint('Dashboard: Response is directly the data structure');
      }

      if (body == null) {
        debugPrint('Dashboard: ERROR - Could not extract data from response');
        throw Exception('Invalid response: Missing data');
      }

      // Helper functions for safe parsing
      int safeInt(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value) ?? 0;
        }
        return 0;
      }

      String safeString(dynamic value) {
        if (value == null) return '-';
        final str = value.toString().trim();
        return str.isEmpty ? '-' : str;
      }

      // Map response to DashboardSummary with all fields
      debugPrint('Mapping response to DashboardSummary...');
      final summary = DashboardSummary(
        empPk: safeInt(body['emp_pk']),
        cardNo1: safeString(body['card_no']),
        empNo: safeString(body['emp_no']),
        empName: safeString(body['emp_name']),
        dateOfJoin: safeString(body['date_of_join']),
        nicNo: safeString(body['nic_no']),
        designation: safeString(body['designation']),
        department: safeString(body['department']),
        compcnm: safeString(body['compcnm']),
        compc: safeInt(body['compc']),
        branch: safeInt(body['branch']),
        brnchnm: safeString(body['brnchnm']),
        hod: safeInt(body['hod']),
        hodNm: safeString(body['hod_nm']),
        balances:
            const [], // Leave balances will be fetched separately and merged
      );

      debugPrint('=== DASHBOARD SUMMARY CREATED ===');
      debugPrint('Employee Name: ${summary.empName}');
      debugPrint('Employee Code: ${summary.empNo}');
      debugPrint('Designation: ${summary.designation}');
      debugPrint('Department: ${summary.department}');
      debugPrint('Branch: ${summary.brnchnm}');

      return summary;
    } catch (e, stackTrace) {
      debugPrint('=== DASHBOARD API ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<LeaveBalance>> leaveBalances() async {
    if (_config.useMockData) {
      return _mockApiService.fetchBalances();
    }

    // Get card_no from secure storage
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no');

    if (cardNo1 == null || cardNo1.isEmpty) {
      throw Exception('Card number not found. Please login again.');
    }

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/auth/leave-balances/$cardNo1',
      );

      final responseData = response.data;
      if (responseData == null) {
        throw Exception('Invalid response from server');
      }

      // API returns data in 'items' array format (ORDS REST API format)
      List<dynamic> items = [];

      // Check if response has 'body' with 'items' array
      if (responseData.containsKey('body')) {
        final body = responseData['body'] as Map<String, dynamic>?;
        if (body != null && body.containsKey('items')) {
          items = body['items'] as List<dynamic>? ?? [];
        }
      } else if (responseData.containsKey('items')) {
        // Items at root level
        items = responseData['items'] as List<dynamic>? ?? [];
      }

      // Map items to LeaveBalance entities
      return items.map((item) {
        final json = item as Map<String, dynamic>;
        final code = (json['leave_type'] ?? '').toString();
        final name = (json['leave_desc'] ?? json['leave_type'] ?? '')
            .toString();
        final balanceValue =
            json['balance'] ??
            json['available'] ??
            json['total_available'] ??
            0;
        final balance = (balanceValue is num)
            ? balanceValue.round()
            : (int.tryParse(balanceValue.toString()) ?? 0);

        return LeaveBalance(code: code, name: name, balance: balance);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('LeaveBalances API Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<LeaveRequest>> leaveRequests() async {
    if (_config.useMockData) {
      return _mockApiService.fetchLeaveRequests();
    }
    final response = await _client.get<List<dynamic>>('/leave/applications');
    throw UnimplementedError('Map leave requests ${response.data}');
  }

  @override
  Future<void> submitLeave(LeaveRequest request) async {
    if (_config.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return;
    }
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no') ?? '';
    await _client.post(
      '/auth/apply-leave/$cardNo1',
      data: {
        'from_date': request.fromDate.toIso8601String().split('T')[0],
        'to_date': request.toDate.toIso8601String().split('T')[0],
        'reason': request.reason,
        'type': request.type,
        'half_day': request.halfDay,
      },
    );
  }

  @override
  Future<List<AttendanceRecord>> attendance(DateTime from, DateTime to) async {
    if (_config.useMockData) {
      return _mockApiService.fetchAttendance(from, to);
    }
    // Attendance history is fetched via the dedicated AttendanceRemoteDataSource
    // which loops day-by-day using /auth/attendance/report/{card_no}/{date}.
    // Return empty list here as a fallback.
    return [];
  }

  @override
  Future<AttendanceSummary> attendanceSummary(
    DateTime from,
    DateTime to,
  ) async {
    if (_config.useMockData) {
      return _mockApiService.fetchAttendanceSummary();
    }
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no') ?? '';
    final response = await _client.get<Map<String, dynamic>>(
      '/auth/attendance/summary',
      queryParameters: {
        'emp_pk': cardNo1,
        'from_date': '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
        'to_date': '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}',
      },
    );
    final data = response.data ?? {};
    final body = data['body'] as Map<String, dynamic>? ?? {};
    int safeInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return AttendanceSummary(
      casualLeave: 0,
      earnedLeave: 0,
      medicalLeave: 0,
      compensatoryLeave: 0,
      sickLeave: 0,
      lossOfPay: 0,
      absent: 0,
      outdoorDuty: 0,
      approvedExtraWork: 0,
      lateCount: 0,
      totalDays: safeInt(body['total_days']),
      presentDays: safeInt(body['present']),
      incompleteDays: safeInt(body['incomplete']),
      totalMinutes: safeInt(body['total_minutes']),
    );
  }

  @override
  Future<EnhancedProfileEntity> profile() async {
    if (_config.useMockData) {
      return _mockApiService.fetchProfile();
    }

    // Get card_no from secure storage
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no');

    if (cardNo1 == null || cardNo1.isEmpty) {
      throw Exception('Card number not found. Please login again.');
    }

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/auth/profile/$cardNo1',
      );

      final responseData = response.data;
      if (responseData == null) {
        throw Exception('Invalid response from server');
      }

      // API returns data in 'body' format (ORDS REST API format)
      Map<String, dynamic>? body;
      if (responseData.containsKey('body')) {
        body = responseData['body'] as Map<String, dynamic>?;
      } else if (responseData.containsKey('items')) {
        final items = responseData['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          body = items[0] as Map<String, dynamic>?;
        }
      } else {
        // If response is directly the data object
        body = responseData as Map<String, dynamic>?;
      }

      debugPrint('Profile API Response: $responseData');
      debugPrint('Profile API Body: $body');

      if (body == null) {
        throw Exception('Invalid response: Missing data');
      }

      // Helper functions for safe parsing
      String safeString(dynamic value) {
        if (value == null) return '-';
        final str = value.toString().trim();
        return str.isEmpty ? '-' : str;
      }

      // Parse reporting manager from hod_nm and hod2
      // hod2 represents the phone number of the HOD
      ReportingManager? reportingTo;
      final hodNm = safeString(body['hod_nm']);
      final hod2 = body['hod2'];
      if (hodNm.isNotEmpty && hodNm != '-' && hod2 != null) {
        reportingTo = ReportingManager(
          id: safeString(hod2), // Use hod2 as ID (phone number)
          name: hodNm,
          designation: '', // Remove designation as per requirements
          phoneNumber: safeString(hod2), // hod2 is the phone number
        );
      }

      // Parse emergency_contact (not in API response, but keep structure)
      EmergencyContact? emergencyContact;
      // API doesn't provide emergency contact, so leave as null

      // Helper for safe int parsing
      int? safeInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) {
          return int.tryParse(value);
        }
        if (value is num) {
          return value.toInt();
        }
        return null;
      }

      final employeeCodeRaw = safeString(
        body['emp_no'] ??
            body['employee_code'] ??
            body['emp_code'] ??
            body['empno'] ??
            body['employee_no'],
      );
      final employeeCode = (employeeCodeRaw.isNotEmpty && employeeCodeRaw != '-')
          ? employeeCodeRaw
          : safeString(
              getIt<LmsLocalDataSource>().dashboard()?.empNo ??
                  body['card_no'] ??
                  body['card_no1'] ??
                  cardNo1,
            );

      // Company name arrives under several key names depending on the
      // endpoint version.
      final companyRaw = safeString(
        body['compcnm'] ??
            body['company_name'] ??
            body['company'] ??
            body['org_name'] ??
            body['organization'],
      );
      final companyName =
          companyRaw.isNotEmpty && companyRaw != '-' ? companyRaw : null;

      return EnhancedProfileEntity(
        id: safeString(body['emp_pk']),
        // Employee code arrives under several key names; fall back to the
        // dashboard cache and finally the card number so the badge is never
        // blank for a logged-in employee.
        employeeCode: employeeCode,
        name: safeString(body['emp_name']),
        email: safeString(body['email_address']),
        phoneNumber: safeString(body['mobile_no']),
        gender: safeString(body['gender'] ?? 'M'), // Not in API, default to M
        // Keep backend date strings as-is (e.g. "27-oct-2025")
        dateOfBirth: safeString(body['date_of_birth']),
        joiningDate: safeString(body['date_of_join']),
        department: safeString(body['department']),
        designation: safeString(body['designation']),
        cadre: safeString(body['cadre']),
        // Organization fields: the payload uses different key names across
        // endpoint versions, so accept every known spelling before giving up.
        location: safeString(
          body['location'] ?? body['city'] ?? body['brnchnm'],
        ),
        branch: safeString(
          body['brnchnm'] ?? body['branch_name'] ?? body['branch'],
        ),
        cardNumber: safeString(
          body['card_no'] ?? body['card_no1'] ?? body['card_number'],
        ),
        profilePictureUrl: ProfilePhotoUrl.resolve(
          body,
          cardNo: (body['card_no'] ?? body['card_no1'] ?? cardNo1)?.toString(),
        ),
        reportingTo: reportingTo,
        emergencyContact: emergencyContact,
        // The employee's own roster from HRMS web, not a hardcoded default.
        workSchedule: WorkSchedule.fromApi(body) ?? WorkSchedule.defaultSchedule,
        // Additional fields from API
        fatherName:
            safeString(body['father_name']).isNotEmpty &&
                safeString(body['father_name']) != '-'
            ? safeString(body['father_name'])
            : null,
        nicNo:
            safeString(body['nic_no']).isNotEmpty &&
                safeString(body['nic_no']) != '-'
            ? safeString(body['nic_no'])
            : null,
        eobiNo:
            safeString(body['eobi_no']).isNotEmpty &&
                safeString(body['eobi_no']) != '-'
            ? safeString(body['eobi_no'])
            : null,
        uicCardNo:
            safeString(body['uic_card_no']).isNotEmpty &&
                safeString(body['uic_card_no']) != '-'
            ? safeString(body['uic_card_no'])
            : null,
        salary: safeInt(body['salary']),
        managerAboveSts:
            safeString(body['manager_above_sts']).isNotEmpty &&
                safeString(body['manager_above_sts']) != '-'
            ? safeString(body['manager_above_sts'])
            : null,
        confirmationDate: safeString(
          body['confirmation_date'] ??
              body['confirm_date'] ??
              body['date_of_confirmation'] ??
              body['confirmation_dt'] ??
              body['perm_date'],
        ),
        companyAccommodation:
            safeString(body['company_accomodation']).isNotEmpty &&
                safeString(body['company_accomodation']) != '-'
            ? safeString(body['company_accomodation'])
            : null,
        compcnm: companyName,
        compc: safeInt(body['compc'] ?? body['company_code']),
      );
    } catch (e, stackTrace) {
      debugPrint('Profile API Error: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> updateEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    if (_config.useMockData) return;

    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no');
    if (cardNo1 == null || cardNo1.isEmpty) {
      throw Exception('Card number not found. Please login again.');
    }

    await _client.post<Map<String, dynamic>>(
      '/auth/profile/emergency-contact/$cardNo1',
      data: {
        'name': name,
        'relation': relationship,
        'phone': phone,
      },
    );
  }

  @override
  Future<List<NotificationMessage>> notifications() async {
    if (_config.useMockData) {
      return _mockApiService.fetchNotifications();
    }
    final response = await _client.get<List<dynamic>>('/notifications');
    throw UnimplementedError('Map notifications ${response.data}');
  }

  @override
  Future<void> markAttendance({required bool automatic, String? note}) async {
    if (_config.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return;
    }
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no') ?? '';
    await _client.post(
      '/auth/attendance/$cardNo1',
      data: {'automatic': automatic, 'note': note},
    );
  }

  @override
  Future<BiometricAttendanceResponse> markBiometricAttendance(
    BiometricAttendanceRequest request,
  ) async {
    if (_config.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return BiometricAttendanceResponse(
        attendanceId: 'ATT-${DateTime.now().millisecondsSinceEpoch}',
        markedAt: DateTime.now(),
        locationVerified: true,
        biometricVerified: true,
        success: true,
        message: 'Attendance marked successfully',
      );
    }

    final response = await _client.post<Map<String, dynamic>>(
      '/auth/attendance/face',
      data: request.toJson(),
    );

    return BiometricAttendanceResponse.fromJson(
      response.data ??
          {
            'header': {'code': 500, 'message': 'Unknown error'},
          },
    );
  }

  @override
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_config.useMockData) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return true;
    }

    // Get card_no from secure storage
    final secureStorage = getIt<SecureStorageService>();
    final cardNo1 = await secureStorage.read('card_no');

    if (cardNo1 == null || cardNo1.isEmpty) {
      throw Exception('Card number not found. Please login again.');
    }

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/change-password/$cardNo1',
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );

      final responseData = response.data;
      if (responseData == null) {
        throw Exception('Invalid response from server');
      }

      // Check response format
      final header = responseData['header'] as Map<String, dynamic>?;
      final body = responseData['body'] as Map<String, dynamic>?;

      final success =
          header?['code'] == 100 ||
          body?['success'] == true ||
          response.statusCode == 200;

      if (success) {
        return true;
      } else {
        final errorMessage =
            header?['message'] as String? ??
            body?['message'] as String? ??
            'Failed to change password';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Change password error: $e');
      rethrow;
    }
  }
}
