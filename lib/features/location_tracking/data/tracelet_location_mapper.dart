import '../domain/entities/location_point.dart';
import '../domain/entities/tracking_session.dart';

/// Converts one location recorded by the Tracelet engine into a
/// [LocationPoint] for the local sync queue.
///
/// Tracelet only *captures*; delivery goes through the local queue and
/// `LocationRepository.syncPending`, which uploads per card number to the
/// backend's `/auth/location/batch`. Attribution is decided here, at capture
/// time, from the tracking session -- never from whoever is logged in when
/// the upload eventually happens.
///
/// Returns null when the fix must not be queued:
///  * there is no ACTIVE session (paused or stopped tracking records nothing),
///  * the fix predates the session (a leftover from an earlier session, which
///    must not be attributed to this employee),
///  * the fix was taken after the session's cutoff (shift end + grace), so an
///    employee who never checked out is not tracked into the next day,
///  * the coordinates cannot be real.
///
/// Every capture path -- foreground listener, headless isolate, startup
/// backfill, the one-off check-in/checkout fix -- goes through here, which is
/// why the cutoff is enforced here rather than at each caller.
///
/// [locationMap] is the `Location.toMap()` shape Tracelet delivers to
/// `onLocation`, to headless `location` events and from `getLocations()`.
LocationPoint? locationPointFromTracelet(
  Map<String, Object?> locationMap, {
  required TrackingSession? session,
  required String localId,
  DateTime? now,
}) {
  if (session == null || session.state != TrackingState.active) return null;
  if (session.cardNo.isEmpty) return null;

  final coords = locationMap['coords'];
  if (coords is! Map) return null;

  final latitude = _asDouble(coords['latitude']);
  final longitude = _asDouble(coords['longitude']);
  if (latitude == null || longitude == null) return null;
  if (!_isPlausible(latitude, longitude)) return null;

  final recordedAt = _parseUtc(locationMap['timestamp']);
  if (recordedAt == null) return null;

  // Allow a small skew so the first fix taken around check-in is kept.
  final sessionStart = session.startedAt.toUtc().subtract(
    const Duration(minutes: 2),
  );
  if (recordedAt.isBefore(sessionStart)) return null;

  // Judged by the fix's own timestamp: a fix taken before the cutoff but
  // delivered after it (app asleep, backfill) is still kept; one taken after
  // it never is, however it arrives.
  if (!session.acceptsFixAt(recordedAt)) return null;

  // The idempotency key is derived from the physical fix (capture time +
  // coordinates), NOT Tracelet's uuid. Seen on a real device: when the engine
  // is reconfigured (e.g. the interval changes) Tracelet re-emits the last
  // fix -- same timestamp, same coordinates -- under a brand-new uuid, which
  // a uuid key would upload twice. The same fix arriving through both the
  // foreground listener and the headless isolate also collapses to one row.
  final clientEventId =
      'tl-${recordedAt.millisecondsSinceEpoch}-$latitude-$longitude';

  final accuracy = _asDouble(coords['accuracy']);

  return LocationPoint(
    localId: localId,
    clientEventId: clientEventId,
    cardNo: session.cardNo,
    latitude: latitude,
    longitude: longitude,
    // Negative accuracy is the platform's "unknown"; keep it unknown.
    accuracy: (accuracy != null && accuracy >= 0) ? accuracy : null,
    recordedAt: recordedAt,
    attendanceDate: session.attendanceDate,
    createdAt: (now ?? DateTime.now()).toUtc(),
  );
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}

bool _isPlausible(double latitude, double longitude) {
  if (latitude.isNaN || longitude.isNaN) return false;
  if (latitude.abs() > 90 || longitude.abs() > 180) return false;
  // Exact null island is the classic "no fix" sentinel.
  return !(latitude == 0 && longitude == 0);
}

DateTime? _parseUtc(Object? value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}
