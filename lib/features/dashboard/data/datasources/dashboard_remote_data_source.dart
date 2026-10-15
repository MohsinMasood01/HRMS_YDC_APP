import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/dio_client.dart';
import '../models/dashboard_summary_model.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardSummaryModel> fetchDashboard(String cardNo1);
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  DashboardRemoteDataSourceImpl({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  @override
  Future<DashboardSummaryModel> fetchDashboard(String cardNo1) async {
    try {
      debugPrint(
        'DashboardRemoteDataSource: Fetching dashboard for card_no: $cardNo1',
      );
      final response = await _dio.get<Map<String, dynamic>>('/auth/dashboard/$cardNo1');

      debugPrint(
        'DashboardRemoteDataSource: Response status: ${response.statusCode}',
      );
      debugPrint('DashboardRemoteDataSource: Response data: ${response.data}');

      // API returns data in 'items' array format (ORDS REST API format)
      final responseData = response.data;
      Map<String, dynamic>? body;

      // Check if response has 'items' array (ORDS format)
      if (responseData != null && responseData.containsKey('items')) {
        final items = responseData['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) {
          body = items[0] as Map<String, dynamic>?;
          debugPrint(
            'DashboardRemoteDataSource: Found items array with ${items.length} item(s), using first item',
          );
        } else {
          debugPrint('DashboardRemoteDataSource: ERROR - Items array is empty');
          throw Exception('No dashboard data found in response');
        }
      } else if (responseData != null && responseData.containsKey('body')) {
        // Fallback to 'body' format if present
        body = responseData['body'] as Map<String, dynamic>?;
        debugPrint('DashboardRemoteDataSource: Found body structure');
      } else if (responseData is Map<String, dynamic>) {
        // If response is directly the data object
        body = responseData;
        debugPrint(
          'DashboardRemoteDataSource: Response is directly the data structure',
        );
      }

      if (body == null) {
        debugPrint(
          'DashboardRemoteDataSource: ERROR - Could not extract data from response',
        );
        debugPrint(
          'DashboardRemoteDataSource: Response keys: ${responseData?.keys.toList()}',
        );
        throw Exception('Invalid response: Missing data');
      }

      return DashboardSummaryModel.fromJson(body);
    } on DioException catch (e) {
      debugPrint('DashboardRemoteDataSource: DioException - ${e.type}');
      debugPrint('DashboardRemoteDataSource: Error message: ${e.message}');
      debugPrint(
        'DashboardRemoteDataSource: Status code: ${e.response?.statusCode}',
      );
      debugPrint(
        'DashboardRemoteDataSource: Response data: ${e.response?.data}',
      );

      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          throw Exception(
            'Dashboard data not found. Please verify your card number.',
          );
        } else if (statusCode == 401) {
          throw Exception('Unauthorized. Please login again.');
        } else if (statusCode != null && statusCode >= 500) {
          throw Exception('Server error. Please try again later.');
        }
      }

      throw Exception(e.message ?? 'Failed to fetch dashboard data');
    } catch (e) {
      debugPrint('DashboardRemoteDataSource: Unexpected error: $e');
      rethrow;
    }
  }
}
