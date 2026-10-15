import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/notification_message.dart';
// import '../../domain/repositories/notification_repository.dart';
import '../../domain/usecases/get_notifications_usecase.dart';
import '../../domain/usecases/mark_notification_read_usecase.dart';
import '../../../../core/errors/error_messages.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc(
    this._getNotificationsUseCase,
    this._markNotificationReadUseCase,
  ) : super(const NotificationState()) {
    on<NotificationsRequested>(_onRequested);
    on<NotificationMarkedRead>(_onMarkedRead);
  }

  final GetNotificationsUseCase _getNotificationsUseCase;
  final MarkNotificationReadUseCase _markNotificationReadUseCase;

  Future<void> _onRequested(
    NotificationsRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(
      state.copyWith(status: NotificationStatus.loading, errorMessage: null),
    );
    try {
      final page = await _getNotificationsUseCase(event.page, event.limit);
      emit(
        state.copyWith(
          status: NotificationStatus.success,
          notifications: page.notifications,
          unreadCount: page.unreadCount,
          totalCount: page.totalCount,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: NotificationStatus.failure,
          errorMessage: ErrorMessages.from(
            e,
            fallback: 'Could not load your notifications. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _onMarkedRead(
    NotificationMarkedRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _markNotificationReadUseCase(event.id);
      final updated = state.notifications
          .map((n) => n.id == event.id ? n.copyWith(isRead: true) : n)
          .toList();
      emit(state.copyWith(notifications: updated));
    } catch (_) {}
  }
}






