import '../../../../data/datasources/lms_remote_data_source.dart';
import '../../domain/repositories/geofence_repository.dart';

class GeoFenceRepositoryImpl implements GeoFenceRepository {
  GeoFenceRepositoryImpl(this._remoteDataSource);

  final LmsRemoteDataSource _remoteDataSource;

  @override
  Future<void> manualOverride({String? note}) {
    return _remoteDataSource.markAttendance(automatic: false, note: note);
  }

  @override
  Future<void> markAutomaticCheckIn() {
    return _remoteDataSource.markAttendance(automatic: true);
  }
}

