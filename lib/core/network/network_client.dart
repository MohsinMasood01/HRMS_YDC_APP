import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

// ignore_for_file: todo

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import '../services/secure_storage_service.dart';
import '../../di/service_locator.dart';

class NetworkClient {
  NetworkClient(this._config) : _dio = _createDio(_config);

  final AppConfig _config;
  final Dio _dio;

  static Dio _createDio(AppConfig config) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(
          seconds: 30,
        ), // Increased for physical devices
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Configure SSL certificate handling for physical devices
    // This allows connections to work on both emulator and physical devices
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      // For development/testing: allow bad certificates
      // In production, you should use proper certificate validation
      client.badCertificateCallback = (cert, host, port) {
        // Allow self-signed certificates for development
        // TODO: Replace with proper certificate validation in production
        return true;
      };
      return client;
    };

    return dio;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // Get token from secure storage if available
      final secureStorage = getIt<SecureStorageService>();
      final token = await secureStorage.read('token');

      // Add authorization header if token exists
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      debugPrint('API GET Request: $path');
      // Header names only: the values include the Bearer token.
      debugPrint('Headers: ${headers.keys.toList()}');
      debugPrint('Query Parameters: $queryParameters');

      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Data: ${response.data}');

      return response;
    } on DioException catch (error) {
      debugPrint('API Error: ${error.message}');
      debugPrint('API Error Type: ${error.type}');
      debugPrint('API Error Response: ${error.response?.data}');
      debugPrint('API Error Status Code: ${error.response?.statusCode}');
      throw NetworkException(
        error.response?.data?['message'] as String? ??
            error.message ??
            'Network error',
      );
    } catch (e) {
      debugPrint('Unexpected error: $e');
      throw NetworkException('Unexpected error: $e');
    }
  }

  Future<Response<T>> post<T>(String path, {Object? data}) async {
    try {
      // Get token from secure storage if available
      final secureStorage = getIt<SecureStorageService>();
      final token = await secureStorage.read('token');

      // Add authorization header if token exists
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      debugPrint('API POST Request: $path');
      // Header names only: the values include the Bearer token.
      debugPrint('Headers: ${headers.keys.toList()}');
      debugPrint('Request Data: $data');

      final response = await _dio.post<T>(
        path,
        data: data,
        options: Options(headers: headers),
      );

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Data: ${response.data}');

      return response;
    } on DioException catch (error) {
      debugPrint('API Error: ${error.message}');
      debugPrint('API Error Type: ${error.type}');
      debugPrint('API Error Response: ${error.response?.data}');
      debugPrint('API Error Status Code: ${error.response?.statusCode}');
      throw NetworkException(
        error.response?.data?['message'] as String? ??
            error.message ??
            'Network error',
      );
    } catch (e) {
      debugPrint('Unexpected error: $e');
      throw NetworkException('Unexpected error: $e');
    }
  }

  AppConfig get config => _config;
}
