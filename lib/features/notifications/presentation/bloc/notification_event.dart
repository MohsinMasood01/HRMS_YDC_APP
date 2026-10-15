part of 'notification_bloc.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class NotificationsRequested extends NotificationEvent {
  const NotificationsRequested({this.page = 1, this.limit = 20});

  final int page;
  final int limit;

  @override
  List<Object?> get props => [page, limit];
}

class NotificationMarkedRead extends NotificationEvent {
  const NotificationMarkedRead(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}






