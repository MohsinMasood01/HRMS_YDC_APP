import '../repositories/notification_repository.dart';

class GetNotificationsUseCase {
  GetNotificationsUseCase(this._repository);

  final NotificationRepository _repository;

  Future<NotificationPage> call(int page, int limit) {
    return _repository.fetchNotifications(page: page, limit: limit);
  }
}
