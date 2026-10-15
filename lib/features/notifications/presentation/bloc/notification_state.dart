part of 'notification_bloc.dart';

enum NotificationStatus { initial, loading, success, failure }

class NotificationState extends Equatable {
  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.totalCount = 0,
    this.errorMessage,
  });

  final NotificationStatus status;
  final List<NotificationMessage> notifications;
  final int unreadCount;
  final int totalCount;
  final String? errorMessage;

  NotificationState copyWith({
    NotificationStatus? status,
    List<NotificationMessage>? notifications,
    int? unreadCount,
    int? totalCount,
    String? errorMessage,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      totalCount: totalCount ?? this.totalCount,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    notifications,
    unreadCount,
    totalCount,
    errorMessage,
  ];
}






