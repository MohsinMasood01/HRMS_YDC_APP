import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/entities/location_point.dart';

/// Outcome the backend reported for a single point in a batch.
class LocationSyncItemResult {
  const LocationSyncItemResult({
    required this.clientEventId,
    required this.result,
    this.serverId,
    this.syncedAt,
    this.error,
  });

  final String clientEventId;
  final LocationSyncResult result;
  final int? serverId;
  final DateTime? syncedAt;
  final String? error;
}

/// Thrown when the batch call itself failed (transport, auth, 5xx).
///
/// Distinct from a per-record FAILED: nothing in the batch was accepted, so
/// every point stays queued for the next attempt.
class LocationSyncTransportException implements Exception {
  const LocationSyncTransportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the backend batch location-sync endpoint.
///
/// BACKEND CONTRACT (verified against the deployed Node backend,
/// `src/routes/auth.routes.js` + `controllers/location.controller.js`, and
/// against production with a no-op request):
///   POST /auth/location/batch
///   { "card_no": "100002.1",
///     "locations": [ { latitude, longitude, accuracy, recorded_at }, ... ] }
///
///   200 { "body": { "inserted": N } }   -- all rows inserted
///   500 { "detail": "..." }             -- nothing inserted (rolled back)
///
/// One card per request, so every batch must belong to a single employee
/// (`LocationRepositoryImpl._syncCard` guarantees this). The endpoint has no
/// per-record breakdown and no idempotency key: a 2xx means the whole batch is
/// stored. `recorded_at` is stored as its literal wall clock with the zone
/// designator stripped, so it is always sent as UTC -- the same convention
/// the server uses for the attendance-origin point it inserts itself.
///
/// History: an earlier build pointed this at `/location-tracks/sync`, which
/// has never existed on the server (404 in production), so no tracked point
/// from those builds ever arrived. Responses carrying a `results` list are
/// still parsed in case the backend later adds per-record outcomes.
class LocationRemoteDataSource {
  LocationRemoteDataSource({Dio? dio, String? Function()? tokenProvider})
    : _dio = dio ?? DioClient.instance,
      _tokenProvider = tokenProvider;

  final Dio _dio;
  final String? Function()? _tokenProvider;

  /// Batch sync endpoint. Single source of truth for the path — if the
  /// backend names it differently, change it here only.
  static const String syncPath = '/auth/location/batch';

  /// Request body for one batch. All [points] must share one card number.
  static Map<String, dynamic> buildBatchBody(List<LocationPoint> points) {
    final cards = points.map((p) => p.cardNo).toSet();
    if (cards.length != 1) {
      throw ArgumentError(
        'A location batch must belong to exactly one card, got $cards',
      );
    }
    return {
      'card_no': cards.single,
      'locations': points
          .map(
            (p) => {
              'latitude': p.latitude,
              'longitude': p.longitude,
              // Omitted, never null, when unknown: the server's schema
              // (`pyFloat().optional().default(0.0)`) rejects an explicit
              // null with a 400, and batches are all-or-nothing -- a single
              // null would block that employee's whole queue permanently.
              // Verified against the backend's own Zod schema (zod 4.4.3).
              if (p.accuracy != null) 'accuracy': p.accuracy,
              'recorded_at': p.recordedAt.toUtc().toIso8601String(),
            },
          )
          .toList(),
    };
  }

  /// Uploads one batch and reports the per-point outcome.
  ///
  /// Throws [LocationSyncTransportException] when the request itself failed;
  /// callers must then leave every point queued.
  Future<List<LocationSyncItemResult>> syncBatch(
    List<LocationPoint> points, {
    String? authToken,
  }) async {
    if (points.isEmpty) return const [];

    final token = authToken ?? _tokenProvider?.call();
    final headers = <String, dynamic>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _dio.post<dynamic>(
        syncPath,
        data: buildBatchBody(points),
        options: Options(
          headers: headers,
          // A partial-success body is still useful, so let us parse 4xx
          // rather than having Dio throw before we can read it.
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw LocationSyncTransportException(
          'Sync rejected with HTTP $status',
        );
      }

      return _parseResults(response.data, points);
    } on DioException catch (e) {
      throw LocationSyncTransportException(
        e.message ?? 'Network error during location sync',
      );
    }
  }

  List<LocationSyncItemResult> _parseResults(
    dynamic data,
    List<LocationPoint> sent,
  ) {
    final map = _asMap(data);
    // Unwrap the `body` envelope used elsewhere in this API.
    final body = _asMap(map?['body']) ?? map;

    final rawResults = body?['results'] ?? body?['locations'];

    if (rawResults is! List || rawResults.isEmpty) {
      // 2xx with no breakdown: the backend accepted the batch wholesale.
      debugPrint(
        '[LocationSync] No per-record results returned; '
        'treating ${sent.length} point(s) as accepted',
      );
      return sent
          .map(
            (p) => LocationSyncItemResult(
              clientEventId: p.clientEventId,
              result: LocationSyncResult.synced,
            ),
          )
          .toList();
    }

    final results = <LocationSyncItemResult>[];
    for (final entry in rawResults) {
      final row = _asMap(entry);
      if (row == null) continue;

      final clientEventId = row['client_event_id']?.toString();
      if (clientEventId == null || clientEventId.isEmpty) continue;

      results.add(
        LocationSyncItemResult(
          clientEventId: clientEventId,
          result: LocationSyncResult.fromWire(row['status']?.toString()),
          serverId: _asInt(row['server_id'] ?? row['id']),
          syncedAt: DateTime.tryParse(row['synced_at']?.toString() ?? '')
              ?.toUtc(),
          error: row['error']?.toString() ?? row['message']?.toString(),
        ),
      );
    }
    return results;
  }

  static Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
