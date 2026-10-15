import 'dart:async';

import '../../features/notifications/domain/entities/notification_message.dart';

class NotificationService {
  final _controller = StreamController<NotificationMessage>.broadcast();

  Stream<NotificationMessage> get stream => _controller.stream;

  void push(NotificationMessage message) {
    _controller.add(message);
  }

  void dispose() {
    _controller.close();
  }
}

