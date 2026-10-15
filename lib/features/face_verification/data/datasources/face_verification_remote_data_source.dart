import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/face_embedding.dart';

/// Remote data source for face verification backend APIs
///
/// Handles:
/// - Face registration (linking face to employee_id)
/// - Face verification (comparing live face with stored face)
/// - Checking face registration status
abstract class FaceVerificationRemoteDataSource {
  /// Register face for an employee
  ///
  /// [employeeId] - Employee ID or card number
  /// [embedding] - Face embedding vector (128-dimensional)
  /// Returns true if registration successful, false if already registered
  Future<bool> registerFace({
    required String employeeId,
    required FaceEmbedding embedding,
  });

  /// Verify face for an employee
  ///
  /// [employeeId] - Employee ID or card number
  /// [embedding] - Live face embedding vector
  /// Returns verification result with match status and confidence
  Future<FaceVerificationResponse> verifyFace({
    required String employeeId,
    required FaceEmbedding embedding,
  });

  /// Check if face is registered for an employee
  ///
  /// [employeeId] - Employee ID or card number
  /// Returns true if face is registered, false otherwise
  Future<bool> isFaceRegistered(String employeeId);

  /// Delete face registration for an employee
  ///
  /// [employeeId] - Employee ID or card number
  /// Deletes the face registration from the backend
  Future<void> deleteFace(String employeeId);
}

/// Response from face verification API
class FaceVerificationResponse {
  const FaceVerificationResponse({
    required this.isMatch,
    required this.confidence,
    this.message,
  });

  final bool isMatch;
  final double confidence;
  final String? message;

  factory FaceVerificationResponse.fromJson(Map<String, dynamic> json) {
    return FaceVerificationResponse(
      isMatch: json['is_match'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String?,
    );
  }
}

class FaceVerificationRemoteDataSourceImpl
    implements FaceVerificationRemoteDataSource {
  FaceVerificationRemoteDataSourceImpl({Dio? dio, AppConfig? config})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: (config ?? const AppConfig()).faceAuthBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              contentType: 'application/json',
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  @override
  Future<bool> registerFace({
    required String employeeId,
    required FaceEmbedding embedding,
  }) async {
    try {
      debugPrint(
        'FaceVerificationRemoteDataSource: Registering face for employee: $employeeId',
      );

      final response = await _dio.post<Map<String, dynamic>>(
        '/face/register',
        data: {
          'employee_id': employeeId,
          'embedding': embedding.embedding,
          'created_at': embedding.createdAt.toIso8601String(),
        },
      );

      final body =
          response.data?['body'] as Map<String, dynamic>? ??
          (response.data != null ? response.data as Map<String, dynamic> : {});

      final status = body['status'] as String? ?? '';
      final alreadyRegistered = body['already_registered'] as bool? ?? false;

      debugPrint(
        'FaceVerificationRemoteDataSource: Registration response - '
        'status: $status, already_registered: $alreadyRegistered',
      );

      // Return true if successful, false if already registered
      return status.toLowerCase() == 'success' || alreadyRegistered;
    } on DioException catch (e) {
      debugPrint(
        'FaceVerificationRemoteDataSource: Registration error - ${e.type}',
      );
      debugPrint(
        'FaceVerificationRemoteDataSource: Error message: ${e.message}',
      );
      debugPrint(
        'FaceVerificationRemoteDataSource: Status code: ${e.response?.statusCode}',
      );

      // If 409 Conflict, face is already registered
      if (e.response?.statusCode == 409) {
        debugPrint(
          'FaceVerificationRemoteDataSource: Face already registered for employee',
        );
        return false; // Already registered
      }

      // If 404, endpoint doesn't exist yet (backend not implemented)
      if (e.response?.statusCode == 404) {
        debugPrint(
          'FaceVerificationRemoteDataSource: Face registration endpoint not found (404). '
          'Backend may not be implemented yet.',
        );
        // For now, we'll throw an exception to indicate the feature isn't available
        throw Exception(
          'Face registration is not available. The backend endpoint is not implemented yet.',
        );
      }

      // For other errors, rethrow
      throw Exception(
        e.response?.data?['message'] as String? ??
            'Failed to register face: ${e.message}',
      );
    } catch (e) {
      debugPrint('FaceVerificationRemoteDataSource: Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<FaceVerificationResponse> verifyFace({
    required String employeeId,
    required FaceEmbedding embedding,
  }) async {
    try {
      debugPrint(
        'FaceVerificationRemoteDataSource: Verifying face for employee: $employeeId',
      );

      final response = await _dio.post<Map<String, dynamic>>(
        '/face/verify',
        data: {'employee_id': employeeId, 'embedding': embedding.embedding},
      );

      final body =
          response.data?['body'] as Map<String, dynamic>? ??
          (response.data != null ? response.data as Map<String, dynamic> : {});

      debugPrint(
        'FaceVerificationRemoteDataSource: Verification response: $body',
      );

      return FaceVerificationResponse.fromJson(body);
    } on DioException catch (e) {
      debugPrint(
        'FaceVerificationRemoteDataSource: Verification error - ${e.type}',
      );
      debugPrint(
        'FaceVerificationRemoteDataSource: Error message: ${e.message}',
      );
      debugPrint(
        'FaceVerificationRemoteDataSource: Status code: ${e.response?.statusCode}',
      );

      // If 404, face not registered
      if (e.response?.statusCode == 404) {
        return const FaceVerificationResponse(
          isMatch: false,
          confidence: 0.0,
          message: 'Face not registered for this employee',
        );
      }

      // For other errors, return failure
      return FaceVerificationResponse(
        isMatch: false,
        confidence: 0.0,
        message:
            e.response?.data?['message'] as String? ??
            'Face verification failed: ${e.message}',
      );
    } catch (e) {
      debugPrint('FaceVerificationRemoteDataSource: Unexpected error: $e');
      return FaceVerificationResponse(
        isMatch: false,
        confidence: 0.0,
        message: 'Face verification failed: $e',
      );
    }
  }

  @override
  Future<bool> isFaceRegistered(String employeeId) async {
    try {
      debugPrint(
        'FaceVerificationRemoteDataSource: Checking face registration for employee: $employeeId',
      );

      final response = await _dio.get<Map<String, dynamic>>(
        '/face/status/$employeeId',
      );

      final body =
          response.data?['body'] as Map<String, dynamic>? ??
          (response.data != null ? response.data as Map<String, dynamic> : {});

      final isRegistered = body['is_registered'] as bool? ?? false;

      debugPrint(
        'FaceVerificationRemoteDataSource: Face registration status: $isRegistered',
      );

      return isRegistered;
    } on DioException catch (e) {
      debugPrint(
        'FaceVerificationRemoteDataSource: Status check error - ${e.type}',
      );
      debugPrint(
        'FaceVerificationRemoteDataSource: Error message: ${e.message}',
      );

      // If 404, face is not registered
      if (e.response?.statusCode == 404) {
        return false;
      }

      // For other errors, assume not registered
      return false;
    } catch (e) {
      debugPrint('FaceVerificationRemoteDataSource: Unexpected error: $e');
      return false;
    }
  }

  @override
  Future<void> deleteFace(String employeeId) async {
    try {
      debugPrint(
        'FaceVerificationRemoteDataSource: Deleting face for employee: $employeeId',
      );

      await _dio.delete<Map<String, dynamic>>('/face/delete/$employeeId');

      debugPrint(
        'FaceVerificationRemoteDataSource: Face deleted successfully for employee: $employeeId',
      );
    } on DioException catch (e) {
      debugPrint('FaceVerificationRemoteDataSource: Delete error - ${e.type}');
      debugPrint(
        'FaceVerificationRemoteDataSource: Error message: ${e.message}',
      );
      debugPrint(
        'FaceVerificationRemoteDataSource: Status code: ${e.response?.statusCode}',
      );

      // If 404, face was not registered (already deleted or never existed)
      if (e.response?.statusCode == 404) {
        debugPrint(
          'FaceVerificationRemoteDataSource: Face not found for employee (may already be deleted)',
        );
        return; // Consider it successful if already deleted
      }

      // For other errors, rethrow
      throw Exception(
        e.response?.data?['message'] as String? ??
            'Failed to delete face: ${e.message}',
      );
    } catch (e) {
      debugPrint('FaceVerificationRemoteDataSource: Unexpected error: $e');
      rethrow;
    }
  }
}
