import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../models/face_identify_response_model.dart';
import '../models/face_register_response_model.dart';
import '../models/face_status_response_model.dart';
import '../models/face_verify_response_model.dart';

/// Remote data source for face authentication API
abstract class FaceRemoteDataSource {
  Future<FaceRegisterResponseModel> registerFace({
    required String cardNo1,
    required List<String> frames,
    required DateTime createdAt,
  });

  Future<FaceVerifyResponseModel> verifyFace({
    required String cardNo1,
    required List<String> frames,
  });

  Future<FaceStatusResponseModel> getFaceStatus(String cardNo1);

  Future<FaceIdentifyResponseModel> identifyFace({
    required List<String> frames,
  });
}

class FaceRemoteDataSourceImpl implements FaceRemoteDataSource {
  FaceRemoteDataSourceImpl({required AppConfig config, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: config.faceAuthBaseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Content-Type': 'application/json',
                // 'Accept': 'application/json'
              },
            ),
          );

  final Dio _dio;

  @override
  Future<FaceRegisterResponseModel> registerFace({
    required String cardNo1,
    required List<String> frames,
    required DateTime createdAt,
  }) async {
    try {
      debugPrint(
        'FaceRemoteDataSource: Registering face for card_no: $cardNo1 with ${frames.length} frames',
      );
      debugPrint('FaceRemoteDataSource: Backend URL: ${_dio.options.baseUrl}');

      if (frames.length < 5) {
        throw Exception('Minimum 5 frames required for registration');
      }

      final requestData = {
        'card_no1': cardNo1,
        'frames': frames,
        'created_at': createdAt.toIso8601String(),
      };

      debugPrint(
        'FaceRemoteDataSource: Full URL: ${_dio.options.baseUrl}/face/register',
      );

      final response = await _dio.post<Map<String, dynamic>>(
        '/face/register',
        data: requestData,
      );

      debugPrint(
        'FaceRemoteDataSource: Registration response: ${response.data}',
      );

      return FaceRegisterResponseModel.fromJson(response.data ?? {});
    } on DioException catch (e) {
      debugPrint('FaceRemoteDataSource: Registration error: ${e.message}');
      debugPrint(
        'FaceRemoteDataSource: Status code: ${e.response?.statusCode}',
      );
      debugPrint('FaceRemoteDataSource: Response: ${e.response?.data}');

      if (e.response?.data != null) {
        try {
          return FaceRegisterResponseModel.fromJson(e.response!.data!);
        } catch (_) {
          // Fall through to throw exception
        }
      }

      throw Exception(
        e.response?.data?['body']?['msg'] as String? ??
            e.response?.data?['msg'] as String? ??
            'Failed to register face: ${e.message}',
      );
    } catch (e) {
      debugPrint('FaceRemoteDataSource: Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<FaceVerifyResponseModel> verifyFace({
    required String cardNo1,
    required List<String> frames,
  }) async {
    try {
      debugPrint(
        'FaceRemoteDataSource: Verifying face for card_no: $cardNo1 with ${frames.length} frames',
      );

      if (frames.length < 3) {
        throw Exception('Minimum 3 frames required for verification');
      }

      final requestData = {'card_no1': cardNo1, 'frames': frames};

      final response = await _dio.post<Map<String, dynamic>>(
        '/face/verify',
        data: requestData,
      );

      debugPrint(
        'FaceRemoteDataSource: Verification response: ${response.data}',
      );

      return FaceVerifyResponseModel.fromJson(response.data ?? {});
    } on DioException catch (e) {
      debugPrint('FaceRemoteDataSource: Verification error: ${e.message}');
      debugPrint(
        'FaceRemoteDataSource: Status code: ${e.response?.statusCode}',
      );

      if (e.response?.data != null) {
        try {
          return FaceVerifyResponseModel.fromJson(e.response!.data!);
        } catch (_) {
          // Fall through to throw exception
        }
      }

      throw Exception(
        e.response?.data?['body']?['msg'] as String? ??
            e.response?.data?['msg'] as String? ??
            'Failed to verify face: ${e.message}',
      );
    } catch (e) {
      debugPrint('FaceRemoteDataSource: Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<FaceStatusResponseModel> getFaceStatus(String cardNo1) async {
    try {
      debugPrint(
        'FaceRemoteDataSource: Checking face status for card_no: $cardNo1',
      );

      final response = await _dio.get<Map<String, dynamic>>(
        '/face/status/$cardNo1',
      );

      debugPrint('FaceRemoteDataSource: Status response: ${response.data}');

      return FaceStatusResponseModel.fromJson(response.data ?? {});
    } on DioException catch (e) {
      debugPrint('FaceRemoteDataSource: Status check error: ${e.message}');
      debugPrint(
        'FaceRemoteDataSource: Status code: ${e.response?.statusCode}',
      );

      // 404 means not registered, return not registered response
      if (e.response?.statusCode == 404) {
        return FaceStatusResponseModel.notRegistered();
      }

      if (e.response?.data != null) {
        try {
          return FaceStatusResponseModel.fromJson(e.response!.data!);
        } catch (_) {
          // Fall through to return not registered
        }
      }

      // Default to not registered on error
      return FaceStatusResponseModel.notRegistered();
    } catch (e) {
      debugPrint('FaceRemoteDataSource: Unexpected error: $e');
      // Default to not registered on error
      return FaceStatusResponseModel.notRegistered();
    }
  }

  @override
  Future<FaceIdentifyResponseModel> identifyFace({
    required List<String> frames,
  }) async {
    try {
      debugPrint(
        'FaceRemoteDataSource: Identifying face with ${frames.length} frames',
      );

      if (frames.length < 5) {
        throw Exception('Minimum 5 frames required for identification');
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/face/identify',
        data: {'frames': frames},
      );

      debugPrint(
        'FaceRemoteDataSource: Identify response: ${response.data}',
      );

      return FaceIdentifyResponseModel.fromJson(response.data ?? {});
    } on DioException catch (e) {
      debugPrint('FaceRemoteDataSource: Identify error: ${e.message}');

      if (e.response?.data != null) {
        try {
          return FaceIdentifyResponseModel.fromJson(e.response!.data!);
        } catch (_) {}
      }

      throw Exception(
        e.response?.data?['body']?['message'] as String? ??
            e.response?.data?['message'] as String? ??
            'Failed to identify face: ${e.message}',
      );
    } catch (e) {
      debugPrint('FaceRemoteDataSource: Unexpected error: $e');
      rethrow;
    }
  }
}
