import 'package:flutter_test/flutter_test.dart';
import 'package:lms/features/attendance/domain/entities/biometric_attendance.dart';
import 'package:lms/features/attendance/domain/entities/location_info.dart';

void main() {
  BiometricAttendanceResponse parse(Map<String, dynamic> body) =>
      BiometricAttendanceResponse.fromJson({'body': body});

  final location = LocationInfo(
    latitude: 24.8,
    longitude: 67.0,
    accuracy: 8.0,
    timestamp: DateTime(2026, 9, 10, 9),
  );

  group('client_event_id', () {
    test('is sent on the punch body when present', () {
      final request = BiometricAttendanceRequest(
        employeeId: '123',
        attendanceType: 'check_in',
        biometricType: 'face',
        locationInfo: location,
        timestamp: DateTime(2026, 9, 10, 9),
        clientEventId: 'abc-123',
      );
      expect(request.toJson()['client_event_id'], 'abc-123');
    });

    test('is omitted entirely rather than sent as null', () {
      final request = BiometricAttendanceRequest(
        employeeId: '123',
        attendanceType: 'check_in',
        biometricType: 'face',
        locationInfo: location,
        timestamp: DateTime(2026, 9, 10, 9),
      );
      expect(request.toJson().containsKey('client_event_id'), isFalse);
    });
  });

  group('posted_to_erp', () {
    test('false means saved but not on the roster - a note, not a failure', () {
      final response = parse({'success': true, 'posted_to_erp': false});
      expect(response.success, isTrue);
      expect(response.isHrSyncPending, isTrue);
    });

    test('true shows no note', () {
      expect(
        parse({'success': true, 'posted_to_erp': true}).isHrSyncPending,
        isFalse,
      );
    });

    test('absent is treated exactly as today - no note', () {
      expect(parse({'success': true}).isHrSyncPending, isFalse);
      expect(parse({'success': true}).postedToErp, isNull);
    });
  });

  group('action', () {
    test('noop is recognised so the UI does not claim a fresh check-in', () {
      expect(parse({'success': true, 'action': 'noop'}).isNoop, isTrue);
    });

    test('already_done records nothing, same as noop', () {
      expect(
        parse({'success': true, 'action': 'already_done'}).isNoop,
        isTrue,
      );
    });

    test('a real punch is not a noop', () {
      expect(parse({'success': true, 'action': 'check_in'}).isNoop, isFalse);
      expect(parse({'success': true, 'action': 'check_out'}).isNoop, isFalse);
    });

    test('a backend that omits action reports neither', () {
      final response = parse({'success': true});
      expect(response.action, isNull);
      expect(response.isNoop, isFalse);
    });
  });

  group('existing fields still parse alongside the new ones', () {
    test('checkout ruling and identification survive', () {
      final response = parse({
        'success': true,
        'card_no': '9911',
        'marked_for': 'Shakeel Ahmed',
        'is_final_checkout': true,
        'tracking_state': 'STOPPED',
        'posted_to_erp': true,
        'action': 'check_out',
      });
      expect(response.markedCardNo, '9911');
      expect(response.markedFor, 'Shakeel Ahmed');
      expect(response.isFinalCheckout, isTrue);
      expect(response.trackingState, 'STOPPED');
    });
  });
}
