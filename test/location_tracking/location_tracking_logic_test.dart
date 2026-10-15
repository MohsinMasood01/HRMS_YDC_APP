import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/services/location_tracking_config_service.dart';
import 'package:lms/features/attendance/domain/entities/biometric_attendance.dart';
import 'package:lms/features/location_tracking/domain/entities/location_point.dart';
import 'package:lms/features/location_tracking/domain/entities/tracking_session.dart';

/// Pure-logic tests for offline location tracking.
///
/// Deliberately free of sqflite / plugin channels so they run under plain
/// `flutter test` with no platform bindings.
void main() {
  group('LocationSyncStatus', () {
    test('maps database values both ways', () {
      expect(LocationSyncStatus.fromDb('PENDING'), LocationSyncStatus.pending);
      expect(LocationSyncStatus.fromDb('SYNCING'), LocationSyncStatus.syncing);
      expect(LocationSyncStatus.fromDb('SYNCED'), LocationSyncStatus.synced);
      expect(LocationSyncStatus.fromDb('FAILED'), LocationSyncStatus.failed);
    });

    test('falls back to PENDING for unknown or null values', () {
      // A row we cannot classify must stay eligible for upload rather than
      // being treated as already delivered.
      expect(LocationSyncStatus.fromDb(null), LocationSyncStatus.pending);
      expect(LocationSyncStatus.fromDb('GARBAGE'), LocationSyncStatus.pending);
    });
  });

  group('LocationSyncResult', () {
    test('SYNCED and ALREADY_SYNCED both count as accepted', () {
      expect(LocationSyncResult.fromWire('SYNCED').isAccepted, isTrue);
      expect(LocationSyncResult.fromWire('ALREADY_SYNCED').isAccepted, isTrue);
    });

    test('FAILED is not accepted', () {
      expect(LocationSyncResult.fromWire('FAILED').isAccepted, isFalse);
    });

    test('unknown status is treated as FAILED so the point survives', () {
      final result = LocationSyncResult.fromWire('WAT');
      expect(result, LocationSyncResult.failed);
      expect(result.isAccepted, isFalse);
    });

    test('is case and whitespace tolerant', () {
      expect(LocationSyncResult.fromWire(' synced '), LocationSyncResult.synced);
    });
  });

  group('LocationPoint', () {
    LocationPoint buildPoint() => LocationPoint(
      localId: 'local-1',
      clientEventId: 'abc-123',
      cardNo: '100569.1',
      latitude: 24.8607,
      longitude: 67.0011,
      accuracy: 7.5,
      recordedAt: DateTime.utc(2026, 8, 11, 9, 30),
      attendanceDate: '2026-08-11',
      createdAt: DateTime.utc(2026, 8, 11, 9, 30, 1),
    );

    test('survives a database round trip', () {
      final original = buildPoint();
      final restored = LocationPoint.fromDb(original.toDb());

      expect(restored.localId, original.localId);
      expect(restored.clientEventId, original.clientEventId);
      expect(restored.cardNo, original.cardNo);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.accuracy, original.accuracy);
      expect(restored.recordedAt, original.recordedAt);
      expect(restored.attendanceDate, original.attendanceDate);
      expect(restored.syncStatus, LocationSyncStatus.pending);
      expect(restored.retryCount, 0);
    });

    test('sync payload carries exactly the agreed backend fields', () {
      expect(buildPoint().toSyncJson().keys, containsAll(<String>[
        'client_event_id',
        'card_no',
        'latitude',
        'longitude',
        'accuracy',
        'recorded_at',
        'attendance_date',
      ]));
    });

    test('keeps client_event_id stable across retries', () {
      // The backend dedupes on this key, so a retry of the same capture must
      // present the same id or the point would be stored twice.
      final original = buildPoint();
      final afterFailure = original.copyWith(
        syncStatus: LocationSyncStatus.failed,
        retryCount: 1,
        lastSyncError: 'timeout',
      );
      final afterSecondFailure = afterFailure.copyWith(
        retryCount: 2,
        lastSyncError: 'offline',
      );

      expect(afterFailure.clientEventId, original.clientEventId);
      expect(afterSecondFailure.clientEventId, original.clientEventId);
      expect(afterSecondFailure.retryCount, 2);
    });

    test('never invents an accuracy value', () {
      final noAccuracy = LocationPoint(
        localId: 'local-2',
        clientEventId: 'def-456',
        cardNo: '100569.1',
        latitude: 24.8607,
        longitude: 67.0011,
        recordedAt: DateTime.utc(2026, 8, 11, 10),
        attendanceDate: '2026-08-11',
        createdAt: DateTime.utc(2026, 8, 11, 10),
      );
      expect(noAccuracy.accuracy, isNull);
      expect(noAccuracy.toSyncJson()['accuracy'], isNull);
    });

    test('serialises timestamps as UTC regardless of input zone', () {
      final local = DateTime.now();
      final point = LocationPoint(
        localId: 'local-3',
        clientEventId: 'ghi-789',
        cardNo: '1',
        latitude: 1,
        longitude: 1,
        recordedAt: local,
        attendanceDate: '2026-08-11',
        createdAt: local,
      );
      expect(point.toSyncJson()['recorded_at'], endsWith('Z'));
    });
  });

  group('TrackingState', () {
    test('only ACTIVE captures', () {
      expect(TrackingState.active.shouldCapture, isTrue);
      expect(TrackingState.paused.shouldCapture, isFalse);
      expect(TrackingState.stopped.shouldCapture, isFalse);
      expect(TrackingState.inactive.shouldCapture, isFalse);
    });

    test('ACTIVE and PAUSED sessions can be resumed, STOPPED cannot', () {
      // An intermediate checkout must not permanently end tracking.
      expect(TrackingState.active.isResumable, isTrue);
      expect(TrackingState.paused.isResumable, isTrue);
      expect(TrackingState.stopped.isResumable, isFalse);
    });

    test('round trips through storage', () {
      for (final state in TrackingState.values) {
        expect(TrackingState.fromStorage(state.storageValue), state);
      }
      expect(TrackingState.fromStorage(null), TrackingState.inactive);
      expect(TrackingState.fromStorage('NONSENSE'), TrackingState.inactive);
    });
  });

  group('BackendTrackingDirective', () {
    test('parses the documented values', () {
      expect(
        BackendTrackingDirective.fromWire('STOPPED'),
        BackendTrackingDirective.stopped,
      );
      expect(
        BackendTrackingDirective.fromWire('paused'),
        BackendTrackingDirective.paused,
      );
      expect(
        BackendTrackingDirective.fromWire('ACTIVE'),
        BackendTrackingDirective.active,
      );
    });

    test('returns null when the backend says nothing', () {
      // Null means "no ruling", which callers treat as an intermediate
      // checkout rather than inventing a final one on the phone.
      expect(BackendTrackingDirective.fromWire(null), isNull);
      expect(BackendTrackingDirective.fromWire(''), isNull);
      expect(BackendTrackingDirective.fromWire('unknown'), isNull);
    });
  });

  group('TrackingSession', () {
    test('copyWith preserves identity while changing state', () {
      final session = TrackingSession(
        cardNo: '100569.1',
        attendanceDate: '2026-08-11',
        state: TrackingState.active,
        intervalMinutes: 60,
        startedAt: DateTime.utc(2026, 8, 11, 9),
      );

      final paused = session.copyWith(state: TrackingState.paused);
      expect(paused.cardNo, session.cardNo);
      expect(paused.attendanceDate, session.attendanceDate);
      expect(paused.startedAt, session.startedAt);
      expect(paused.state, TrackingState.paused);
      expect(paused.isActive, isFalse);
    });
  });

  group('LocationTrackingConfig interval resolution', () {
    test('explicit minutes win over hours', () {
      final config = LocationTrackingConfig.fromJson({
        'track_location': 'Y',
        'interval_minutes': 90,
        'track_location_hr': 2,
      });
      expect(config.resolvedIntervalMinutes, 90);
    });

    test('hours are converted to minutes when minutes are absent', () {
      final config = LocationTrackingConfig.fromJson({
        'track_location': 'Y',
        'track_location_hr': 2,
      });
      expect(config.resolvedIntervalMinutes, 120);
    });

    test('returns null when the backend states no interval', () {
      // Distinguishing "not stated" from a default is what lets the scheduler
      // fall back to the cached value instead of inventing one.
      final config = LocationTrackingConfig.fromJson({'track_location': 'Y'});
      expect(config.resolvedIntervalMinutes, isNull);
    });

    test('reads the tracking-enabled flag case-insensitively', () {
      expect(
        LocationTrackingConfig.fromJson({'track_location': 'y'})
            .isTrackingEnabled,
        isTrue,
      );
      expect(
        LocationTrackingConfig.fromJson({'track_location': 'N'})
            .isTrackingEnabled,
        isFalse,
      );
    });
  });

  group('BiometricAttendanceResponse checkout ruling', () {
    test('reads is_final_checkout and tracking_state from the body', () {
      final response = BiometricAttendanceResponse.fromJson({
        'body': {
          'attendance_id': '1',
          'success': true,
          'is_final_checkout': false,
          'tracking_state': 'PAUSED',
        },
      });
      expect(response.isFinalCheckout, isFalse);
      expect(response.trackingState, 'PAUSED');
    });

    test('leaves both null when the backend omits them', () {
      final response = BiometricAttendanceResponse.fromJson({
        'body': {'attendance_id': '1', 'success': true},
      });
      expect(response.isFinalCheckout, isNull);
      expect(response.trackingState, isNull);
    });
  });
}
