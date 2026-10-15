part of 'geofence_bloc.dart';

/// Base class for geofence events
abstract class GeoFenceEvent extends Equatable {
  const GeoFenceEvent();

  @override
  List<Object?> get props => [];
}

/// Start geofence monitoring
class GeoFenceStarted extends GeoFenceEvent {
  const GeoFenceStarted();
}

/// Stop geofence monitoring
class GeoFenceStopped extends GeoFenceEvent {
  const GeoFenceStopped();
}

/// Internal event for status updates from the service
class _GeoFenceStatusUpdated extends GeoFenceEvent {
  const _GeoFenceStatusUpdated(this.status);

  final GeoFenceStatus status;

  @override
  List<Object?> get props => [status];
}

/// Request to refresh the geofence status manually
class GeoFenceRefreshRequested extends GeoFenceEvent {
  const GeoFenceRefreshRequested();
}

/// Request a manual attendance override
class GeoFenceManualOverrideRequested extends GeoFenceEvent {
  const GeoFenceManualOverrideRequested({required this.note});

  final String note;

  @override
  List<Object?> get props => [note];
}

/// Request to sync offline attendance entries
class GeoFenceOfflineSyncRequested extends GeoFenceEvent {
  const GeoFenceOfflineSyncRequested();
}