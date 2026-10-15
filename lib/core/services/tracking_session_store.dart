import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/location_tracking/domain/entities/tracking_session.dart';

/// Persists the tracking state machine.
///
/// Backed by SharedPreferences because the WorkManager background isolate
/// must read it without going through the service locator. It is the single
/// source of truth for "should this device be capturing right now", so the
/// scheduler, the notification and the background worker cannot disagree.
///
/// Replaces the pre-existing `lms_is_tracking` / `lms_tracking_card_no` /
/// `lms_tracking_interval_hours` trio, which encoded only a boolean and could
/// not express the difference between an intermediate and a final checkout.
class TrackingSessionStore {
  static const String _keyState = 'lms_tracking_state';
  static const String _keyCardNo = 'lms_tracking_card_no';
  static const String _keyAttendanceDate = 'lms_tracking_attendance_date';
  static const String _keyIntervalMinutes = 'lms_tracking_interval_minutes';
  static const String _keyStartedAt = 'lms_tracking_started_at';
  static const String _keyEndedAt = 'lms_tracking_ended_at';
  static const String _keyCutoffAt = 'lms_tracking_cutoff_at';

  /// Legacy keys, read once during [migrateLegacyKeysIfNeeded].
  static const String _legacyIsTracking = 'lms_is_tracking';
  static const String _legacyIntervalHours = 'lms_tracking_interval_hours';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Reads the current session, or null when none exists.
  Future<TrackingSession?> read() async {
    final prefs = await _prefs;
    // Re-read from disk: the background isolate holds its own cached copy.
    await prefs.reload();
    return _readFrom(prefs);
  }

  TrackingSession? _readFrom(SharedPreferences prefs) {
    final cardNo = prefs.getString(_keyCardNo) ?? '';
    final stateValue = prefs.getString(_keyState);
    if (cardNo.isEmpty || stateValue == null) return null;

    final state = TrackingState.fromStorage(stateValue);
    if (state == TrackingState.inactive) return null;

    return TrackingSession(
      cardNo: cardNo,
      attendanceDate: prefs.getString(_keyAttendanceDate) ?? '',
      state: state,
      intervalMinutes: prefs.getInt(_keyIntervalMinutes) ?? 0,
      startedAt:
          DateTime.tryParse(prefs.getString(_keyStartedAt) ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      endedAt: DateTime.tryParse(prefs.getString(_keyEndedAt) ?? '')?.toUtc(),
      // Absent for sessions persisted before cutoffs existed; those fall back
      // to TrackingSession.fallbackMaxDuration, which is what finally closes
      // a session left open for days by an older build.
      cutoffAt: DateTime.tryParse(
        prefs.getString(_keyCutoffAt) ?? '',
      )?.toUtc(),
    );
  }

  Future<void> save(TrackingSession session) async {
    final prefs = await _prefs;
    await prefs.setString(_keyState, session.state.storageValue);
    await prefs.setString(_keyCardNo, session.cardNo);
    await prefs.setString(_keyAttendanceDate, session.attendanceDate);
    await prefs.setInt(_keyIntervalMinutes, session.intervalMinutes);
    await prefs.setString(
      _keyStartedAt,
      session.startedAt.toUtc().toIso8601String(),
    );
    if (session.endedAt != null) {
      await prefs.setString(
        _keyEndedAt,
        session.endedAt!.toUtc().toIso8601String(),
      );
    } else {
      await prefs.remove(_keyEndedAt);
    }
    if (session.cutoffAt != null) {
      await prefs.setString(
        _keyCutoffAt,
        session.cutoffAt!.toUtc().toIso8601String(),
      );
    } else {
      await prefs.remove(_keyCutoffAt);
    }
    debugPrint(
      '[TrackingSession] ${session.cardNo} -> ${session.state.storageValue} '
      '(every ${session.intervalMinutes}m, day ${session.attendanceDate}, '
      'cutoff ${session.effectiveCutoffAt.toIso8601String()}'
      '${session.cutoffAt == null ? " [fallback]" : ""})',
    );
  }

  /// Moves the current session to [state], keeping its identity intact.
  ///
  /// [endedAt] overrides the recorded end time of a STOPPED session -- an
  /// expired session ended at its cutoff, not at whenever the app noticed.
  ///
  /// Returns null when there is no session to transition.
  Future<TrackingSession?> transitionTo(
    TrackingState state, {
    DateTime? endedAt,
  }) async {
    final current = await read();
    if (current == null) return null;

    final updated = current.copyWith(
      state: state,
      endedAt: state == TrackingState.stopped
          ? (endedAt ?? DateTime.now()).toUtc()
          : null,
    );
    await save(updated);
    return updated;
  }

  /// Closes the session if it has run past its cutoff.
  ///
  /// This is what stops a forgotten checkout from being tracked into the
  /// following day(s). Safe to call from any isolate, repeatedly: only an
  /// ACTIVE or PAUSED session past its cutoff is transitioned, to STOPPED with
  /// `endedAt` set to the cutoff itself.
  ///
  /// Returns the session as it was *before* expiry (still ACTIVE/PAUSED, so
  /// the caller can flush fixes taken before the cutoff), or null when
  /// nothing expired.
  Future<TrackingSession?> expireIfDue({DateTime? now}) async {
    final session = await read();
    if (session == null || !session.state.isResumable) return null;
    if (!session.isExpiredAt(now ?? DateTime.now())) return null;

    await transitionTo(
      TrackingState.stopped,
      endedAt: session.effectiveCutoffAt,
    );
    debugPrint(
      '[TrackingSession] ${session.cardNo} expired at cutoff '
      '${session.effectiveCutoffAt.toIso8601String()} (no checkout)',
    );
    return session;
  }

  /// Clears the session entirely (back to INACTIVE).
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_keyState);
    await prefs.remove(_keyCardNo);
    await prefs.remove(_keyAttendanceDate);
    await prefs.remove(_keyIntervalMinutes);
    await prefs.remove(_keyStartedAt);
    await prefs.remove(_keyEndedAt);
    await prefs.remove(_keyCutoffAt);
  }

  /// Fast path for the background worker: may it capture right now?
  ///
  /// Returns the session only when it is ACTIVE and not past its cutoff.
  /// PAUSED, STOPPED and expired all yield null, so no points are generated
  /// after a checkout, or after the shift's cutoff when checkout never came.
  /// Callers that should also *close* an expired session use [expireIfDue].
  Future<TrackingSession?> activeSession({DateTime? now}) async {
    final session = await read();
    if (session == null || !session.state.shouldCapture) return null;
    if (session.cardNo.isEmpty) return null;
    if (session.isExpiredAt(now ?? DateTime.now())) return null;
    return session;
  }

  /// One-time upgrade from the pre-existing boolean keys.
  ///
  /// An older build that was mid-session when the app updated had
  /// `lms_is_tracking = true` and an hours-based interval. That is promoted
  /// to an ACTIVE session so tracking is not silently lost across the update.
  Future<void> migrateLegacyKeysIfNeeded() async {
    final prefs = await _prefs;
    await prefs.reload();

    // Already migrated (or a fresh install): nothing to do.
    if (prefs.getString(_keyState) != null) return;

    final wasTracking = prefs.getBool(_legacyIsTracking) ?? false;
    final cardNo = prefs.getString(_keyCardNo) ?? '';
    if (!wasTracking || cardNo.isEmpty) {
      await prefs.remove(_legacyIsTracking);
      await prefs.remove(_legacyIntervalHours);
      return;
    }

    final legacyHours = prefs.getInt(_legacyIntervalHours) ?? 0;
    final now = DateTime.now();

    await save(
      TrackingSession(
        cardNo: cardNo,
        attendanceDate: _formatDay(now),
        state: TrackingState.active,
        // Hours in the old schema; 0 means "unknown, re-fetch from backend".
        intervalMinutes: legacyHours > 0 ? legacyHours * 60 : 0,
        startedAt: now.toUtc(),
      ),
    );

    await prefs.remove(_legacyIsTracking);
    await prefs.remove(_legacyIntervalHours);
    debugPrint('[TrackingSession] Migrated legacy tracking flags for $cardNo');
  }

  static String _formatDay(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
