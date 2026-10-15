import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Owns the location-tracking SQLite database: path, version and schema.
///
/// This class deliberately contains **no queries** — CRUD lives in
/// `LocationLocalDataSource`. It exists as a single schema authority because
/// the database is opened from two isolates: the UI isolate and the
/// WorkManager background isolate. Both must agree on version and migrations,
/// so both go through [open].
class LocationTrackDb {
  static const String dbName = 'lms_location_tracks.db';

  /// v1 — legacy `location_tracks` table (auto-inc id, `synced` flag).
  /// v2 — `location_tracks_local` with UUID keys, sync states and retries.
  static const int dbVersion = 2;

  /// Current table name.
  static const String table = 'location_tracks_local';

  /// Pre-v2 table name, retained only for the migration path.
  static const String legacyTable = 'location_tracks';

  Database? _db;

  /// Cached handle for the isolate that owns this instance.
  Future<Database> get database async => _db ??= await open();

  /// Opens (and migrates) the database. Safe to call from any isolate.
  ///
  /// The background isolate uses this directly and closes the handle when its
  /// task finishes, rather than sharing the UI isolate's cached instance.
  static Future<Database> open() async {
    final path = join(await getDatabasesPath(), dbName);
    return openDatabase(
      path,
      version: dbVersion,
      onCreate: (db, _) async => _createV2(db),
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        local_id        TEXT PRIMARY KEY,
        server_id       INTEGER,
        client_event_id TEXT NOT NULL UNIQUE,
        card_no         TEXT NOT NULL,
        latitude        REAL NOT NULL,
        longitude       REAL NOT NULL,
        accuracy        REAL,
        recorded_at     TEXT NOT NULL,
        synced_at       TEXT,
        attendance_date TEXT,
        sync_status     TEXT NOT NULL DEFAULT 'PENDING',
        retry_count     INTEGER NOT NULL DEFAULT 0,
        last_sync_error TEXT,
        created_at      TEXT NOT NULL
      )
    ''');

    // Sync passes always filter by status, and usually by employee.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_status '
      'ON $table (sync_status, recorded_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${table}_card '
      'ON $table (card_no, sync_status)',
    );
  }

  /// v1 -> v2 migration.
  ///
  /// Any points queued by an older build are carried across rather than
  /// dropped: a fresh UUID is minted for each (they were never sent under an
  /// idempotency key, so a new one is correct), the legacy `synced` flag maps
  /// onto the new status column, and `attendance_date` is backfilled from the
  /// recorded day. Only after a successful copy is the old table dropped.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 2) return;

    await _createV2(db);

    final legacyExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [legacyTable],
    );
    if (legacyExists.isEmpty) return;

    const uuid = Uuid();
    final legacyRows = await db.query(legacyTable);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final batch = db.batch();
    for (final row in legacyRows) {
      final recordedAt = row['recorded_at']?.toString() ?? nowIso;
      final wasSynced = (row['synced'] as int?) == 1;

      batch.insert(table, {
        'local_id': uuid.v4(),
        'client_event_id': uuid.v4(),
        'card_no': row['card_no']?.toString() ?? '',
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'accuracy': row['accuracy'],
        'recorded_at': recordedAt,
        'synced_at': wasSynced ? nowIso : null,
        // Legacy rows carry no attendance day; the recorded date is the best
        // available approximation.
        'attendance_date': recordedAt.length >= 10
            ? recordedAt.substring(0, 10)
            : null,
        'sync_status': wasSynced ? 'SYNCED' : 'PENDING',
        'retry_count': 0,
        'created_at': recordedAt,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    await db.execute('DROP TABLE IF EXISTS $legacyTable');
  }
}
