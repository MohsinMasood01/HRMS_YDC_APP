import 'package:equatable/equatable.dart';

/// Represents the different states of geofence presence
enum GeoFencePresenceState {
  /// User just entered the geofence zone
  entered,
  
  /// User just exited the geofence zone
  exited,
  
  /// User is still inside the geofence zone (no change)
  stillInside,
  
  /// User is still outside the geofence zone (no change)
  stillOutside,
  
  /// Initial state, location not yet determined
  unknown,
}

/// Represents the quality of the location reading
enum LocationQuality {
  /// High quality reading (accuracy < 10m)
  high,
  
  /// Good quality reading (accuracy 10-30m)
  good,
  
  /// Poor quality reading (accuracy > 30m)
  poor,
  
  /// Location reading is invalid or unavailable
  invalid,
}

/// Comprehensive geofence status for enterprise attendance tracking
/// 
/// This entity contains all information needed for:
/// - Determining if user is inside/outside geofence
/// - Tracking state transitions (enter/exit events)
/// - Validating location quality
/// - Detecting potential spoofing attempts
class GeoFenceStatus extends Equatable {
  const GeoFenceStatus({
    required this.isInside,
    required this.distanceMeters,
    required this.lastUpdated,
    this.presenceState = GeoFencePresenceState.unknown,
    this.locationQuality = LocationQuality.invalid,
    this.accuracyMeters = 0,
    this.latitude = 0,
    this.longitude = 0,
    this.isMockLocation = false,
    this.isFromBackground = false,
    this.consecutiveReadings = 0,
    this.errorMessage,
  });

  /// Whether the user is currently inside the geofence boundary
  final bool isInside;

  /// Distance from the geofence center in meters
  final double distanceMeters;

  /// Timestamp of the last location update
  final DateTime lastUpdated;

  /// Current presence state (entered, exited, still inside, still outside)
  final GeoFencePresenceState presenceState;

  /// Quality rating of the location reading
  final LocationQuality locationQuality;

  /// GPS accuracy in meters
  final double accuracyMeters;

  /// Current latitude
  final double latitude;

  /// Current longitude
  final double longitude;

  /// Whether this location appears to be mocked/spoofed
  final bool isMockLocation;

  /// Whether this reading was obtained in background mode
  final bool isFromBackground;

  /// Number of consecutive readings with same inside/outside state
  /// Used to confirm stable position before marking attendance
  final int consecutiveReadings;

  /// Error message if location fetch failed
  final String? errorMessage;

  /// Whether the location is valid for attendance marking
  bool get isValidForAttendance =>
      !isMockLocation &&
      locationQuality != LocationQuality.invalid &&
      locationQuality != LocationQuality.poor &&
      consecutiveReadings >= 2;

  /// Whether this is an entry event that should trigger attendance marking
  bool get shouldMarkEntry =>
      presenceState == GeoFencePresenceState.entered && isValidForAttendance;

  /// Whether this is an exit event
  bool get isExitEvent => presenceState == GeoFencePresenceState.exited;

  /// Whether the status has an error
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  /// Create a copy with updated fields
  GeoFenceStatus copyWith({
    bool? isInside,
    double? distanceMeters,
    DateTime? lastUpdated,
    GeoFencePresenceState? presenceState,
    LocationQuality? locationQuality,
    double? accuracyMeters,
    double? latitude,
    double? longitude,
    bool? isMockLocation,
    bool? isFromBackground,
    int? consecutiveReadings,
    String? errorMessage,
  }) {
    return GeoFenceStatus(
      isInside: isInside ?? this.isInside,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      presenceState: presenceState ?? this.presenceState,
      locationQuality: locationQuality ?? this.locationQuality,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isMockLocation: isMockLocation ?? this.isMockLocation,
      isFromBackground: isFromBackground ?? this.isFromBackground,
      consecutiveReadings: consecutiveReadings ?? this.consecutiveReadings,
      errorMessage: errorMessage,
    );
  }

  /// Create an error status
  factory GeoFenceStatus.error(String message) {
    return GeoFenceStatus(
      isInside: false,
      distanceMeters: 0,
      lastUpdated: DateTime.now(),
      presenceState: GeoFencePresenceState.unknown,
      errorMessage: message,
    );
  }

  /// Create an unknown/initial status
  factory GeoFenceStatus.unknown() {
    return GeoFenceStatus(
      isInside: false,
      distanceMeters: 0,
      lastUpdated: DateTime.now(),
      presenceState: GeoFencePresenceState.unknown,
    );
  }

  @override
  List<Object?> get props => [
        isInside,
        distanceMeters,
        lastUpdated,
        presenceState,
        locationQuality,
        accuracyMeters,
        latitude,
        longitude,
        isMockLocation,
        isFromBackground,
        consecutiveReadings,
        errorMessage,
      ];

  @override
  String toString() {
    return 'GeoFenceStatus('
        'isInside: $isInside, '
        'distance: ${distanceMeters.toStringAsFixed(1)}m, '
        'state: ${presenceState.name}, '
        'quality: ${locationQuality.name}, '
        'accuracy: ${accuracyMeters.toStringAsFixed(1)}m, '
        'mock: $isMockLocation, '
        'consecutive: $consecutiveReadings)';
  }
}
