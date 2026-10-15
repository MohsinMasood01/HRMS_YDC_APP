import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/services/app_version_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../di/service_locator.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String username, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  @override
  Future<UserModel> login(String username, String password) async {
    // Prepare request data according to actual API specification:
    // Request body: {"username": "...", "password": "...", ...version fields}
    // The version fields let the server enforce a minimum supported build
    // and return HTTP 426 (caught globally by ForceUpdateInterceptor) when
    // the installed app is too old. Fields are optional/backward-compatible.
    final versions = getIt<AppVersionService>();
    final appVersion = await versions.version();
    final appBuild = await versions.build();
    final requestData = {
      'username': username,
      'password': password,
      'app_version': appVersion,
      'app_build': appBuild,
      'platform': 'android',
    };

    try {
      debugPrint(
        'AuthRemoteDataSource: Making login request - Username: $username',
      );
      debugPrint('AuthRemoteDataSource: Base URL: ${_dio.options.baseUrl}');

      // Actual API specification:
      // - Endpoint: POST /auth/login
      // - Request body: {"username": "...", "password": "..."}
      // - Response: {"status": "SUCCESS", "card_no": "..."}
      // - No token in response
      final endpoint = '/auth/login';

      debugPrint('AuthRemoteDataSource: Calling endpoint: $endpoint');
      debugPrint('AuthRemoteDataSource: Request data: $requestData');
      debugPrint(
        'AuthRemoteDataSource: Full URL will be: ${_dio.options.baseUrl}$endpoint',
      );

      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint(
        'AuthRemoteDataSource: Response status: ${response.statusCode}, '
        'Data: ${_redactToken(response.data)}',
      );

      // Parse response according to actual API spec:
      // {
      //   "body": {
      //     "status": "SUCCESS",
      //     "userid": "3458000041"
      //   }
      // }
      // OR the response might be directly in the body without wrapping
      final responseData = response.data;
      debugPrint(
        'AuthRemoteDataSource: Full response data: ${_redactToken(responseData)}',
      );
      debugPrint(
        'AuthRemoteDataSource: Response data type: ${responseData.runtimeType}',
      );

      if (responseData == null) {
        debugPrint('AuthRemoteDataSource: ERROR - Response data is null');
        throw Exception('Invalid response from server');
      }

      // Try to get body - it might be nested or direct
      // responseData is guaranteed to be non-null here
      final responseMap = responseData;
      Map<String, dynamic>? body;
      String status = '';
      String userid = '';

      // Check if response has a 'body' key
      if (responseMap.containsKey('body')) {
        body = responseMap['body'] as Map<String, dynamic>?;
        debugPrint('AuthRemoteDataSource: Found nested body structure');
      } else {
        // Response might be directly the body structure
        body = responseMap;
        debugPrint(
          'AuthRemoteDataSource: Response is directly the body structure',
        );
      }

      debugPrint('AuthRemoteDataSource: Body: ${_redactToken(body)}');

      if (body != null) {
        status = body['status']?.toString().toUpperCase() ?? '';
        // Try to get userid from response, but if not available, use username (phone number)
        userid =
            body['userid']?.toString() ??
            body['user_id']?.toString() ??
            body['userId']?.toString() ??
            body['phoneNumber']?.toString() ??
            body['phone_number']?.toString() ??
            '';
      } else {
        debugPrint(
          'AuthRemoteDataSource: ERROR - Could not extract body from response',
        );
        debugPrint(
          'AuthRemoteDataSource: Full response structure: ${_redactToken(responseData)}',
        );
        throw Exception('Invalid response format: Missing body');
      }

      // Check status in body
      final finalStatus = status;

      debugPrint('AuthRemoteDataSource: Status: $finalStatus');

      // API returns "SUCCESS" for successful login
      if (finalStatus != 'SUCCESS') {
        final errorMessage =
            body['message']?.toString() ??
            body['error']?.toString() ??
            'Login failed. Please check your credentials.';
        debugPrint(
          'AuthRemoteDataSource: Login failed - Status: $finalStatus, Message: $errorMessage',
        );
        throw Exception(errorMessage);
      }

      // Extract card_no from response if available
      String? cardNo1 = body['card_no']?.toString();
      if (cardNo1 == null || cardNo1.isEmpty) {
        // Try alternative field names
        cardNo1 =
            body['cardNo1']?.toString() ??
            body['card_no']?.toString() ??
            body['card_number']?.toString() ??
            body['cardNumber']?.toString();
      }

      debugPrint(
        'AuthRemoteDataSource: Extracted card_no: ${cardNo1 ?? "not found"}',
      );
      debugPrint(
        'AuthRemoteDataSource: Available body keys: ${body.keys.toList()}',
      );

      // If userid is not in response, use the username (phone number) from the login request
      final finalUserid = userid.isEmpty ? username : userid;

      debugPrint(
        'AuthRemoteDataSource: User ID: $finalUserid (from ${userid.isEmpty ? "username" : "response"})',
      );

      // Store username (phone number) in secure storage for future API calls
      // Note: API doesn't return token, so we just store the username
      final secureStorage = getIt<SecureStorageService>();
      await secureStorage.write('phone_number', finalUserid);

      // Store card_no if available (used for all API calls)
      if (cardNo1 != null && cardNo1.isNotEmpty) {
        await secureStorage.write('card_no', cardNo1);
        // Also store as card_no1 — face verification BLoC reads this key
        await secureStorage.write('card_no1', cardNo1);
        // Also store as emp_pk — backend URLs use card_no for everything,
        // and empPkProvider is used by leave-submit & attendance repos.
        await secureStorage.write('emp_pk', cardNo1);
        debugPrint(
          'AuthRemoteDataSource: Stored card_no, card_no1 & emp_pk: $cardNo1',
        );
      }

      // `session_token` is the Bearer token for the authenticated /auth/*
      // endpoints (payslips, location sync, attendance reports). Every caller
      // reads it from the 'token' key. It is cleared when there is none, so a
      // previous employee's token is never reused. Never log it.
      final sessionToken =
          (body['session_token'] ?? responseMap['session_token'])
              ?.toString()
              .trim();
      if (sessionToken != null && sessionToken.isNotEmpty) {
        await secureStorage.write('token', sessionToken);
      } else {
        await secureStorage.delete('token');
      }

      // Store additional login response fields from backend
      final empName = body['emp_name']?.toString() ?? '';
      if (empName.isNotEmpty) {
        await secureStorage.write('emp_name', empName);
      }
      final faceRegistered = body['face_registered'] == true ? 'Y' : 'N';
      await secureStorage.write('face_registered', faceRegistered);
      final hrAdmin = body['hr_admin'] == true ? 'Y' : 'N';
      await secureStorage.write('hr_admin', hrAdmin);
      debugPrint(
        'AuthRemoteDataSource: Stored emp_name: $empName, '
        'face_registered: $faceRegistered, hr_admin: $hrAdmin',
      );

      // Create user model with userid from response
      // Note: Full user details will be fetched from /data/{phoneNumber} endpoint later
      final user = UserModel(
        id: finalUserid,
        name: '', // Will be populated from dashboard API
        employeeCode: '', // Will be populated from dashboard API
        department: '', // Will be populated from dashboard API
        designation: '', // Will be populated from dashboard API
        location: '', // Will be populated from dashboard API
        cardNumber: '', // Will be populated from dashboard API
      );

      debugPrint(
        'AuthRemoteDataSource: Login successful - User ID: ${user.id}',
      );
      return user;
    } on DioException catch (e) {
      // Handle Dio errors with detailed logging
      debugPrint(
        'AuthRemoteDataSource: DioException - Type: ${e.type}, '
        'Message: ${e.message}, Status Code: ${e.response?.statusCode}',
      );

      if (e.response != null) {
        final responseData = e.response?.data;
        debugPrint(
          'AuthRemoteDataSource: Error response data type: ${responseData.runtimeType}',
        );

        // Try to extract error message from API response
        // Actual API format: {"body": {"status": "...", "message": "..."}}
        String? message;
        if (responseData is Map<String, dynamic>) {
          // Check body first (actual API format)
          final body = responseData['body'] as Map<String, dynamic>?;
          if (body != null) {
            message = body['message']?.toString();
          }

          // Fallback to top-level message or other fields
          if (message == null || message.isEmpty) {
            message =
                responseData['message']?.toString() ??
                responseData['error']?.toString() ??
                responseData['errorMessage']?.toString();
          }
        }

        // For 404 errors, provide user-friendly message
        if (e.response?.statusCode == 404) {
          message =
              'Login endpoint not found. Please verify the API endpoint or contact support.';
        }

        final errorMessage = message?.isNotEmpty == true
            ? message!
            : (e.message ?? 'Login failed');
        debugPrint('AuthRemoteDataSource: Throwing error: $errorMessage');
        throw Exception(errorMessage);
      }

      final errorMessage = e.message ?? 'Network error';
      debugPrint('AuthRemoteDataSource: Network error: $errorMessage');
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      debugPrint(
        'AuthRemoteDataSource: Unexpected error: $e\nStack trace: $stackTrace',
      );
      rethrow;
    }
  }

  /// Copy of a login response with `session_token` masked, for logging.
  static Object? _redactToken(Object? data) {
    if (data is! Map) return data;
    return data.map(
      (key, value) => MapEntry(
        key,
        key == 'session_token' ? '<redacted>' : _redactToken(value),
      ),
    );
  }
}
