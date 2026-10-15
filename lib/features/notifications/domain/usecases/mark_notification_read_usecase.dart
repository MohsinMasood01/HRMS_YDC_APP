import '../repositories/notification_repository.dart';

class MarkNotificationReadUseCase {
  MarkNotificationReadUseCase(this._repository);

  final NotificationRepository _repository;

  Future<void> call(String id) => _repository.markRead(id);
}
