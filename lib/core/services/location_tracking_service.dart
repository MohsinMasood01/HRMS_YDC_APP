import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/location_tracking/data/tracelet_location_mapper.dart';
import '../../features/location_tracking/domain/entities/tracking_session.dart';
import '../../features/location_tracking/domain/repositories/location_repository.dart';
import '../../features/location_tracking/location_tracking_bootstrap.dart';
import '../background/background_tasks.dart' show kLocationTaskName;
import 'location_tracking_config_service.dart';
import 'secure_storage_service.dart';
import 'tracelet_service.dart';
import 'tracking_session_store.dart';

/// Orchestrates background location tracking.
///
/// Owns the tracking state machine, scheduling and the notification.
///
/// Data path, end to end:
///   Tracelet periodic fix
///     -> queued in local SQLite under the ACTIVE session's card number
///        (foreground: [TraceletService.onFix]; app killed: the headless
///         `location` event in core/background/tracelet_headless.dart)
///     -> [LocationRepository.syncPending] -> POST /auth/location/batch
///
/// On startup, fixes Tracelet recorded during the current session are
/// backfilled into the queue, so a fix the background path missed is still
/// delivered. Queue inserts are idempotent on Tracelet's location uuid.
///
/// Public API is unchanged, so the attendance and auth blocs need no changes.
class LocationTrackingService {
  LocationTrackingService({
    LocationRepository? repository,
    TrackingSessionStore? sessionStore,
    LocationTrackingConfigService? configService,
    SecureStorageService? secureStorage,
    TraceletService? tracelet,
  }) : _repository = repository ?? createLocationRepository(),
       _sessions = sessionStore ?? TrackingSessionStore(),
       _configService = configService ?? LocationTrackingConfigService(),
       _secureStorage = secureStorage ?? SecureStorageService(),
       _tracelet = tracelet ?? TraceletService();

  final LocationRepository _repository;
  final TrackingSessionStore _sessions;
  final LocationTrackingConfigService _configService;
  final SecureStorageService _secureStorage;
  final TraceletService _tracelet;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Android refuses WorkManager periodic work more frequent than 15 minutes.
  /// HR-configured intervals are never scheduled below this.
  static const int _minIntervalMinutes = 15;

  /// Tracelet's periodic mode minimum (60 seconds). Only reachable through
  /// [testIntervalOverrideMinutes]; see TraceletService.start for how a
  /// sub-15-minute interval is scheduled.
  static const int _absoluteMinIntervalMinutes = 1;

  /// Test-only interval override (minutes) per card. MUST be empty in any
  /// build given to employees: every card then follows the panel setting.
  ///
  /// Exists because the backend stores the interval in whole hours
  /// (HR_EMP_MASTER.TRACK_LOCATION_HR, minimum 1), so a shorter test interval
  /// cannot come from the server. Example: `{'100002.1': 15}`.
  @visibleForTesting
  static const Map<String, int> testIntervalOverrideMinutes = {};

  /// Used only when neither the backend nor the cache can supply an interval,
  /// so tracking still runs rather than silently doing nothing. HR's value
  /// always wins as soon as the backend answers.
  static const int _lastResortIntervalMinutes = 60;

  /// Synced points older than this are pruned locally. The backend remains
  /// the historical source of truth.
  static const Duration _retention = Duration(days: 7);

  /// Guards against overlapping sync passes (connectivity events can burst).
  bool _syncInFlight = false;

  /// Set when a sync is requested while one is already running.
  bool _syncRequestedDuringPass = false;

  /// Fires at the session's cutoff while this isolate is alive, closing a
  /// session whose employee never checked out. When the app is not running,
  /// the headless isolate does the same on the first fix after the cutoff,
  /// and [reconcileOnStartup] does it on the next app open.
  Timer? _cutoffTimer;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Called once at startup from the service locator.
  ///
  /// Sets up the notification channel and the single connectivity listener,
  /// then reconciles persisted tracking state with what is actually
  /// scheduled -- restoring the schedule and notification after an app
  /// restart or device reboot.
  Future<void> init() async {
    // Every fix Tracelet records while this isolate is alive is queued here.
    _tracelet.onFix = (locationMap) => unawaited(_queueFix(locationMap));

    // Must not block app startup (the caller does not await this), and
    // permissions are NOT requested here -- only at check-in, from a UI.
    try {
      // Hand ready() the active session's interval so the schedule it resumes
      // is already the right one (see TraceletService.init).
      // An expired session gets no schedule: reconcileOnStartup closes it
      // just below, and resuming its capture first would record past the
      // cutoff.
      final stored = await _sessions.read();
      final capturing =
          stored != null &&
          stored.state == TrackingState.active &&
          !stored.isExpiredAt(DateTime.now());
      await _tracelet.init(
        intervalMinutes: capturing
            ? resolveIntervalMinutes(
                cardNo: stored.cardNo,
                cached: stored.intervalMinutes,
              )
            : null,
      );
    } catch (e) {
      debugPrint('[LocationTracking] Tracelet init failed (non-fatal): $e');
    }

    await _cancelLegacyWorkManagerCapture();

    // Single connectivity listener for the whole app. Sync is the only thing
    // gated on connectivity -- GPS capture never is.
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(syncPendingLocations());
    });

    await _sessions.migrateLegacyKeysIfNeeded();
    await reconcileOnStartup();
  }

  /// Restores scheduling, notification and pending sync after a cold start.
  Future<void> reconcileOnStartup() async {
    try {
      // A crash mid-upload can strand rows in SYNCING where no pass would
      // pick them up again.
      await _repository.releaseStuckSyncing();

      final session = await _sessions.read();

      if (session == null || session.state == TrackingState.stopped) {
        // Never resurrect tracking after a final checkout.
        await _cancelSchedule();
        await _clearNotification();
      } else if (session.isExpiredAt(DateTime.now())) {
        // Past the shift's cutoff with no checkout: close it rather than
        // tracking into the next day. Judged by the cutoff instant, not the
        // calendar date -- the old date check also killed overnight shifts
        // (e.g. 20:30-08:30) at midnight.
        debugPrint(
          '[LocationTracking] Session for ${session.cardNo} passed its cutoff '
          '${session.effectiveCutoffAt.toIso8601String()} without a checkout',
        );
        await _expireSession(session);
      } else if (session.state == TrackingState.active) {
        // Deliver anything recorded while the app was closed that the
        // headless path did not queue, before re-arming capture.
        await _backfillFromTracelet(session);
        // Re-register: a Tracelet registration does not always survive a
        // force-stop, and the notification never survives a reboot.
        await _scheduleCapture(session.intervalMinutes);
        await _showNotification(session);
        _armCutoffTimer(session);
        unawaited(_tracelet.syncWorkSiteGeofence(session.cardNo));
        unawaited(_refreshConfig(session));
      } else if (session.state == TrackingState.paused) {
        await _cancelSchedule();
        await _showNotification(session);
        // A paused session still expires at its cutoff, so a later check-in
        // cannot resume a shift that has already ended.
        _armCutoffTimer(session);
      }

      unawaited(syncPendingLocations());
      unawaited(_repository.pruneSyncedOlderThan(_retention));
    } catch (e) {
      debugPrint('[LocationTracking] Startup reconciliation failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Check-in
  // ---------------------------------------------------------------------

  /// Starts (or resumes) tracking after a **successful online check-in**.
  ///
  /// Never called merely because the attendance screen opened. Returns the
  /// session when tracking is running, or null when HR has tracking disabled
  /// for this employee or permission is missing.
  ///
  /// [cutoffAt] is the backend's `tracking_cutoff_at` from the check-in
  /// response: shift end plus grace. Capture stops there if no checkout comes
  /// first. When absent, the settings endpoint's cutoff is used, and failing
  /// that [TrackingSession.fallbackMaxDuration].
  Future<TrackingSession?> startSessionAfterCheckIn({
    required String cardNo,
    String? attendanceDate,
    DateTime? cutoffAt,
  }) async {
    if (cardNo.isEmpty) return null;

    try {
      final existing = await _sessions.read();

      // A different employee checked in on this phone: flush the previous
      // queue under its own card number before switching sessions.
      if (existing != null &&
          existing.cardNo.isNotEmpty &&
          existing.cardNo != cardNo) {
        debugPrint(
          '[LocationTracking] Employee switch ${existing.cardNo} -> $cardNo; '
          'flushing previous queue',
        );
        await syncPendingLocations(cardNo: existing.cardNo);
      }

      // Backend is authoritative for whether this employee is tracked at all.
      int? intervalMinutes;
      DateTime? configCutoff;
      try {
        final config = await _configService.getTrackingSettings(cardNo);
        if (!config.isTrackingEnabled) {
          debugPrint('[LocationTracking] Tracking disabled for $cardNo');
          await _stopInternal(clearSession: true);
          return null;
        }
        intervalMinutes = config.resolvedIntervalMinutes;
        configCutoff = config.trackingCutoffAt;
      } catch (e) {
        // Offline at check-in: fall back to the cached interval rather than
        // refusing to track. The backend re-asserts itself on next contact.
        debugPrint(
          '[LocationTracking] Config fetch failed ($e); using cached interval',
        );
        intervalMinutes = existing?.intervalMinutes;
      }

      final resolved = resolveIntervalMinutes(
        cardNo: cardNo,
        fromServer: intervalMinutes,
        cached: existing?.intervalMinutes,
      );

      final now = DateTime.now();
      final backendCutoff = cutoffAt ?? configCutoff;

      // The backend says this shift is already over (check-in after shift
      // end + grace): recording anything would be recording past the cutoff.
      if (backendCutoff != null && !backendCutoff.isAfter(now.toUtc())) {
        debugPrint(
          '[LocationTracking] Check-in for $cardNo is after its cutoff '
          '${backendCutoff.toIso8601String()} -- not tracking',
        );
        return null;
      }

      // Resume the same session when the same employee re-checks in on the
      // same day and the shift has not ended; otherwise open a new one.
      final day = attendanceDate ?? _today();
      // Holding the resumable session (rather than a bool) keeps it promoted
      // to non-null for the reads below.
      final resumable =
          existing != null &&
              existing.cardNo == cardNo &&
              existing.attendanceDate == day &&
              existing.state.isResumable &&
              !existing.isExpiredAt(now)
          ? existing
          : null;

      final session = TrackingSession(
        cardNo: cardNo,
        attendanceDate: day,
        state: TrackingState.active,
        intervalMinutes: resolved,
        startedAt: resumable?.startedAt ?? now.toUtc(),
        // The latest word from the backend wins; a resumed session with no
        // fresh cutoff keeps the one it already had.
        cutoffAt: backendCutoff ?? resumable?.cutoffAt,
      );

      // Ask for location/notification permission HERE, not at startup: this
      // runs from a real UI context after a successful check-in. Requesting
      // it during app bootstrap (before runApp) hangs launch on a white
      // screen. A denial must not stop the session from being recorded.
      try {
        await _tracelet.requestPermissions();
      } catch (e) {
        debugPrint('[LocationTracking] Permission request failed: $e');
      }

      await _sessions.save(session);
      await _scheduleCapture(resolved);
      await _showNotification(session);
      _armCutoffTimer(session);
      // Additive to the synchronous attendance-time geofence check -- see
      // TraceletService.syncWorkSiteGeofence doc comment.
      unawaited(_tracelet.syncWorkSiteGeofence(cardNo));
      // First trail point now rather than one full interval later (the
      // previous WorkManager build fired ~1 minute after check-in).
      unawaited(_captureAndQueueNow(session));

      debugPrint(
        '[LocationTracking] Session '
        '${resumable != null ? "resumed" : "started"} for $cardNo '
        'every ${resolved}m until '
        '${session.effectiveCutoffAt.toIso8601String()}'
        '${session.cutoffAt == null ? " (fallback cutoff)" : ""}',
      );
      return session;
    } catch (e) {
      debugPrint('[LocationTracking] Failed to start session: $e');
      return null;
    }
  }

  /// Re-reads HR config in the background and applies what changed: tracking
  /// switched off, a new cutoff (shift edited mid-day), or a new interval.
  Future<void> _refreshConfig(TrackingSession initial) async {
    var session = initial;
    try {
      final config = await _configService.getTrackingSettings(session.cardNo);

      if (!config.isTrackingEnabled) {
        debugPrint(
          '[LocationTracking] HR disabled tracking for ${session.cardNo}',
        );
        await _stopInternal(clearSession: true);
        return;
      }

      // Only adopt a cutoff that belongs to THIS session. The endpoint reports
      // the employee's latest session on the server; when its roster day
      // differs from ours it describes another shift and must not move our
      // cutoff.
      final serverCutoff = config.trackingCutoffAt;
      final sameSession =
          config.attendanceDate == null ||
          config.attendanceDate == session.attendanceDate;
      if (serverCutoff != null &&
          sameSession &&
          serverCutoff != session.cutoffAt) {
        debugPrint(
          '[LocationTracking] Cutoff for ${session.cardNo} is now '
          '${serverCutoff.toIso8601String()}',
        );
        session = session.copyWith(cutoffAt: serverCutoff);
        await _sessions.save(session);
        if (session.isExpiredAt(DateTime.now())) {
          await _expireSession(session);
          return;
        }
        _armCutoffTimer(session);
      }

      final serverMinutes = config.resolvedIntervalMinutes;
      if (serverMinutes == null) return;

      final resolved = resolveIntervalMinutes(
        cardNo: session.cardNo,
        fromServer: serverMinutes,
      );
      if (resolved == session.intervalMinutes) return;

      debugPrint(
        '[LocationTracking] Interval changed '
        '${session.intervalMinutes}m -> ${resolved}m',
      );
      final updated = session.copyWith(intervalMinutes: resolved);
      await _sessions.save(updated);
      await _scheduleCapture(resolved);
      await _showNotification(updated);
    } catch (e) {
      debugPrint('[LocationTracking] Config refresh skipped: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Checkout
  // ---------------------------------------------------------------------

  /// Applies the backend's ruling on a checkout.
  ///
  /// The phone does not decide whether a checkout was final -- our system
  /// allows several checkouts per shift, and only the backend is shift-aware.
  /// [directive] comes from `tracking_state` on the attendance response and
  /// [isFinalCheckout] from `is_final_checkout`.
  ///
  /// When the backend says nothing (older build of the API), the checkout is
  /// treated as INTERMEDIATE: tracking pauses but the session survives, so a
  /// 15:00 checkout cannot permanently kill tracking for a shift that runs to
  /// 17:00. Either way capture stops immediately. A paused session still ends
  /// for good at its cutoff (shift end + grace) if no check-in resumes it.
  Future<TrackingState> applyCheckoutDirective({
    required String cardNo,
    bool? isFinalCheckout,
    BackendTrackingDirective? directive,
  }) async {
    final session = await _sessions.read();
    if (session == null || session.state == TrackingState.stopped) {
      return TrackingState.stopped;
    }

    // Checking out after the cutoff (the phone missed the expiry, e.g. it was
    // off): the shift is over, so close the session rather than pausing one
    // a later check-in could wrongly resume.
    if (session.isExpiredAt(DateTime.now())) {
      await _expireSession(session);
      await syncPendingLocations(cardNo: session.cardNo);
      return TrackingState.stopped;
    }

    // The backend may explicitly tell us to keep capturing through this
    // checkout (e.g. a break that does not interrupt the shift). Honour that
    // rather than pausing.
    if (directive == BackendTrackingDirective.active) {
      debugPrint(
        '[LocationTracking] Checkout for $cardNo but backend says ACTIVE - '
        'continuing to capture',
      );
      unawaited(syncPendingLocations(cardNo: session.cardNo));
      return session.state;
    }

    // tracking_state is the more specific instruction, so it wins over
    // is_final_checkout when both are present.
    final isFinal =
        directive == BackendTrackingDirective.stopped ||
        (directive == null && isFinalCheckout == true);

    // Queue everything recorded so far while the session is still ACTIVE --
    // after the transition below, fixes would no longer be attributable.
    await _backfillFromTracelet(session);

    if (!isFinal) {
      // Intermediate checkout: capture stops, session survives.
      debugPrint(
        '[LocationTracking] Intermediate checkout for $cardNo -> PAUSED',
      );
      final paused = await _sessions.transitionTo(TrackingState.paused);
      await _cancelSchedule();
      if (paused != null) await _showNotification(paused);
      unawaited(syncPendingLocations(cardNo: session.cardNo));
      return TrackingState.paused;
    }

    // Final checkout: one last fix, then shut everything down.
    debugPrint('[LocationTracking] FINAL checkout for $cardNo -> STOPPED');
    _cancelCutoffTimer();
    await _captureFinalPoint(session);
    await _sessions.transitionTo(TrackingState.stopped);
    await _cancelSchedule();
    await _clearNotification();
    unawaited(_tracelet.clearWorkSiteGeofence());
    await syncPendingLocations(cardNo: session.cardNo);
    return TrackingState.stopped;
  }

  /// Best-effort final GPS sample. A missing fix must never block checkout.
  Future<void> _captureFinalPoint(TrackingSession session) =>
      _captureAndQueueNow(session);

  /// Takes one fix and queues it under [session]. Best-effort: a missing fix
  /// never blocks check-in or checkout, and nothing is ever fabricated.
  Future<void> _captureAndQueueNow(TrackingSession session) async {
    try {
      final locationMap = await _tracelet.captureOnce();
      await _queueFix(locationMap, session: session);
    } catch (e) {
      debugPrint('[LocationTracking] Immediate capture failed: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Queueing Tracelet fixes
  // ---------------------------------------------------------------------

  /// Queues one Tracelet fix under the ACTIVE session and uploads it.
  ///
  /// [session] defaults to the stored session read now; pass it explicitly
  /// when the caller already holds the session the fix belongs to (e.g. the
  /// final fix taken just before the session is closed).
  Future<void> _queueFix(
    Map<String, Object?> locationMap, {
    TrackingSession? session,
  }) async {
    try {
      final owner = session ?? await _sessions.read();
      final point = locationPointFromTracelet(
        locationMap,
        session: owner,
        localId: const Uuid().v4(),
      );
      if (point == null) return;
      await _repository.store(point);
      unawaited(syncPendingLocations(cardNo: point.cardNo));
    } catch (e) {
      debugPrint('[LocationTracking] Could not queue fix: $e');
    }
  }

  /// Queues every fix Tracelet still holds from [session]'s time window.
  /// Idempotent: fixes already queued are ignored by the UNIQUE key.
  Future<void> _backfillFromTracelet(TrackingSession session) async {
    if (session.state != TrackingState.active) return;
    try {
      final recorded = await _tracelet.recordedLocations();
      var queued = 0;
      for (final locationMap in recorded) {
        final point = locationPointFromTracelet(
          locationMap,
          session: session,
          localId: const Uuid().v4(),
        );
        if (point == null) continue;
        await _repository.store(point);
        queued++;
      }
      if (queued > 0) {
        debugPrint(
          '[LocationTracking] Backfill considered $queued fix(es) for '
          '${session.cardNo}',
        );
      }
    } catch (e) {
      debugPrint('[LocationTracking] Backfill skipped: $e');
    }
  }

  /// Builds before this one scheduled capture as a WorkManager periodic job.
  /// Left in place after an upgrade it would keep capturing alongside
  /// Tracelet and double every point, so it is cancelled once at startup.
  Future<void> _cancelLegacyWorkManagerCapture() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().cancelByUniqueName(kLocationTaskName);
    } catch (e) {
      debugPrint('[LocationTracking] Legacy WorkManager cancel skipped: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Cutoff (shift end + grace)
  // ---------------------------------------------------------------------

  /// Closes a session that reached its cutoff without a checkout.
  ///
  /// Fixes taken up to the cutoff are queued first, while the session is
  /// still ACTIVE -- the mapper keeps only those recorded on or before the
  /// cutoff. Then the session is STOPPED (endedAt = the cutoff itself), the
  /// engine stops and the notification goes with it.
  Future<void> _expireSession(TrackingSession session) async {
    _cancelCutoffTimer();
    await _backfillFromTracelet(session);
    await _sessions.expireIfDue();
    await _cancelSchedule();
    await _clearNotification();
    unawaited(_tracelet.clearWorkSiteGeofence());
    unawaited(syncPendingLocations(cardNo: session.cardNo));
  }

  /// Arms [_cutoffTimer] for [session]'s cutoff, replacing any earlier one.
  void _armCutoffTimer(TrackingSession session) {
    _cancelCutoffTimer();
    final remaining = session.effectiveCutoffAt.difference(
      DateTime.now().toUtc(),
    );
    if (remaining <= Duration.zero) {
      unawaited(_onCutoffReached());
      return;
    }
    _cutoffTimer = Timer(remaining, () => unawaited(_onCutoffReached()));
  }

  void _cancelCutoffTimer() {
    _cutoffTimer?.cancel();
    _cutoffTimer = null;
  }

  /// Re-reads the session when the timer fires: a checkout may have closed it
  /// already, or a refresh may have moved the cutoff later.
  Future<void> _onCutoffReached() async {
    try {
      final session = await _sessions.read();
      if (session == null || !session.state.isResumable) return;
      if (!session.isExpiredAt(DateTime.now())) {
        _armCutoffTimer(session);
        return;
      }
      debugPrint(
        '[LocationTracking] Cutoff reached for ${session.cardNo} with no '
        'checkout -- closing session',
      );
      await _expireSession(session);
    } catch (e) {
      debugPrint('[LocationTracking] Cutoff handling failed: $e');
    }
  }

  /// Hard stop, ignoring shift rules. Used on logout and when HR turns
  /// tracking off. Checkout must go through [applyCheckoutDirective].
  Future<void> stopTracking() => _stopInternal(clearSession: true);

  Future<void> _stopInternal({required bool clearSession}) async {
    _cancelCutoffTimer();
    final session = await _sessions.read();
    await _cancelSchedule();
    await _clearNotification();
    unawaited(_tracelet.clearWorkSiteGeofence());

    if (clearSession) {
      await _sessions.clear();
    } else {
      await _sessions.transitionTo(TrackingState.stopped);
    }

    // Flush whatever the session already captured.
    if (session != null && session.cardNo.isNotEmpty) {
      unawaited(syncPendingLocations(cardNo: session.cardNo));
    }
  }

  // ---------------------------------------------------------------------
  // Synchronisation
  // ---------------------------------------------------------------------

  /// Uploads queued points. Safe to call at any time; a no-op when offline.
  ///
  /// Every employee holding a queue is synced under their own card number;
  /// [cardNo] is accepted for call-site compatibility but no longer narrows
  /// the pass (a full pass is a superset and never mis-attributes). Points
  /// queued by earlier builds, which posted to a URL that never existed, are
  /// delivered by the same pass.
  Future<LocationSyncSummary> syncPendingLocations({String? cardNo}) async {
    if (_syncInFlight) {
      // A fix queued during a pass would otherwise wait for the next trigger
      // (next fix, reconnect, app open). Remember it and run once more.
      _syncRequestedDuringPass = true;
      return const LocationSyncSummary();
    }
    _syncInFlight = true;
    var summary = const LocationSyncSummary();
    try {
      do {
        _syncRequestedDuringPass = false;
        final token = await _readAuthToken();
        summary = await _repository.syncPending(authToken: token);
        if (summary.synced > 0) {
          await _repository.pruneSyncedOlderThan(_retention);
        }
        debugPrint('[LocationTracking] $summary');
        // Stop on a transport error: retrying immediately cannot succeed.
      } while (_syncRequestedDuringPass && !summary.hadTransportError);
      return summary;
    } catch (e) {
      debugPrint('[LocationTracking] Sync pass failed: $e');
      return LocationSyncSummary(transportError: e.toString());
    } finally {
      _syncInFlight = false;
    }
  }

  Future<String?> _readAuthToken() async {
    try {
      return await _secureStorage.read('token');
    } catch (e) {
      debugPrint('[LocationTracking] Could not read auth token: $e');
      return null;
    }
  }

  /// Points still awaiting upload, for diagnostics and UI badges.
  Future<int> pendingLocationCount() => _repository.pendingCount();

  // ---------------------------------------------------------------------
  // State queries
  // ---------------------------------------------------------------------

  Future<TrackingSession?> currentSession() => _sessions.read();

  Future<bool> get isTracking async {
    final session = await _sessions.read();
    return session?.state == TrackingState.active;
  }

  // ---------------------------------------------------------------------
  // Scheduling / notification
  // ---------------------------------------------------------------------

  /// Resolves the capture interval: a test override for [cardNo] first, then
  /// HR's value, then the cached value, then a last-resort constant so
  /// tracking is never silently disabled.
  @visibleForTesting
  static int resolveIntervalMinutes({
    required String cardNo,
    int? fromServer,
    int? cached,
  }) {
    final override = testIntervalOverrideMinutes[cardNo];
    if (override != null) {
      return override < _absoluteMinIntervalMinutes
          ? _absoluteMinIntervalMinutes
          : override;
    }
    final candidate = (fromServer != null && fromServer > 0)
        ? fromServer
        : (cached != null && cached > 0 ? cached : _lastResortIntervalMinutes);
    // HR intervals keep Android's WorkManager 15-minute floor.
    return candidate < _minIntervalMinutes ? _minIntervalMinutes : candidate;
  }

  /// Best-effort: if the capture engine cannot start, the session is still
  /// recorded and the upload of already-queued points must still run. (A
  /// Tracelet startup failure used to abort reconciliation before its sync.)
  Future<void> _scheduleCapture(int intervalMinutes) async {
    final minutes = intervalMinutes < _absoluteMinIntervalMinutes
        ? _absoluteMinIntervalMinutes
        : intervalMinutes;
    try {
      await _tracelet.start(intervalMinutes: minutes);
      debugPrint('[LocationTracking] Capture engine started, every ${minutes}m');
    } catch (e) {
      debugPrint(
        '[LocationTracking] CAPTURE ENGINE FAILED TO START -- no new points '
        'will be recorded: $e',
      );
    }
  }

  /// Best-effort: an engine that failed to initialise has nothing to stop,
  /// and that must not abort the reconciliation / sync that follows.
  Future<void> _cancelSchedule() async {
    try {
      await _tracelet.stop();
    } catch (e) {
      debugPrint('[LocationTracking] Tracelet stop skipped: $e');
    }
  }

  /// Keeps the notification honest: it reflects the real state.
  ///
  /// This updates wording on Tracelet's OWN foreground-service notification
  /// (via [TraceletService.updateNotificationText]) rather than showing a
  /// second, separate `flutter_local_notifications` notification -- Android
  /// only allows one foreground-service notification per service, and
  /// showing an unrelated second one would just be visual clutter for the
  /// employee. There is nothing to clear on stop: Tracelet removes its own
  /// notification when capture stops.
  Future<void> _showNotification(TrackingSession session) async {
    if (!Platform.isAndroid) return;

    if (session.state == TrackingState.stopped ||
        session.state == TrackingState.inactive) {
      return;
    }

    final isPaused = session.state == TrackingState.paused;
    final title = isPaused ? 'Work Session Paused' : 'Work Session Active';
    final body = isPaused
        ? 'Location tracking is paused until your next check-in'
        : _intervalText(session.intervalMinutes);

    // Cosmetic: a notification that cannot be updated must never abort the
    // session start or reconciliation around it.
    try {
      await _tracelet.updateNotificationText(title: title, text: body);
    } catch (e) {
      debugPrint('[LocationTracking] Notification update skipped: $e');
    }
  }

  static String _intervalText(int minutes) {
    if (minutes < 60) return 'Tracking your location every $minutes minutes';
    if (minutes == 60) return 'Tracking your location every hour';
    if (minutes % 60 == 0) {
      return 'Tracking your location every ${minutes ~/ 60} hours';
    }
    return 'Tracking your location every $minutes minutes';
  }

  /// No-op: Tracelet owns its own foreground notification lifecycle and
  /// removes it when capture stops (see [_showNotification]'s doc comment).
  /// Kept as a named call site so [reconcileOnStartup] / [_stopInternal]
  /// read the same either way.
  Future<void> _clearNotification() async {}

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _cancelCutoffTimer();
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }
}
