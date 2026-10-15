import 'package:flutter/foundation.dart';
import 'package:tracelet/tracelet.dart' as tl;
import 'package:uuid/uuid.dart';

import '../../features/location_tracking/data/tracelet_location_mapper.dart';
import '../../features/location_tracking/location_tracking_bootstrap.dart';
import '../database/location_track_db.dart';
import '../services/secure_storage_service.dart';
import '../services/tracking_session_store.dart';

/// Entry point Tracelet runs in a background Dart isolate when the app's own
/// isolate is not alive (app swiped away / process killed). Registered once in
/// `main.dart`, before `runApp()`.
///
/// The service locator does not exist in this isolate, so dependencies are
/// built by hand. Tracelet's headless engine auto-registers plugins, so
/// SQLite, SharedPreferences and secure storage are all available here.
@pragma('vm:entry-point')
void traceletHeadlessTask(tl.HeadlessEvent event) {
  debugPrint('[TraceletHeadless] ${event.name}');

  switch (event.name) {
    case 'location':
      // Fire-and-forget: the dispatcher calls this synchronously, and the
      // engine stays alive while the work completes.
      queueAndSyncHeadlessFix(event.event);
      break;
    case 'geofence':
      final geofence = tl.GeofenceEvent.fromMap(event.event);
      debugPrint(
        '[TraceletHeadless] Geofence ${geofence.action.name}: '
        '${geofence.identifier}',
      );
      break;
    default:
      break;
  }
}

/// Queues one background fix under the ACTIVE session's card number, then
/// uploads that card's pending queue. Every failure is swallowed: an upload
/// that cannot happen now leaves the point PENDING for the next fix, the
/// connectivity listener, or the next app open.
///
/// This is also where a forgotten checkout is closed while the app is not
/// running. The native engine keeps firing after the app is killed, and
/// before this check every one of those fixes was queued under a session that
/// never ended -- so an employee who did not check out was tracked for days.
/// Now the first fix after the session's cutoff closes the session and stops
/// the engine; the fix itself is dropped by its timestamp. More generally, a
/// fix that arrives with no ACTIVE session means the engine is running when it
/// should not be (expired, paused or stopped), so it is stopped every time.
Future<void> queueAndSyncHeadlessFix(Map<String, Object?> locationMap) async {
  LocationTrackDb? db;
  try {
    final store = TrackingSessionStore();

    // Past the cutoff with no checkout: close the session first. The
    // pre-expiry session is still used to map THIS fix, so one recorded before
    // the cutoff but delivered late is kept; one recorded after is dropped.
    final expired = await store.expireIfDue();
    final session = expired ?? await store.activeSession();

    final point = locationPointFromTracelet(
      locationMap,
      session: session,
      localId: const Uuid().v4(),
    );

    // No session to record for -- expired just now, or already PAUSED /
    // STOPPED -- means the engine should not be running. Stopping on every
    // such fix (not only on the expiring one) is what makes a failed stop
    // self-healing: the next fix simply tries again.
    if (expired != null || session == null) {
      await stopEngineWithoutActiveSession();
    }

    if (point == null) {
      debugPrint(
        expired != null
            ? '[TraceletHeadless] Session expired at cutoff; fix dropped'
            : '[TraceletHeadless] Fix not queued (no active session)',
      );
      // An expired session may still hold pre-cutoff points; deliver them.
      if (expired == null) return;
    }

    db = LocationTrackDb();
    final repository = createBackgroundLocationRepository(db);
    if (point != null) await repository.store(point);

    String? token;
    try {
      token = await SecureStorageService().read('token');
    } catch (_) {
      // Not required by /auth/location/batch today.
    }
    final summary = await repository.syncPending(
      cardNo: point?.cardNo ?? expired?.cardNo,
      authToken: token,
    );
    debugPrint('[TraceletHeadless] $summary');
  } catch (e, st) {
    debugPrint('[TraceletHeadless] Queue/sync failed: $e\n$st');
  } finally {
    await db?.close();
  }
}

/// Stops the capture engine from the headless isolate when it fires with no
/// ACTIVE session, so the phone stops waking up and the "Work Session Active"
/// notification goes away.
///
/// Best-effort. Stopping is permitted here because the engine runs as a
/// foreground service, which exempts the app from Android's background
/// service-start limits while it is running. If the stop still fails, nothing
/// is recorded regardless -- the fix is dropped because there is no active
/// session -- and the next fix retries this stop. The next app open also
/// stops it in `LocationTrackingService.reconcileOnStartup`.
Future<void> stopEngineWithoutActiveSession() async {
  try {
    final state = await tl.Tracelet.getState();
    if (!state.enabled) return;
    await tl.Tracelet.stop();
    debugPrint('[TraceletHeadless] Capture engine stopped (no active session)');
  } catch (e) {
    debugPrint('[TraceletHeadless] Engine stop failed: $e');
  }
}
