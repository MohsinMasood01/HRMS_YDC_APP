import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../models/enhanced_profile_model.dart';

abstract class ProfileRemoteDataSource {
  Future<EnhancedProfileModel> fetchProfile(String empPk);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  @override
  Future<EnhancedProfileModel> fetchProfile(String empPk) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/profile/$empPk',
    );
    // Backend returns a flat object; fall back to empty map on null
    final body = response.data ?? {};
    return EnhancedProfileModel.fromJson(body);
  }
}






