import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/location_tracking/data/datasources/location_remote_data_source.dart';
import 'package:lms/features/location_tracking/data/tracelet_location_mapper.dart';
import 'package:lms/features/location_tracking/domain/entities/location_point.dart';
import 'package:lms/features/location_tracking/domain/entities/tracking_session.dart';

/// Records the last request and replies with a canned response.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

LocationPoint _point({
  String cardNo = '100002.1',
  String clientEventId = 'evt-1',
  double? accuracy = 12.5,
  DateTime? recordedAt,
}) {
  return LocationPoint(
    localId: 'local-$clientEventId',
    clientEventId: clientEventId,
    cardNo: cardNo,
    latitude: 24.8607,
    longitude: 67.0011,
    accuracy: accuracy,
    recordedAt: recordedAt ?? DateTime.utc(2026, 9, 15, 9, 5),
    attendanceDate: '2026-09-15',
    createdAt: DateTime.utc(2026, 9, 15, 9, 5),
  );
}

TrackingSession _session({
  TrackingState state = TrackingState.active,
  String cardNo = '100002.1',
  DateTime? startedAt,
}) {
  return TrackingSession(
    cardNo: cardNo,
    attendanceDate: '2026-09-15',
    state: state,
    intervalMinutes: 60,
    startedAt: startedAt ?? DateTime.utc(2026, 9, 15, 4),
  );
}

Map<String, Object?> _traceletFix({
  String? uuid = 'tl-uuid-1',
  Object? latitude = 24.8607,
  Object? longitude = 67.0011,
  Object? accuracy = 9.4,
  Object? timestamp = '2026-09-15T09:05:00.000Z',
}) {
  return {
    'uuid': uuid,
    'timestamp': timestamp,
    'coords': {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    },
  };
}

void main() {
  group('backend contract: POST /auth/location/batch', () {
    test('posts to the endpoint that exists on the server', () {
      // /location-tracks/sync returned 404 in production; this one returns
      // 200 {"body":{"inserted":0}} for an empty batch.
      expect(LocationRemoteDataSource.syncPath, '/auth/location/batch');
    });

    test('body is card_no at the root plus the four accepted point fields', () {
      final body = LocationRemoteDataSource.buildBatchBody([
        _point(clientEventId: 'a'),
        _point(clientEventId: 'b', accuracy: null),
      ]);

      expect(body.keys, unorderedEquals(['card_no', 'locations']));
      expect(body['card_no'], '100002.1');

      final locations = body['locations'] as List;
      expect(locations, hasLength(2));
      expect(
        (locations.first as Map).keys,
        unorderedEquals(['latitude', 'longitude', 'accuracy', 'recorded_at']),
      );
    });

    test('unknown accuracy is omitted, never sent as null', () {
      // The server rejects {"accuracy": null} with a 400 (checked against its
      // Zod schema) but accepts a missing key. A single null would otherwise
      // wedge the whole batch, and with it that employee's queue.
      final body = LocationRemoteDataSource.buildBatchBody([
        _point(accuracy: null),
      ]);
      final location = (body['locations'] as List).single as Map;
      expect(location.containsKey('accuracy'), isFalse);
      expect(
        location.keys,
        unorderedEquals(['latitude', 'longitude', 'recorded_at']),
      );
    });

    test('recorded_at is sent as UTC, matching the server convention', () {
      final body = LocationRemoteDataSource.buildBatchBody([
        _point(recordedAt: DateTime.utc(2026, 9, 15, 9, 5, 7)),
      ]);
      final recordedAt =
          ((body['locations'] as List).single as Map)['recorded_at'] as String;
      expect(recordedAt, '2026-09-15T09:05:07.000Z');
    });

    test('refuses a batch that mixes employees', () {
      expect(
        () => LocationRemoteDataSource.buildBatchBody([
          _point(cardNo: '100002.1', clientEventId: 'a'),
          _point(cardNo: '100660.1', clientEventId: 'b'),
        ]),
        throwsArgumentError,
      );
    });

    test('a 200 {"body":{"inserted":N}} marks the whole batch accepted', () async {
      final adapter = _FakeAdapter(200, {
        'body': {'inserted': 2},
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..httpClientAdapter = adapter;
      final remote = LocationRemoteDataSource(dio: dio);

      final results = await remote.syncBatch([
        _point(clientEventId: 'a'),
        _point(clientEventId: 'b'),
      ]);

      expect(adapter.lastRequest!.path, '/auth/location/batch');
      expect(adapter.lastRequest!.method, 'POST');
      expect((adapter.lastRequest!.data as Map)['card_no'], '100002.1');
      expect(results.map((r) => r.clientEventId), ['a', 'b']);
      expect(results.every((r) => r.result.isAccepted), isTrue);
    });

    test('a server error keeps every point queued', () async {
      final adapter = _FakeAdapter(500, {'detail': 'ORA-00001'});
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..httpClientAdapter = adapter;
      final remote = LocationRemoteDataSource(dio: dio);

      expect(
        () => remote.syncBatch([_point()]),
        throwsA(isA<LocationSyncTransportException>()),
      );
    });

    test('a 404 is a failure, never silently accepted', () async {
      final adapter = _FakeAdapter(404, {});
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
        ..httpClientAdapter = adapter;
      final remote = LocationRemoteDataSource(dio: dio);

      expect(
        () => remote.syncBatch([_point()]),
        throwsA(isA<LocationSyncTransportException>()),
      );
    });
  });

  group('Tracelet fix -> queued point', () {
    test('an ACTIVE session queues the fix under the session card', () {
      final point = locationPointFromTracelet(
        _traceletFix(),
        session: _session(cardNo: '100660.1'),
        localId: 'local-1',
      );

      expect(point, isNotNull);
      expect(point!.cardNo, '100660.1');
      expect(point.attendanceDate, '2026-09-15');
      expect(point.latitude, 24.8607);
      expect(point.longitude, 67.0011);
      expect(point.accuracy, 9.4);
      expect(point.recordedAt, DateTime.utc(2026, 9, 15, 9, 5));
      expect(point.recordedAt.isUtc, isTrue);
    });

    test('the same fix re-emitted under a new uuid is one point', () {
      // Observed on a Samsung SM-G973F: an interval change made Tracelet
      // re-emit its last fix (identical time and coordinates) with a new
      // uuid, which a uuid-based key uploaded twice.
      final original = locationPointFromTracelet(
        _traceletFix(uuid: 'fd3db165-3aad-45f5-8d0a-827f80ecd448'),
        session: _session(),
        localId: 'x',
      );
      final reEmitted = locationPointFromTracelet(
        _traceletFix(uuid: '9f6b7506-27de-4bb8-87e8-959ee2ca89f3'),
        session: _session(),
        localId: 'y',
      );
      expect(reEmitted!.clientEventId, original!.clientEventId);
    });

    test('the key does not depend on a uuid being present', () {
      final a = locationPointFromTracelet(
        _traceletFix(uuid: null),
        session: _session(),
        localId: 'x',
      );
      final b = locationPointFromTracelet(
        _traceletFix(uuid: 'anything'),
        session: _session(),
        localId: 'y',
      );
      expect(a!.clientEventId, b!.clientEventId);
    });

    test('a genuinely new fix gets a different key', () {
      final first = locationPointFromTracelet(
        _traceletFix(timestamp: '2026-09-15T09:05:00.000Z'),
        session: _session(),
        localId: 'x',
      );
      final tenMinutesLater = locationPointFromTracelet(
        _traceletFix(timestamp: '2026-09-15T09:15:00.000Z'),
        session: _session(),
        localId: 'y',
      );
      expect(tenMinutesLater!.clientEventId, isNot(first!.clientEventId));
    });

    test('nothing is queued without an ACTIVE session', () {
      for (final state in [TrackingState.paused, TrackingState.stopped]) {
        expect(
          locationPointFromTracelet(
            _traceletFix(),
            session: _session(state: state),
            localId: 'x',
          ),
          isNull,
          reason: '$state must not record',
        );
      }
      expect(
        locationPointFromTracelet(_traceletFix(), session: null, localId: 'x'),
        isNull,
      );
    });

    test('a fix from before the session is not attributed to it', () {
      final point = locationPointFromTracelet(
        _traceletFix(timestamp: '2026-09-15T03:00:00.000Z'),
        session: _session(startedAt: DateTime.utc(2026, 9, 15, 4)),
        localId: 'x',
      );
      expect(point, isNull);
    });

    test('a fix taken just around check-in is kept', () {
      final point = locationPointFromTracelet(
        _traceletFix(timestamp: '2026-09-15T03:59:00.000Z'),
        session: _session(startedAt: DateTime.utc(2026, 9, 15, 4)),
        localId: 'x',
      );
      expect(point, isNotNull);
    });

    test('impossible coordinates are never queued', () {
      for (final fix in [
        _traceletFix(latitude: 0, longitude: 0),
        _traceletFix(latitude: 91),
        _traceletFix(longitude: -181),
        _traceletFix(latitude: null),
      ]) {
        expect(
          locationPointFromTracelet(fix, session: _session(), localId: 'x'),
          isNull,
        );
      }
    });

    test('unknown (negative) accuracy stays unknown', () {
      final point = locationPointFromTracelet(
        _traceletFix(accuracy: -1),
        session: _session(),
        localId: 'x',
      );
      expect(point!.accuracy, isNull);
    });

    test('a local-offset timestamp is normalised to UTC', () {
      final point = locationPointFromTracelet(
        _traceletFix(timestamp: '2026-09-15T14:05:00.000+05:00'),
        session: _session(),
        localId: 'x',
      );
      expect(point!.recordedAt, DateTime.utc(2026, 9, 15, 9, 5));
    });
  });
}
