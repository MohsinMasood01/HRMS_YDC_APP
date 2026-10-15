import 'package:dio/dio.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/notification_message.dart';
import '../../domain/repositories/notification_repository.dart';

abstract class NotificationRemoteDataSource {
  Future<NotificationPage> fetchNotifications({
    required String empPk,
    required int page,
    required int limit,
  });

  Future<void> markRead({required String empPk, required String id});
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  NotificationRemoteDataSourceImpl({Dio? dio})
    : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  @override
  Future<NotificationPage> fetchNotifications({
    required String empPk,
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'emp_pk': empPk, 'page': page, 'limit': limit},
    );
    final body = response.data?['body'] as Map<String, dynamic>? ?? {};
    final items = body['notifications'] as List<dynamic>? ?? [];
    final notifications = items
        .map(
          (n) => NotificationMessage(
            id: (n['id'] ?? '').toString(),
            title: (n['title'] ?? '').toString(),
            body: (n['message'] ?? '').toString(),
            createdAt: n['created_at'] != null
                ? DateTime.parse(n['created_at'] as String)
                : DateTime.now(),
            isRead: n['is_read'] == true,
          ),
        )
        .toList();

    return NotificationPage(
      notifications: notifications,
      unreadCount: _asInt(body['unread_count']),
      totalCount: _asInt(body['total_count']),
    );
  }

  @override
  Future<void> markRead({required String empPk, required String id}) async {
    await _dio.put('/notifications/$id/read', data: {'emp_pk': empPk});
  }

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}






