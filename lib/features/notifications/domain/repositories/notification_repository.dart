import '../entities/notification_message.dart';

class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.totalCount,
  });

  final List<NotificationMessage> notifications;
  final int unreadCount;
  final int totalCount;
}

abstract class NotificationRepository {
  Future<NotificationPage> fetchNotifications({
    required int page,
    required int limit,
  });

  Future<void> markRead(String id);
}






