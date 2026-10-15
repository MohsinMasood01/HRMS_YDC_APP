import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tracelet/tracelet.dart' as tl;

import 'location_tracking_config_service.dart';

/// Thin wrapper around the Tracelet background-geolocation SDK.
///
/// [LocationTrackingService] owns the tracking STATE MACHINE (ACTIVE /
/// PAUSED / STOPPED, resumable sessions, HR-interval resolution, the
/// notification). This class owns only the CAPTURE ENGINE: starting and
/// stopping periodic fixes, keeping the interval in step with HR's setting,
/// and registering the employee's attendance geofence.
///
/// ---------------------------------------------------------------------
/// Capture only -- delivery goes through the app's own sync queue
/// ---------------------------------------------------------------------
/// Tracelet's built-in HTTP sync is deliberately NOT configured. Every fix it
/// records is handed to [onFix] (foreground) or to the headless `location`
/// event (app killed); both write it into the local queue under the ACTIVE
/// session's card number, and `LocationRepository.syncPending` uploads it to
/// the backend's real endpoint, `POST /auth/location/batch`, one card per
/// request. That keeps attribution and delivery in code this app controls and
/// tests, instead of in a native payload builder whose output cannot be
/// verified from Dart.
///
/// ---------------------------------------------------------------------
/// Capture mode -- periodic, not continuous
/// ---------------------------------------------------------------------
/// The system takes one GPS fix every HR-configured interval, not a
/// continuous trail. `Tracelet.startPeriodic()` with
/// `GeoConfig.periodicLocationInterval` (seconds) wakes the location provider
/// for a single fix per interval, scheduled by WorkManager on Android.
///
/// Tracelet's engine is binary (running / stopped). PAUSED and STOPPED both
/// mean "stopped" here; which of the two it was lives in
/// `TrackingSessionStore`.
class TraceletService {
  TraceletService({LocationTrackingConfigService? configService})
    : _configService = configService ?? LocationTrackingConfigService();

  final LocationTrackingConfigService _configService;

  bool _readied = false;
  bool _listening = false;

  /// Receives every fix Tracelet records while the app's Dart isolate is
  /// alive, as a `Location.toMap()` map. Set by [LocationTrackingService].
  void Function(Map<String, Object?> locationMap)? onFix;

  /// Registers foreground listeners and calls `Tracelet.ready()`.
  ///
  /// [intervalMinutes] is the active session's interval, when there is one.
  /// `ready()` auto-resumes periodic tracking with whatever schedule it is
  /// given, so passing it here makes that resumed schedule already correct
  /// instead of the 15-minute default that [start] would then have to replace.
  ///
  /// Headless entry points are registered separately in `main.dart`, before
  /// `runApp()`, because they must be reachable when the app is not running.
  Future<void> init({int? intervalMinutes}) async {
    if (!_listening) {
      _listening = true;
      tl.Tracelet.onLocation((location) {
        debugPrint(
          '[Tracelet] fix ${location.coords.latitude}, '
          '${location.coords.longitude} (±${location.coords.accuracy}m) '
          'uuid=${location.uuid}',
        );
        onFix?.call(location.toMap());
      });
      tl.Tracelet.onGeofence((event) {
        debugPrint(
          '[Tracelet] geofence ${event.action.name}: ${event.identifier}',
        );
      });
    }

    if (_readied) return;

    // Bounded: a native init that never returns must not leave the rest of
    // the app waiting on it. On timeout _readied stays false, so the next
    // start() retries ready() rather than starting an unconfigured engine.
    await tl.Tracelet.ready(_baseConfig(intervalMinutes: intervalMinutes))
        .timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('Tracelet.ready() did not complete in 15s');
      },
    );
    _readied = true;
  }

  /// Base configuration, optionally carrying the session's capture interval.
  tl.Config _baseConfig({int? intervalMinutes}) {
    final base = _staticBaseConfig();
    if (intervalMinutes == null) return base;
    final interval = _intervalConfig(intervalMinutes);
    return tl.Config(
      geo: base.geo.copyWith(
        periodicLocationInterval: interval.geo.periodicLocationInterval,
      ),
      app: base.app,
      motion: interval.motion,
      android: base.android.copyWith(
        periodicUseForegroundService:
            interval.android.periodicUseForegroundService,
      ),
      ios: base.ios,
    );
  }

  static tl.Config _staticBaseConfig() {
    return const tl.Config(
      geo: tl.GeoConfig(
        // Street-level precision; accuracy prioritised over battery.
        desiredAccuracy: tl.DesiredAccuracy.high,
        periodicDesiredAccuracy: tl.DesiredAccuracy.high,
        filter: tl.LocationFilter(
          // Mock-location rejection was explicitly declined.
          rejectMockLocations: false,
        ),
        // The app reverse-geocodes addresses itself (GeocodingService).
        resolveAddress: false,
      ),
      app: tl.AppConfig(
        // Keep capturing after the app is swiped away (Android). iOS cannot
        // resume after a user force-quit regardless of this flag.
        stopOnTerminate: false,
        startOnBoot: false,
      ),
      android: tl.AndroidConfig(
        foregroundService: tl.ForegroundServiceConfig(
          enabled: true,
          channelName: 'Work Session Tracking',
          notificationTitle: 'Work Session Active',
          notificationText:
              'Your location is being tracked during your work session',
          notificationOngoing: true,
        ),
      ),
      ios: tl.IosConfig(showsBackgroundLocationIndicator: true),
      // No `http` url on purpose: see the class doc comment. Tracelet keeps
      // its own copy of each fix for a few days (PersistenceConfig default),
      // which is what [recordedLocations] backfills from.
    );
  }

  // -----------------------------------------------------------------------
  // Engine control
  // -----------------------------------------------------------------------

  /// Starts (or re-affirms) periodic capture at [intervalMinutes].
  ///
  /// Always stops first. Seen on a device: `ready()` auto-resumes periodic
  /// tracking on its persisted/default schedule (15 min, WorkManager), and a
  /// following `startPeriodic()` on the foreground-service strategy did not
  /// cancel it -- two independent timers ran and points arrived every ~5
  /// minutes instead of every 10. Stopping first leaves exactly one.
  Future<void> start({required int intervalMinutes}) async {
    await init(intervalMinutes: intervalMinutes);

    // Already running exactly this schedule: leave it alone. Restarting would
    // reset the timer and take an extra fix on every app open, which makes
    // the trail irregular (and a 10-minute test unreadable).
    if (await _isRunning(intervalMinutes)) {
      debugPrint(
        '[TraceletService] periodic capture already running every '
        '${intervalMinutes}m -- not restarting',
      );
      return;
    }

    try {
      await tl.Tracelet.stop();
    } catch (e) {
      debugPrint('[TraceletService] stop before start skipped: $e');
    }
    await tl.Tracelet.setConfig(_intervalConfig(intervalMinutes));
    await tl.Tracelet.startPeriodic();
  }

  /// True when periodic capture is enabled with exactly this interval and
  /// scheduler. Any doubt (no state, no config) counts as "not running".
  Future<bool> _isRunning(int intervalMinutes) async {
    try {
      final state = await tl.Tracelet.getState();
      return isSameSchedule(
        enabled: state.enabled,
        trackingMode: state.trackingMode,
        config: state.config,
        intervalMinutes: intervalMinutes,
      );
    } catch (e) {
      debugPrint('[TraceletService] getState failed, restarting: $e');
      return false;
    }
  }

  /// Pure comparison behind [_isRunning], exposed for tests.
  @visibleForTesting
  static bool isSameSchedule({
    required bool enabled,
    required tl.TrackingMode trackingMode,
    required tl.Config? config,
    required int intervalMinutes,
  }) {
    if (!enabled || trackingMode != tl.TrackingMode.periodic) return false;
    if (config == null) return false;
    final wanted = _intervalConfig(intervalMinutes);
    return config.geo.periodicLocationInterval ==
            wanted.geo.periodicLocationInterval &&
        config.motion.stationaryPeriodicInterval ==
            wanted.motion.stationaryPeriodicInterval &&
        config.android.periodicUseForegroundService ==
            wanted.android.periodicUseForegroundService;
  }

  /// Applies a new interval without stopping capture.
  Future<void> setIntervalMinutes(int intervalMinutes) async {
    await tl.Tracelet.setConfig(_intervalConfig(intervalMinutes));
  }

  /// Interval plus the scheduler that delivers it: ALWAYS the
  /// foreground-service timer.
  ///
  /// Seen in production on two Xiaomi phones: capture on the default
  /// WorkManager scheduler took the check-in fix, then never ran again -- not
  /// once in over two hours -- because MIUI kills background jobs. Tracelet
  /// warns about exactly this on aggressive OEMs. A foreground service (with
  /// the "Work Session Active" notification) is treated as user-visible work
  /// and is far less likely to be killed. It also lifts WorkManager's
  /// 15-minute floor. It must be started while the app is on screen, which
  /// is the case at check-in; a start attempted from the background is
  /// deferred by Tracelet until the app is next opened.
  @visibleForTesting
  static tl.Config intervalConfig(int intervalMinutes) =>
      _intervalConfig(intervalMinutes);

  static tl.Config _intervalConfig(int intervalMinutes) {
    final seconds = intervalMinutes * 60;
    return tl.Config(
      geo: tl.GeoConfig(periodicLocationInterval: seconds),
      // Once the motion engine decides the phone is sitting still it switches
      // to its OWN stationary cadence, which defaults to 120 seconds. Seen in
      // production: an employee's phone recorded every 2 minutes instead of
      // hourly. Both intervals must carry the employee's setting.
      motion: tl.MotionConfig(stationaryPeriodicInterval: seconds),
      android: const tl.AndroidConfig(periodicUseForegroundService: true),
    );
  }

  /// Battery-management details for this device (manufacturer, whether it is
  /// known to kill background apps, whether the app is exempt).
  Future<Map<String, Object?>> batteryHealth() =>
      tl.Tracelet.getSettingsHealth();

  /// Opens the manufacturer's power-management / autostart screen, falling
  /// back to Android's battery-optimisation settings. True if a screen opened.
  Future<bool> openBatterySettings() async {
    try {
      if (await tl.Tracelet.showPowerManager()) return true;
    } catch (e) {
      debugPrint('[TraceletService] showPowerManager failed: $e');
    }
    try {
      return await tl.Tracelet.openBatterySettings();
    } catch (e) {
      debugPrint('[TraceletService] openBatterySettings failed: $e');
      return false;
    }
  }

  /// Stops capture (PAUSED and STOPPED alike).
  ///
  /// Skipped when the engine is already stopped. Seen on Android 12: calling
  /// `Tracelet.stop()` while the app is in the background throws
  /// BackgroundServiceStartNotAllowedException (it dispatches a service
  /// intent), which happened at every background app start with no session
  /// even though there was nothing to stop.
  Future<void> stop() async {
    try {
      final state = await tl.Tracelet.getState();
      if (!state.enabled) return;
    } catch (_) {
      // State unknown: fall through and try to stop anyway.
    }
    await tl.Tracelet.stop();
  }

  /// Updates Tracelet's own foreground-service notification text in place.
  Future<void> updateNotificationText({
    required String title,
    required String text,
  }) async {
    await tl.Tracelet.setConfig(
      tl.Config(
        android: tl.AndroidConfig(
          foregroundService: tl.ForegroundServiceConfig(
            notificationTitle: title,
            notificationText: text,
          ),
        ),
      ),
    );
    await tl.Tracelet.updateNotification();
  }

  /// Takes one fix now and returns it as a `Location.toMap()` map. The caller
  /// queues it; a missing fix must never block check-in or checkout.
  Future<Map<String, Object?>> captureOnce() async {
    await init();
    final location = await tl.Tracelet.getCurrentPosition(
      desiredAccuracy: tl.DesiredAccuracy.high,
      timeout: 30,
      persist: true,
    );
    return location.toMap();
  }

  /// Fixes Tracelet has recorded and still holds locally, as maps. Used to
  /// backfill the sync queue with anything the headless path did not deliver.
  Future<List<Map<String, Object?>>> recordedLocations() async {
    final locations = await tl.Tracelet.getLocations();
    return locations.map((l) => l.toMap()).toList();
  }

  // -----------------------------------------------------------------------
  // Geofencing -- circular only
  // -----------------------------------------------------------------------

  static const String _workSiteGeofenceId = 'attendance_work_site';

  /// Registers the employee's fixed work-site as a background geofence. This
  /// is additive to the synchronous attendance-time geofence check, which is
  /// the enforcement path of record and is unchanged.
  Future<void> syncWorkSiteGeofence(String empCode) async {
    try {
      final settings = await _configService.getGeofenceSettings(empCode);
      if (settings == null || !settings.isEnforced) {
        await tl.Tracelet.removeGeofence(_workSiteGeofenceId);
        return;
      }
      await tl.Tracelet.addGeofence(
        tl.Geofence(
          identifier: _workSiteGeofenceId,
          latitude: settings.latitude!,
          longitude: settings.longitude!,
          radius: settings.margin,
          notifyOnEntry: true,
          notifyOnExit: true,
          notifyOnDwell: false,
        ),
      );
    } catch (e) {
      debugPrint('[TraceletService] Geofence sync skipped: $e');
    }
  }

  Future<void> clearWorkSiteGeofence() async {
    try {
      await tl.Tracelet.removeGeofence(_workSiteGeofenceId);
    } catch (e) {
      debugPrint('[TraceletService] Geofence removal skipped: $e');
    }
  }

  // -----------------------------------------------------------------------
  // Permissions
  // -----------------------------------------------------------------------

  /// Location, then notification. Only ever called from a UI context (at
  /// check-in) -- never during app bootstrap, where it would hang launch.
  Future<void> requestPermissions() async {
    await tl.Tracelet.requestLocationAuthorization();
    await tl.Tracelet.requestNotificationAuthorization();
  }
}
