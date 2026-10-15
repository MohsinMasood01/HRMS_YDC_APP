import 'package:equatable/equatable.dart';

/// Lifecycle of a location-tracking session.
///
/// The phone never *decides* that a checkout was final — the backend is
/// authoritative and reports it on the attendance response. These states only
/// record what the backend told us so scheduling survives app restarts.
enum TrackingState {
  /// No tracking session exists (no check-in yet, or the session was cleared).
  inactive('INACTIVE'),

  /// Location capture is scheduled and running.
  active('ACTIVE'),

  /// An intermediate checkout happened. No new points are generated, but the
  /// session is retained so a later check-in resumes it instead of opening a
  /// new one. Tracking is NOT permanently terminated.
  paused('PAUSED'),

  /// Final checkout. No further points may be generated for this session.
  stopped('STOPPED');

  const TrackingState(this.storageValue);

  final String storageValue;

  static TrackingState fromStorage(String? value) {
    for (final state in TrackingState.values) {
      if (state.storageValue == value) return state;
    }
    return TrackingState.inactive;
  }

  /// Whether the scheduler should be capturing GPS in this state.
  bool get shouldCapture => this == TrackingState.active;

  /// Whether a session still exists that a later check-in can resume.
  bool get isResumable =>
      this == TrackingState.active || this == TrackingState.paused;
}

/// What the backend told us to do with tracking on an attendance response.
///
/// BACKEND CONTRACT: parsed from `tracking_state` on the attendance response.
/// When the backend omits it we fall back to [is_final_checkout].
enum BackendTrackingDirective {
  active('ACTIVE'),
  paused('PAUSED'),
  stopped('STOPPED');

  const BackendTrackingDirective(this.wireValue);

  final String wireValue;

  static BackendTrackingDirective? fromWire(String? value) {
    final normalised = value?.trim().toUpperCase();
    if (normalised == null || normalised.isEmpty) return null;
    for (final directive in BackendTrackingDirective.values) {
      if (directive.wireValue == normalised) return directive;
    }
    return null;
  }
}

/// A persisted tracking session, scoped to one employee and one attendance day.
class TrackingSession extends Equatable {
  const TrackingSession({
    required this.cardNo,
    required this.attendanceDate,
    required this.state,
    required this.intervalMinutes,
    required this.startedAt,
    this.endedAt,
    this.cutoffAt,
  });

  /// Longest a session may run when the backend did not supply [cutoffAt].
  ///
  /// A stopgap, not the rule: the backend computes the real cutoff (shift end
  /// + grace). This only guarantees that a session can never stay open
  /// indefinitely -- the original bug, where an employee who never checked
  /// out kept being tracked for days. 18h covers the longest configured shift
  /// (16h15m duty) plus margin, and still ends long before the next day's
  /// equivalent shift.
  static const Duration fallbackMaxDuration = Duration(hours: 18);

  /// Employee being tracked. Every point captured in this session carries this
  /// card number, even if a different employee later logs into the phone.
  final String cardNo;

  /// Attendance day (yyyy-MM-dd) that opened the session.
  final String attendanceDate;

  final TrackingState state;

  /// HR-configured capture interval, resolved from the backend. Never a
  /// hardcoded default at this layer.
  final int intervalMinutes;

  final DateTime startedAt;
  final DateTime? endedAt;

  /// Absolute instant (UTC) after which this session may record nothing --
  /// the shift's end plus its grace period, as computed by the backend.
  ///
  /// Null when the backend did not send one; [effectiveCutoffAt] then falls
  /// back to [fallbackMaxDuration] after [startedAt]. Checkout ends a session
  /// earlier still: it moves the session out of ACTIVE, which stops capture
  /// immediately regardless of the cutoff.
  final DateTime? cutoffAt;

  bool get isActive => state == TrackingState.active;

  /// The instant this session stops accepting fixes, always defined.
  DateTime get effectiveCutoffAt =>
      (cutoffAt ?? startedAt.add(fallbackMaxDuration)).toUtc();

  /// Whether the session has run past its cutoff at [now].
  ///
  /// Inclusive: a session is expired AT its cutoff instant, so a fix stamped
  /// exactly at the cutoff is still accepted by [acceptsFixAt] while nothing
  /// is scheduled after it.
  bool isExpiredAt(DateTime now) =>
      !now.toUtc().isBefore(effectiveCutoffAt);

  /// Whether a fix taken at [recordedAt] falls on or before the cutoff.
  ///
  /// Judged by the fix's own timestamp, not by when it is processed: a fix
  /// recorded at 18:59 and delivered at 19:30 (app was asleep) still belongs
  /// to a session that closed at 19:00, and one recorded at 19:01 never does.
  bool acceptsFixAt(DateTime recordedAt) =>
      !recordedAt.toUtc().isAfter(effectiveCutoffAt);

  TrackingSession copyWith({
    TrackingState? state,
    int? intervalMinutes,
    DateTime? endedAt,
    DateTime? cutoffAt,
  }) {
    return TrackingSession(
      cardNo: cardNo,
      attendanceDate: attendanceDate,
      state: state ?? this.state,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      cutoffAt: cutoffAt ?? this.cutoffAt,
    );
  }

  @override
  List<Object?> get props => [
    cardNo,
    attendanceDate,
    state,
    intervalMinutes,
    startedAt,
    endedAt,
    cutoffAt,
  ];
}
