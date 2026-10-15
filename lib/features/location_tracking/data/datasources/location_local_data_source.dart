import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/location_track_db.dart';
import '../../domain/entities/location_point.dart';

/// SQLite CRUD for queued location points.
///
/// Every write is local-first: a point is durable here *before* any network
/// call is attempted, and a failed upload never deletes a row.
class LocationLocalDataSource {
  LocationLocalDataSource(this._db);

  final LocationTrackDb _db;

  static const String _table = LocationTrackDb.table;

  /// Statuses eligible for an upload attempt.
  static const List<String> _syncableStatuses = ['PENDING', 'FAILED'];

  Future<Database> get _database => _db.database;

  /// Persists a freshly captured point.
  ///
  /// Uses `ignore` on conflict so a replayed [LocationPoint.clientEventId]
  /// (for example if a scheduler fires twice) cannot create a duplicate row.
  Future<void> insert(LocationPoint point) async {
    final db = await _database;
    await db.insert(
      _table,
      point.toDb(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Distinct employees with points still awaiting upload.
  ///
  /// Sync iterates these rather than assuming the logged-in user, so a queue
  /// left behind by employee A is uploaded under A's card number even after
  /// employee B logs into the same phone.
  Future<List<String>> pendingCardNumbers() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT card_no FROM $_table '
      'WHERE sync_status IN (${_placeholders(_syncableStatuses.length)}) '
      'AND card_no <> ?',
      [..._syncableStatuses, ''],
    );
    return rows.map((r) => r['card_no'].toString()).toList();
  }

  /// Points awaiting upload for one employee, oldest first.
  Future<List<LocationPoint>> pendingForCard(
    String cardNo, {
    int limit = 100,
  }) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where:
          'card_no = ? AND sync_status IN (${_placeholders(_syncableStatuses.length)})',
      whereArgs: [cardNo, ..._syncableStatuses],
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(LocationPoint.fromDb).toList();
  }

  /// Claims rows for upload and returns only the ids THIS caller claimed.
  ///
  /// Each row moves to SYNCING only if it is still PENDING/FAILED, so when two
  /// sync passes race -- seen on a device when the background engine delivered
  /// the same fix twice and both handlers uploaded it -- exactly one of them
  /// owns each row. SQLite serialises writes across connections and isolates,
  /// which makes each conditional update atomic.
  Future<List<String>> claimForSync(List<String> localIds) async {
    if (localIds.isEmpty) return const [];
    final db = await _database;
    final claimed = <String>[];
    await db.transaction((txn) async {
      for (final id in localIds) {
        final changed = await txn.rawUpdate(
          'UPDATE $_table SET sync_status = ? '
          'WHERE local_id = ? '
          'AND sync_status IN (${_placeholders(_syncableStatuses.length)})',
          [LocationSyncStatus.syncing.dbValue, id, ..._syncableStatuses],
        );
        if (changed == 1) claimed.add(id);
      }
    });
    return claimed;
  }

  /// Records backend confirmation for one point.
  Future<void> markSynced({
    required String localId,
    int? serverId,
    DateTime? syncedAt,
  }) async {
    final db = await _database;
    await db.update(
      _table,
      {
        'sync_status': LocationSyncStatus.synced.dbValue,
        'server_id': serverId,
        'synced_at': (syncedAt ?? DateTime.now().toUtc())
            .toUtc()
            .toIso8601String(),
        'last_sync_error': null,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Records a failed attempt. The row survives and is retried later.
  Future<void> markFailed({
    required String localId,
    required String error,
  }) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE $_table SET sync_status = ?, retry_count = retry_count + 1, '
      'last_sync_error = ? WHERE local_id = ?',
      [LocationSyncStatus.failed.dbValue, _truncateError(error), localId],
    );
  }

  /// Fails a whole in-flight batch, e.g. when the request threw.
  Future<void> markBatchFailed({
    required List<String> localIds,
    required String error,
  }) async {
    if (localIds.isEmpty) return;
    final db = await _database;
    await db.rawUpdate(
      'UPDATE $_table SET sync_status = ?, retry_count = retry_count + 1, '
      'last_sync_error = ? WHERE local_id IN (${_placeholders(localIds.length)})',
      [
        LocationSyncStatus.failed.dbValue,
        _truncateError(error),
        ...localIds,
      ],
    );
  }

  /// Releases rows stranded in SYNCING by a process death mid-upload.
  ///
  /// Without this a crash during sync would park points in SYNCING forever,
  /// where no later pass would pick them up.
  Future<int> releaseStuckSyncing() async {
    final db = await _database;
    return db.update(
      _table,
      {'sync_status': LocationSyncStatus.pending.dbValue},
      where: 'sync_status = ?',
      whereArgs: [LocationSyncStatus.syncing.dbValue],
    );
  }

  /// Deletes confirmed points older than [age].
  ///
  /// Only SYNCED rows are eligible — PENDING, SYNCING and FAILED are never
  /// removed, because the backend does not yet hold them. The cutoff is
  /// computed in UTC to match how `recorded_at` is stored; the pre-v2 code
  /// compared a local-time cutoff against UTC timestamps, which shifted the
  /// retention window by the device's offset.
  Future<int> pruneSyncedOlderThan(Duration age) async {
    final db = await _database;
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    final deleted = await db.delete(
      _table,
      where: 'sync_status = ? AND recorded_at < ?',
      whereArgs: [LocationSyncStatus.synced.dbValue, cutoff],
    );
    if (deleted > 0) {
      debugPrint('[LocationDb] Pruned $deleted synced points older than $age');
    }
    return deleted;
  }

  /// Count of points still awaiting upload (any employee).
  Future<int> pendingCount() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE sync_status IN '
      '(${_placeholders(_syncableStatuses.length)})',
      _syncableStatuses,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  static String _placeholders(int count) =>
      List.filled(count, '?').join(', ');

  /// Keeps `last_sync_error` bounded — it is a diagnostic, not a log sink.
  static String _truncateError(String error) =>
      error.length > 300 ? error.substring(0, 300) : error;
}
