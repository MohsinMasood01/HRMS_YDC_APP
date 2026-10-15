part of 'geofence_bloc.dart';

/// State for the geofence bloc
class GeoFenceState extends Equatable {
  const GeoFenceState({
    this.status,
    this.lastMessage,
    this.isSubmitting = false,
    this.isMonitoring = false,
  });

  /// Current geofence status
  final GeoFenceStatus? status;
  
  /// Last message/notification to show user
  final String? lastMessage;
  
  /// Whether an async operation is in progress
  final bool isSubmitting;
  
  /// Whether geofence monitoring is active
  final bool isMonitoring;

  /// Whether user is currently inside the geofence
  bool get isInsideGeofence => status?.isInside ?? false;

  /// Whether the location reading is valid for attendance
  bool get hasValidLocation => status?.isValidForAttendance ?? false;

  /// Current distance from geofence center
  double get distanceMeters => status?.distanceMeters ?? 0;

  /// Current GPS accuracy
  double get accuracyMeters => status?.accuracyMeters ?? 0;

  /// Whether mock location was detected
  bool get isMockLocationDetected => status?.isMockLocation ?? false;

  /// Presence state description
  String get presenceStateDescription {
    if (status == null) return 'Unknown';
    switch (status!.presenceState) {
      case GeoFencePresenceState.entered:
        return 'Just Entered';
      case GeoFencePresenceState.exited:
        return 'Just Exited';
      case GeoFencePresenceState.stillInside:
        return 'Inside Zone';
      case GeoFencePresenceState.stillOutside:
        return 'Outside Zone';
      case GeoFencePresenceState.unknown:
        return 'Determining...';
    }
  }

  /// Location quality description
  String get qualityDescription {
    if (status == null) return 'Unknown';
    switch (status!.locationQuality) {
      case LocationQuality.high:
        return 'Excellent';
      case LocationQuality.good:
        return 'Good';
      case LocationQuality.poor:
        return 'Poor';
      case LocationQuality.invalid:
        return 'Invalid';
    }
  }

  GeoFenceState copyWith({
    GeoFenceStatus? status,
    String? lastMessage,
    bool? isSubmitting,
    bool? isMonitoring,
  }) {
    return GeoFenceState(
      status: status ?? this.status,
      lastMessage: lastMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isMonitoring: isMonitoring ?? this.isMonitoring,
    );
  }

  @override
  List<Object?> get props => [
        status,
        lastMessage,
        isSubmitting,
        isMonitoring,
      ];
}
