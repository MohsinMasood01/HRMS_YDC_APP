import '../entities/location_point.dart';

/// Aggregate outcome of one synchronisation pass.
class LocationSyncSummary {
  const LocationSyncSummary({
    this.synced = 0,
    this.failed = 0,
    this.remaining = 0,
    this.transportError,
  });

  final int synced;
  final int failed;
  final int remaining;

  /// Set when the request itself could not complete (offline, auth, 5xx).
  /// Every point stays queued in that case.
  final String? transportError;

  bool get hadTransportError => transportError != null;

  LocationSyncSummary merge(LocationSyncSummary other) => LocationSyncSummary(
    synced: synced + other.synced,
    failed: failed + other.failed,
    remaining: other.remaining,
    transportError: transportError ?? other.transportError,
  );

  @override
  String toString() =>
      'LocationSyncSummary(synced: $synced, failed: $failed, '
      'remaining: $remaining, transportError: $transportError)';
}

/// Why a capture attempt produced no point. Nothing is ever fabricated —
/// a failed fix yields a reason, not a placeholder coordinate.
enum LocationCaptureFailure {
  serviceDisabled,
  permissionDenied,
  timeout,
  invalidFix,
  error,
}

class LocationCaptureException implements Exception {
  const LocationCaptureException(this.reason, this.message);

  final LocationCaptureFailure reason;
  final String message;

  @override
  String toString() => '${reason.name}: $message';
}

/// Local-first location storage and synchronisation.
abstract class LocationRepository {
  /// Acquires a GPS fix and persists it to SQLite **before** any network
  /// call. Throws [LocationCaptureException] when no valid fix is available;
  /// callers must not substitute a default coordinate.
  Future<LocationPoint> captureAndStore({
    required String cardNo,
    required String attendanceDate,
  });

  /// Queues a point captured elsewhere (the Tracelet engine). Idempotent on
  /// [LocationPoint.clientEventId]: storing the same fix twice keeps one row.
  Future<void> store(LocationPoint point);

  /// Uploads queued points. When [cardNo] is null every employee with a
  /// pending queue is synced under their own card number.
  Future<LocationSyncSummary> syncPending({String? cardNo, String? authToken});

  /// Deletes confirmed points older than [age]. Never touches unsynced rows.
  Future<int> pruneSyncedOlderThan(Duration age);

  /// Points still awaiting upload, across all employees.
  Future<int> pendingCount();

  /// Returns rows stranded in SYNCING (process death mid-upload) to PENDING.
  Future<int> releaseStuckSyncing();
}
