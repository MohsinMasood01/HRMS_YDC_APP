import 'package:equatable/equatable.dart';

class NotificationMessage extends Equatable {
  const NotificationMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  NotificationMessage copyWith({bool? isRead}) {
    return NotificationMessage(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  List<Object?> get props => [id, title, body, createdAt, isRead];
}

