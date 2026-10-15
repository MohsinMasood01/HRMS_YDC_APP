import 'package:equatable/equatable.dart';

/// Local synchronisation state of a captured location point.
///
/// A point is born [pending]. The sync service flips it to [syncing] while a
/// batch is in flight, then to [synced] on confirmation or [failed] when the
/// backend rejected it. A [failed] record is *never* deleted — it is retried
/// on the next sync pass. Only [synced] records are ever pruned.
enum LocationSyncStatus {
  pending('PENDING'),
  syncing('SYNCING'),
  synced('SYNCED'),
  failed('FAILED');

  const LocationSyncStatus(this.dbValue);

  final String dbValue;

  static LocationSyncStatus fromDb(String? value) {
    for (final status in LocationSyncStatus.values) {
      if (status.dbValue == value) return status;
    }
    return LocationSyncStatus.pending;
  }
}

/// Per-record outcome reported by the backend batch sync endpoint.
enum LocationSyncResult {
  synced('SYNCED'),
  alreadySynced('ALREADY_SYNCED'),
  failed('FAILED');

  const LocationSyncResult(this.wireValue);

  final String wireValue;

  /// Parses the backend's status string. Unknown values are treated as
  /// [failed] so the record survives locally and is retried rather than
  /// being silently dropped.
  static LocationSyncResult fromWire(String? value) {
    final normalised = value?.trim().toUpperCase();
    for (final result in LocationSyncResult.values) {
      if (result.wireValue == normalised) return result;
    }
    return LocationSyncResult.failed;
  }

  /// Both SYNCED and ALREADY_SYNCED mean the backend holds the record.
  bool get isAccepted => this != LocationSyncResult.failed;
}

/// A single GPS sample captured during a tracking session.
///
/// [clientEventId] is generated once, at capture time, and is **immutable
/// across retries** — the backend uses it as the idempotency key so a point
/// re-sent after a timeout is not stored twice.
class LocationPoint extends Equatable {
  const LocationPoint({
    required this.localId,
    required this.clientEventId,
    required this.cardNo,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.attendanceDate,
    required this.createdAt,
    this.accuracy,
    this.serverId,
    this.syncedAt,
    this.syncStatus = LocationSyncStatus.pending,
    this.retryCount = 0,
    this.lastSyncError,
  });

  /// Local primary key (UUID v4). Distinct from [clientEventId] so the local
  /// row identity never depends on the wire protocol.
  final String localId;

  /// Idempotency key sent to the backend. Never regenerated on retry.
  final String clientEventId;

  /// Employee this point belongs to. Always the card number of the session
  /// that captured it — never the currently logged-in user.
  final String cardNo;

  final double latitude;
  final double longitude;

  /// Real GPS accuracy in metres, as reported by the device. Never fabricated.
  final double? accuracy;

  /// Capture time, always stored in UTC.
  final DateTime recordedAt;

  /// Attendance day this point belongs to (yyyy-MM-dd). Taken from the
  /// tracking session, so points captured after midnight still belong to the
  /// shift that opened the session.
  final String attendanceDate;

  /// Row creation time in UTC.
  final DateTime createdAt;

  /// Server-side LOCATION_TRACKS.ID once acknowledged.
  final int? serverId;

  /// When the backend confirmed the record, in UTC.
  final DateTime? syncedAt;

  final LocationSyncStatus syncStatus;
  final int retryCount;
  final String? lastSyncError;

  LocationPoint copyWith({
    int? serverId,
    DateTime? syncedAt,
    LocationSyncStatus? syncStatus,
    int? retryCount,
    String? lastSyncError,
    bool clearError = false,
  }) {
    return LocationPoint(
      localId: localId,
      clientEventId: clientEventId,
      cardNo: cardNo,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      recordedAt: recordedAt,
      attendanceDate: attendanceDate,
      createdAt: createdAt,
      serverId: serverId ?? this.serverId,
      syncedAt: syncedAt ?? this.syncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastSyncError: clearError ? null : (lastSyncError ?? this.lastSyncError),
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'local_id': localId,
      'client_event_id': clientEventId,
      'card_no': cardNo,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'attendance_date': attendanceDate,
      'created_at': createdAt.toUtc().toIso8601String(),
      'server_id': serverId,
      'synced_at': syncedAt?.toUtc().toIso8601String(),
      'sync_status': syncStatus.dbValue,
      'retry_count': retryCount,
      'last_sync_error': lastSyncError,
    };
  }

  factory LocationPoint.fromDb(Map<String, dynamic> row) {
    double? toDouble(Object? v) => v == null ? null : (v as num).toDouble();
    DateTime? toDate(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString())?.toUtc();
    }

    return LocationPoint(
      localId: row['local_id'] as String,
      clientEventId: row['client_event_id'] as String,
      cardNo: row['card_no'] as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      accuracy: toDouble(row['accuracy']),
      recordedAt: toDate(row['recorded_at']) ?? DateTime.now().toUtc(),
      attendanceDate: (row['attendance_date'] ?? '').toString(),
      createdAt: toDate(row['created_at']) ?? DateTime.now().toUtc(),
      serverId: row['server_id'] as int?,
      syncedAt: toDate(row['synced_at']),
      syncStatus: LocationSyncStatus.fromDb(row['sync_status'] as String?),
      retryCount: (row['retry_count'] as int?) ?? 0,
      lastSyncError: row['last_sync_error'] as String?,
    );
  }

  /// Wire payload for the batch sync endpoint.
  ///
  /// BACKEND CONTRACT: field names follow the agreed LOCATION_TRACKS schema.
  /// Timestamps are ISO-8601 UTC; [attendanceDate] is a plain yyyy-MM-dd day.
  Map<String, dynamic> toSyncJson() {
    return {
      'client_event_id': clientEventId,
      'card_no': cardNo,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'attendance_date': attendanceDate,
    };
  }

  @override
  List<Object?> get props => [
    localId,
    clientEventId,
    cardNo,
    latitude,
    longitude,
    accuracy,
    recordedAt,
    attendanceDate,
    createdAt,
    serverId,
    syncedAt,
    syncStatus,
    retryCount,
    lastSyncError,
  ];
}
