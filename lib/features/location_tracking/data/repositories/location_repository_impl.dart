import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/location_point.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_local_data_source.dart';
import '../datasources/location_remote_data_source.dart';

/// Local-first implementation: GPS -> SQLite -> network, in that order.
///
/// Network availability gates *synchronisation only*. A capture always
/// completes and is always durable, whether or not the device is online.
class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl({
    required LocationLocalDataSource local,
    required LocationRemoteDataSource remote,
    Uuid? uuid,
  }) : _local = local,
       _remote = remote,
       _uuid = uuid ?? const Uuid();

  final LocationLocalDataSource _local;
  final LocationRemoteDataSource _remote;
  final Uuid _uuid;

  /// Points per HTTP request.
  static const int _batchSize = 100;

  /// Safety valve so a backend that keeps returning FAILED cannot spin.
  static const int _maxPassesPerCard = 20;

  /// How long to wait for a GPS fix before giving up on this interval.
  static const Duration _fixTimeout = Duration(seconds: 30);

  @override
  Future<LocationPoint> captureAndStore({
    required String cardNo,
    required String attendanceDate,
  }) async {
    if (cardNo.isEmpty) {
      throw const LocationCaptureException(
        LocationCaptureFailure.error,
        'Cannot capture a location without a card number',
      );
    }

    final position = await _acquirePosition();

    final point = LocationPoint(
      localId: _uuid.v4(),
      // Minted once, here. Retries reuse it so the backend can dedupe.
      clientEventId: _uuid.v4(),
      cardNo: cardNo,
      latitude: position.latitude,
      longitude: position.longitude,
      // Real device accuracy, never fabricated.
      accuracy: position.accuracy,
      recordedAt: position.timestamp.toUtc(),
      attendanceDate: attendanceDate,
      createdAt: DateTime.now().toUtc(),
      syncStatus: LocationSyncStatus.pending,
    );

    // Durable before any network attempt.
    await _local.insert(point);
    debugPrint(
      '[LocationRepo] Stored point ${point.clientEventId} for $cardNo '
      '(${point.latitude}, ${point.longitude} acc=${point.accuracy}m)',
    );
    return point;
  }

  @override
  Future<void> store(LocationPoint point) async {
    // Insert-or-ignore on the UNIQUE client_event_id column.
    await _local.insert(point);
    debugPrint(
      '[LocationRepo] Queued point ${point.clientEventId} for '
      '${point.cardNo} (${point.latitude}, ${point.longitude} '
      'acc=${point.accuracy}m at ${point.recordedAt.toIso8601String()})',
    );
  }

  /// Acquires a fix, or throws with a reason. Never returns a placeholder.
  ///
  /// Permission is only *checked* here, never requested: this runs in the
  /// WorkManager background isolate where no dialog can be shown. Requesting
  /// permission is the responsibility of the UI layer.
  Future<Position> _acquirePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationCaptureException(
        LocationCaptureFailure.serviceDisabled,
        'Location services are turned off',
      );
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationCaptureException(
        LocationCaptureFailure.permissionDenied,
        'Location permission not granted ($permission)',
      );
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _fixTimeout,
      );
    } catch (e) {
      throw LocationCaptureException(
        LocationCaptureFailure.timeout,
        'No GPS fix within ${_fixTimeout.inSeconds}s: $e',
      );
    }

    if (!_isPlausible(position)) {
      throw LocationCaptureException(
        LocationCaptureFailure.invalidFix,
        'Implausible fix (${position.latitude}, ${position.longitude})',
      );
    }
    return position;
  }

  /// Rejects fixes that cannot be real. Poor *accuracy* is still stored --
  /// the value is recorded as-is so the server can judge it.
  static bool _isPlausible(Position p) {
    if (p.latitude.isNaN || p.longitude.isNaN) return false;
    if (p.latitude.abs() > 90 || p.longitude.abs() > 180) return false;
    // Exact null island is the classic "no fix" sentinel.
    if (p.latitude == 0 && p.longitude == 0) return false;
    return true;
  }

  @override
  Future<LocationSyncSummary> syncPending({
    String? cardNo,
    String? authToken,
  }) async {
    final cards = cardNo != null && cardNo.isNotEmpty
        ? [cardNo]
        : await _local.pendingCardNumbers();

    if (cards.isEmpty) return const LocationSyncSummary();

    var summary = const LocationSyncSummary();
    for (final card in cards) {
      summary = summary.merge(await _syncCard(card, authToken));
    }
    return summary.merge(
      LocationSyncSummary(remaining: await _local.pendingCount()),
    );
  }

  /// Syncs one queue under that queue owner's own card number, never the
  /// currently logged-in user.
  Future<LocationSyncSummary> _syncCard(
    String cardNo,
    String? authToken,
  ) async {
    var synced = 0;
    var failed = 0;

    for (var pass = 0; pass < _maxPassesPerCard; pass++) {
      final candidates = await _local.pendingForCard(
        cardNo,
        limit: _batchSize,
      );
      if (candidates.isEmpty) break;

      // Upload only what this pass actually claimed. A concurrent pass (e.g.
      // the background isolate handling the same fix) owns the rest, and
      // sending those too is exactly what produced duplicate server rows.
      final claimedIds = (await _local.claimForSync(
        candidates.map((p) => p.localId).toList(),
      )).toSet();
      final batch = candidates
          .where((p) => claimedIds.contains(p.localId))
          .toList();
      if (batch.isEmpty) break;
      final localIds = batch.map((p) => p.localId).toList();

      final List<LocationSyncItemResult> results;
      try {
        results = await _remote.syncBatch(batch, authToken: authToken);
      } on LocationSyncTransportException catch (e) {
        // Nothing was accepted -- requeue the whole batch and stop trying.
        await _local.markBatchFailed(localIds: localIds, error: e.message);
        debugPrint(
          '[LocationSync] Transport failure for $cardNo: ${e.message}',
        );
        return LocationSyncSummary(
          synced: synced,
          failed: failed + batch.length,
          transportError: e.message,
        );
      } catch (e) {
        await _local.markBatchFailed(localIds: localIds, error: e.toString());
        return LocationSyncSummary(
          synced: synced,
          failed: failed + batch.length,
          transportError: e.toString(),
        );
      }

      final byEventId = {for (final r in results) r.clientEventId: r};
      var batchFailed = 0;

      for (final point in batch) {
        final result = byEventId[point.clientEventId];

        if (result == null) {
          // Backend said nothing about this point -- keep it and retry.
          await _local.markFailed(
            localId: point.localId,
            error: 'No result returned for client_event_id',
          );
          failed++;
          batchFailed++;
          continue;
        }

        // SYNCED and ALREADY_SYNCED both mean the backend holds it.
        if (result.result.isAccepted) {
          await _local.markSynced(
            localId: point.localId,
            serverId: result.serverId,
            syncedAt: result.syncedAt,
          );
          synced++;
        } else {
          await _local.markFailed(
            localId: point.localId,
            error: result.error ?? 'Backend reported FAILED',
          );
          failed++;
          batchFailed++;
        }
      }

      // Nothing in this batch moved forward: stop rather than re-reading the
      // same rows on the next pass.
      if (batchFailed == batch.length) break;
      if (batch.length < _batchSize) break;
    }

    if (synced > 0 || failed > 0) {
      debugPrint('[LocationSync] $cardNo -> synced=$synced failed=$failed');
    }
    return LocationSyncSummary(synced: synced, failed: failed);
  }

  @override
  Future<int> pruneSyncedOlderThan(Duration age) =>
      _local.pruneSyncedOlderThan(age);

  @override
  Future<int> pendingCount() => _local.pendingCount();

  @override
  Future<int> releaseStuckSyncing() => _local.releaseStuckSyncing();
}
