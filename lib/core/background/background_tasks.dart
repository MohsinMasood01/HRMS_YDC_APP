import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/location_tracking/domain/repositories/location_repository.dart';
import '../../features/location_tracking/location_tracking_bootstrap.dart';
import '../database/location_track_db.dart';
import '../services/secure_storage_service.dart';
import '../services/tracking_session_store.dart';

/// WorkManager task name. Declared by [LocationTrackingService] and matched
/// here so a rename cannot silently orphan the scheduled work.
const String kLocationTaskName = 'lms_hourly_location';

/// Synced points older than this are pruned locally.
const Duration _retention = Duration(days: 7);

/// Entry point for the WorkManager background isolate.
///
/// This runs with the app minimised, the screen locked, or the process killed.
/// The service locator is NOT configured here, so every dependency is built by
/// hand through [createBackgroundLocationRepository].
///
/// Order is deliberate and non-negotiable:
///
///   GPS -> SQLite -> (only then) network sync
///
/// A capture is durable before any upload is attempted, so losing connectivity
/// never loses a point. Connectivity gates synchronisation alone.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != kLocationTaskName) return true;

    LocationTrackDb? db;
    try {
      // Capture only while the session is ACTIVE. PAUSED (intermediate
      // checkout) and STOPPED (final checkout) both yield null, so no points
      // are generated after a checkout until the backend says otherwise.
      final session = await TrackingSessionStore().activeSession();
      if (session == null) {
        debugPrint('[LocationTask] No active session - skipping');
        return true;
      }

      db = LocationTrackDb();
      final repository = createBackgroundLocationRepository(db);

      // 1. GPS -> SQLite. Throws rather than inventing a coordinate.
      try {
        await repository.captureAndStore(
          cardNo: session.cardNo,
          attendanceDate: session.attendanceDate,
        );
      } on LocationCaptureException catch (e) {
        // No fix this interval. Log the reason and move on to sync -- older
        // points may still be waiting, and there is nothing to fabricate.
        debugPrint('[LocationTask] No fix (${e.reason.name}): ${e.message}');
      }

      // 2. Opportunistic sync. Failure is expected offline and simply leaves
      // everything PENDING for the next interval or the connectivity listener.
      await _syncQuietly(repository);

      // 3. Housekeeping: only SYNCED rows are eligible.
      await repository.pruneSyncedOlderThan(_retention);
    } catch (e, st) {
      debugPrint('[LocationTask] Error: $e\n$st');
      // Returning true keeps the periodic schedule intact; the next interval
      // retries naturally rather than triggering WorkManager backoff.
    } finally {
      await db?.close();
    }

    return true;
  });
}

/// Syncs every pending queue, each under its own card number.
Future<void> _syncQuietly(LocationRepository repository) async {
  try {
    String? token;
    try {
      token = await SecureStorageService().read('token');
    } catch (e) {
      // Secure storage is not always reachable from a background isolate.
      // Without a token the upload will fail and the points stay PENDING for
      // the foreground to flush -- which is the correct, lossless outcome.
      debugPrint('[LocationTask] Token unavailable in background: $e');
    }

    final summary = await repository.syncPending(authToken: token);
    debugPrint('[LocationTask] $summary');
  } catch (e) {
    debugPrint('[LocationTask] Sync skipped: $e');
  }
}
