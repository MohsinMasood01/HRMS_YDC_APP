import 'package:dio/dio.dart';

import '../../core/database/location_track_db.dart';
import '../../core/network/dio_client.dart';
import 'data/datasources/location_local_data_source.dart';
import 'data/datasources/location_remote_data_source.dart';
import 'data/repositories/location_repository_impl.dart';
import 'domain/repositories/location_repository.dart';

/// Composition helpers for the location-tracking stack.
///
/// The WorkManager background isolate cannot reach the service locator --
/// `configureDependencies()` never runs there -- so it needs a way to build
/// the same object graph by hand. Keeping both constructions here means the
/// UI isolate and the background isolate share one wiring definition instead
/// of drifting apart, which is how the old code ended up with a stale API
/// host hardcoded in the background task.

/// Builds the repository for the UI isolate.
LocationRepository createLocationRepository({
  LocationTrackDb? db,
  Dio? dio,
}) {
  final database = db ?? LocationTrackDb();
  return LocationRepositoryImpl(
    local: LocationLocalDataSource(database),
    remote: LocationRemoteDataSource(dio: dio),
  );
}

/// Builds the repository for the WorkManager background isolate.
///
/// Uses a plain [Dio] rather than [DioClient.instance]: that client carries
/// `ForceUpdateInterceptor`, which drives a blocking UI page that does not
/// exist in a background isolate. The origin still comes from
/// [DioClient.baseUrl] so there is exactly one API host in the app.
LocationRepository createBackgroundLocationRepository(LocationTrackDb db) {
  final dio = Dio(
    BaseOptions(
      baseUrl: DioClient.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );

  return LocationRepositoryImpl(
    local: LocationLocalDataSource(db),
    remote: LocationRemoteDataSource(dio: dio),
  );
}
