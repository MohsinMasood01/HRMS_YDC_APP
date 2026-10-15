import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remoteDataSource, this._empPkProvider);

  final NotificationRemoteDataSource _remoteDataSource;
  final Future<String?> Function() _empPkProvider;

  @override
  Future<NotificationPage> fetchNotifications({
    required int page,
    required int limit,
  }) async {
    final empPk = await _empPkProvider() ?? '';
    return _remoteDataSource.fetchNotifications(
      empPk: empPk,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<void> markRead(String id) async {
    final empPk = await _empPkProvider() ?? '';
    await _remoteDataSource.markRead(empPk: empPk, id: id);
  }
}






