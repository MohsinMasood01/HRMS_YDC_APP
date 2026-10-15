import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/services/location_tracking_config_service.dart';
import 'package:lms/core/services/tracking_session_store.dart';
import 'package:lms/core/utils/server_time.dart';
import 'package:lms/features/attendance/domain/entities/biometric_attendance.dart';
import 'package:lms/features/location_tracking/data/tracelet_location_mapper.dart';
import 'package:lms/features/location_tracking/domain/entities/tracking_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A forgotten checkout must not be tracked past the shift's cutoff
/// (shift end + grace), and never into the following day(s).
///
/// Times are UTC. Pakistan is UTC+5, so a 09:00-17:00 local shift with a
/// 2-hour grace is 04:00Z-12:00Z with a 14:00Z cutoff.

final DateTime _checkIn = DateTime.utc(2026, 9, 22, 4, 5); // 09:05 PKT
final DateTime _cutoff = DateTime.utc(2026, 9, 22, 14); // 19:00 PKT

TrackingSession _session({
  TrackingState state = TrackingState.active,
  DateTime? startedAt,
  DateTime? cutoffAt,
  bool withCutoff = true,
  String attendanceDate = '2026-09-22',
}) {
  return TrackingSession(
    cardNo: '100002.1',
    attendanceDate: attendanceDate,
    state: state,
    intervalMinutes: 60,
    startedAt: startedAt ?? _checkIn,
    cutoffAt: withCutoff ? (cutoffAt ?? _cutoff) : null,
  );
}

Map<String, Object?> _fixAt(DateTime recordedAt) => {
  'uuid': 'tl-${recordedAt.millisecondsSinceEpoch}',
  'timestamp': recordedAt.toIso8601String(),
  'coords': {'latitude': 24.8607, 'longitude': 67.0011, 'accuracy': 9.4},
};

void main() {
  group('TrackingSession cutoff', () {
    test('uses the backend cutoff when one was given', () {
      expect(_session().effectiveCutoffAt, _cutoff);
    });

    test('falls back to a bounded session when the backend sent none', () {
      // Without this an old session never ends -- the original bug.
      expect(
        _session(withCutoff: false).effectiveCutoffAt,
        _checkIn.add(TrackingSession.fallbackMaxDuration),
      );
    });

    test('is live before the cutoff and expired from the cutoff on', () {
      final session = _session();
      expect(
        session.isExpiredAt(_cutoff.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(session.isExpiredAt(_cutoff), isTrue);
      expect(session.isExpiredAt(_cutoff.add(const Duration(days: 1))), isTrue);
    });

    test('a fix exactly at the cutoff is kept, one a second later is not', () {
      final session = _session();
      expect(session.acceptsFixAt(_cutoff), isTrue);
      expect(
        session.acceptsFixAt(_cutoff.add(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('copyWith can move the cutoff without losing identity', () {
      final later = _cutoff.add(const Duration(hours: 1));
      final moved = _session().copyWith(cutoffAt: later);
      expect(moved.cutoffAt, later);
      expect(moved.startedAt, _checkIn);
      expect(moved.cardNo, '100002.1');
    });
  });

  group('Fix mapper enforces the cutoff', () {
    test('a fix during the shift is queued', () {
      final point = locationPointFromTracelet(
        _fixAt(DateTime.utc(2026, 9, 22, 8)),
        session: _session(),
        localId: 'l1',
      );
      expect(point, isNotNull);
    });

    test('the reported bug: no checkout, next-day fix is NOT queued', () {
      // Employee checked in Tuesday and never checked out. Wednesday 10:00
      // PKT the engine fires again under the still-open session.
      final nextDay = DateTime.utc(2026, 9, 23, 5);
      final point = locationPointFromTracelet(
        _fixAt(nextDay),
        session: _session(),
        localId: 'l2',
      );
      expect(point, isNull);
    });

    test('a fix after the cutoff on the same day is not queued', () {
      final point = locationPointFromTracelet(
        _fixAt(_cutoff.add(const Duration(minutes: 1))),
        session: _session(),
        localId: 'l3',
      );
      expect(point, isNull);
    });

    test('a pre-cutoff fix delivered late (app asleep) is still kept', () {
      // Judged by when the fix was TAKEN, not when it is processed.
      final point = locationPointFromTracelet(
        _fixAt(_cutoff.subtract(const Duration(minutes: 1))),
        session: _session(),
        localId: 'l4',
        now: _cutoff.add(const Duration(hours: 3)),
      );
      expect(point, isNotNull);
    });

    test('a session saved before cutoffs existed still stops, via fallback', () {
      final twoDaysLater = _checkIn.add(const Duration(days: 2));
      final point = locationPointFromTracelet(
        _fixAt(twoDaysLater),
        session: _session(withCutoff: false),
        localId: 'l5',
      );
      expect(point, isNull);
    });

    test('an overnight shift keeps tracking past midnight', () {
      // 20:30-08:30 PKT shift (+2h grace) = 15:30Z to 05:30Z next day.
      final nightShift = _session(
        startedAt: DateTime.utc(2026, 9, 22, 15, 35),
        cutoffAt: DateTime.utc(2026, 9, 23, 5, 30),
      );
      // 02:00 PKT on the next calendar day -- still the same shift.
      final point = locationPointFromTracelet(
        _fixAt(DateTime.utc(2026, 9, 22, 21)),
        session: nightShift,
        localId: 'l6',
      );
      expect(point, isNotNull);
      expect(point!.attendanceDate, '2026-09-22');
    });

    test('after checkout (PAUSED) nothing is queued, even before cutoff', () {
      final point = locationPointFromTracelet(
        _fixAt(DateTime.utc(2026, 9, 22, 8)),
        session: _session(state: TrackingState.paused),
        localId: 'l7',
      );
      expect(point, isNull);
    });
  });

  group('parseServerInstant', () {
    test('reads Z and explicit offsets exactly', () {
      expect(
        parseServerInstant('2026-09-22T14:00:00Z'),
        DateTime.utc(2026, 9, 22, 14),
      );
      expect(
        parseServerInstant('2026-09-22T19:00:00+05:00'),
        DateTime.utc(2026, 9, 22, 14),
      );
    });

    test("accepts Oracle's space-separated form", () {
      expect(parseServerInstant('2026-09-22 14:00:00Z'), isNotNull);
    });

    test('returns null for missing or garbage values', () {
      expect(parseServerInstant(null), isNull);
      expect(parseServerInstant(''), isNull);
      expect(parseServerInstant('not a time'), isNull);
    });
  });

  group('Backend contract: tracking_cutoff_at', () {
    test('check-in response carries the cutoff and roster day', () {
      final response = BiometricAttendanceResponse.fromJson({
        'body': {
          'attendance_id': '1',
          'success': true,
          'tracking_cutoff_at': '2026-09-22T19:00:00+05:00',
          'attendance_date': '2026-09-22',
        },
      });
      expect(response.trackingCutoffAt, DateTime.utc(2026, 9, 22, 14));
      expect(response.attendanceDate, '2026-09-22');
    });

    test('an older backend without the fields leaves them null', () {
      final response = BiometricAttendanceResponse.fromJson({
        'body': {'attendance_id': '1', 'success': true},
      });
      expect(response.trackingCutoffAt, isNull);
      expect(response.attendanceDate, isNull);
    });

    test('tracking settings carry the open session cutoff and day', () {
      final config = LocationTrackingConfig.fromJson({
        'track_location': 'Y',
        'track_location_hr': 1,
        'tracking_cutoff_at': '2026-09-22T14:00:00Z',
        'attendance_date': '2026-09-22T00:00:00',
      });
      expect(config.trackingCutoffAt, DateTime.utc(2026, 9, 22, 14));
      expect(config.attendanceDate, '2026-09-22');
    });
  });

  group('TrackingSessionStore expiry', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('an expired ACTIVE session is not handed out as active', () async {
      final store = TrackingSessionStore();
      await store.save(_session());

      final during = await store.activeSession(
        now: DateTime.utc(2026, 9, 22, 8),
      );
      final after = await store.activeSession(
        now: _cutoff.add(const Duration(minutes: 1)),
      );
      expect(during, isNotNull);
      expect(after, isNull);
    });

    test('expireIfDue closes the session at its cutoff, once', () async {
      final store = TrackingSessionStore();
      await store.save(_session());
      final later = _cutoff.add(const Duration(hours: 20));

      final expired = await store.expireIfDue(now: later);
      expect(expired, isNotNull);
      // Returned as it was, so callers can still flush pre-cutoff fixes.
      expect(expired!.state, TrackingState.active);

      final stored = await store.read();
      expect(stored!.state, TrackingState.stopped);
      // Ended at the cutoff, not at whenever the phone noticed.
      expect(stored.endedAt, _cutoff);

      // Idempotent: nothing left to expire.
      expect(await store.expireIfDue(now: later), isNull);
    });

    test('a PAUSED session also expires at its cutoff', () async {
      final store = TrackingSessionStore();
      await store.save(_session(state: TrackingState.paused));

      final expired = await store.expireIfDue(
        now: _cutoff.add(const Duration(minutes: 5)),
      );
      expect(expired, isNotNull);
      expect((await store.read())!.state, TrackingState.stopped);
    });

    test('nothing expires before the cutoff', () async {
      final store = TrackingSessionStore();
      await store.save(_session());

      expect(
        await store.expireIfDue(now: DateTime.utc(2026, 9, 22, 8)),
        isNull,
      );
      expect((await store.read())!.state, TrackingState.active);
    });

    test('the cutoff survives a save/read round trip', () async {
      final store = TrackingSessionStore();
      await store.save(_session());
      expect((await store.read())!.cutoffAt, _cutoff);
    });
  });
}
