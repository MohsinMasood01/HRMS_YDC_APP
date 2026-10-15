import 'package:flutter_test/flutter_test.dart';
import 'package:lms/core/services/location_tracking_service.dart';
import 'package:lms/core/services/tracelet_service.dart';
import 'package:tracelet/tracelet.dart'
    show AndroidConfig, Config, GeoConfig, MotionConfig, TrackingMode;

void main() {
  group('capture interval resolution', () {
    test('no test override ships: every card follows the panel', () {
      // Guards against a test interval leaking into an employee build.
      expect(LocationTrackingService.testIntervalOverrideMinutes, isEmpty);
    });

    test('100002.1 follows its panel setting of 1 hour again', () {
      expect(
        LocationTrackingService.resolveIntervalMinutes(
          cardNo: '100002.1',
          fromServer: 60,
        ),
        60,
      );
    });

    test('offline, the last known panel interval is kept', () {
      expect(
        LocationTrackingService.resolveIntervalMinutes(
          cardNo: '100002.1',
          cached: 60,
        ),
        60,
      );
    });

    test('everyone else keeps HR\'s interval', () {
      expect(
        LocationTrackingService.resolveIntervalMinutes(
          cardNo: '100660.1',
          fromServer: 60,
        ),
        60,
      );
    });

    test('HR intervals keep the 15-minute WorkManager floor', () {
      expect(
        LocationTrackingService.resolveIntervalMinutes(
          cardNo: '100660.1',
          fromServer: 5,
        ),
        15,
      );
    });

    test('no server value and no cache falls back to hourly', () {
      expect(
        LocationTrackingService.resolveIntervalMinutes(cardNo: '100660.1'),
        60,
      );
    });
  });

  group('restart only when the running schedule is wrong', () {
    bool same({
      bool enabled = true,
      TrackingMode mode = TrackingMode.periodic,
      Config? config,
      int wanted = 10,
    }) {
      return TraceletService.isSameSchedule(
        enabled: enabled,
        trackingMode: mode,
        config: config,
        intervalMinutes: wanted,
      );
    }

    test('the exact 10-minute foreground schedule is left running', () {
      expect(same(config: TraceletService.intervalConfig(10)), isTrue);
    });

    test('a different interval is replaced', () {
      expect(same(config: TraceletService.intervalConfig(15)), isFalse);
    });

    test('a WorkManager schedule from an older build is replaced', () {
      // Phones upgrading from the WorkManager build must move onto the
      // foreground-service timer the next time the app opens.
      const oldBuild = Config(
        geo: GeoConfig(periodicLocationInterval: 600),
        android: AndroidConfig(periodicUseForegroundService: false),
      );
      expect(same(config: oldBuild), isFalse);
    });

    test('a running engine on the 2-minute stationary default is replaced', () {
      final wrongStationary = Config(
        geo: const GeoConfig(periodicLocationInterval: 600),
        motion: const MotionConfig(stationaryPeriodicInterval: 120),
        android: const AndroidConfig(periodicUseForegroundService: true),
      );
      expect(same(config: wrongStationary), isFalse);
    });

    test('a stopped engine or another mode is (re)started', () {
      final config = TraceletService.intervalConfig(10);
      expect(same(enabled: false, config: config), isFalse);
      expect(same(mode: TrackingMode.location, config: config), isFalse);
    });

    test('no config reported counts as not running', () {
      expect(same(config: null), isFalse);
    });
  });

  group('scheduler selection', () {
    test('every interval runs on the foreground-service timer', () {
      // WorkManager-only capture never ran on Xiaomi phones after check-in;
      // the foreground service is what keeps hourly tracking alive there.
      for (final minutes in [10, 15, 60, 120]) {
        final config = TraceletService.intervalConfig(minutes);
        expect(config.geo.periodicLocationInterval, minutes * 60);
        expect(config.android.periodicUseForegroundService, isTrue,
            reason: '$minutes-minute interval must use the foreground service');
      }
    });

    test('the stationary cadence matches the interval, not its 2-min default',
        () {
      // A phone sitting still recorded every 2 minutes because Tracelet's
      // stationaryPeriodicInterval defaults to 120s and overrode the hourly
      // setting.
      for (final minutes in [60, 120]) {
        final config = TraceletService.intervalConfig(minutes);
        expect(config.motion.stationaryPeriodicInterval, minutes * 60,
            reason: 'stationary cadence must follow the $minutes-minute setting');
      }
      expect(TraceletService.intervalConfig(60).motion.stationaryPeriodicInterval,
          isNot(120));
    });
  });
}
