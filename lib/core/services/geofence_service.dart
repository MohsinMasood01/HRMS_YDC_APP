import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../../features/geofence/domain/entities/geofence_status.dart';
import '../config/app_config.dart';
import 'location_service.dart';

// ignore_for_file: todo

/// Configuration for geofence monitoring behavior
class GeoFenceConfig {
  const GeoFenceConfig({
    this.monitoringIntervalSeconds = 20,
    this.maxAccuracyMeters = 30.0,
    this.minConsecutiveReadingsForEntry = 2,
    this.minConsecutiveReadingsForExit = 3,
    this.enableAntiSpoofing = true,
    this.enableBackgroundMonitoring = true,
  });

  /// Interval between location checks in seconds
  final int monitoringIntervalSeconds;

  /// Maximum acceptable GPS accuracy in meters
  /// Readings with worse accuracy are filtered out
  final double maxAccuracyMeters;

  /// Minimum consecutive readings inside geofence before marking entry
  final int minConsecutiveReadingsForEntry;

  /// Minimum consecutive readings outside geofence before marking exit
  final int minConsecutiveReadingsForExit;

  /// Whether to enable mock location detection
  final bool enableAntiSpoofing;

  /// Whether to enable background location monitoring
  final bool enableBackgroundMonitoring;
}

/// Result of a location validation check
class LocationValidationResult {
  const LocationValidationResult({
    required this.isValid,
    required this.quality,
    this.rejectionReason,
  });

  final bool isValid;
  final LocationQuality quality;
  final String? rejectionReason;

  factory LocationValidationResult.valid(LocationQuality quality) {
    return LocationValidationResult(isValid: true, quality: quality);
  }

  factory LocationValidationResult.invalid(String reason) {
    return LocationValidationResult(
      isValid: false,
      quality: LocationQuality.invalid,
      rejectionReason: reason,
    );
  }
}

/// Production-ready GeoFence Service for enterprise attendance tracking
///
/// Features:
/// - Periodic background-friendly monitoring
/// - GPS accuracy filtering
/// - Enter/Exit event detection with state management
/// - Anti-spoofing placeholders
/// - Offline queue structure
/// - Clean Architecture compatible
///
/// Usage:
/// ```dart
/// final service = GeoFenceService(appConfig, locationService);
/// await service.startMonitoring();
/// service.statusStream.listen((status) {
///   if (status.shouldMarkEntry) {
///     // Mark attendance
///   }
/// });
/// ```
class GeoFenceService {
  GeoFenceService(
    this._appConfig,
    this._locationService, {
    GeoFenceConfig? config,
  }) : _config = config ?? const GeoFenceConfig();

  final AppConfig _appConfig;
  final LocationService _locationService;
  final GeoFenceConfig _config;

  /// Stream controller for geofence status updates
  final _statusController = StreamController<GeoFenceStatus>.broadcast();

  /// Timer for periodic monitoring
  Timer? _monitoringTimer;

  /// Track if monitoring is active
  bool _isMonitoring = false;

  /// Previous status for state change detection
  GeoFenceStatus? _previousStatus;

  /// Count of consecutive readings with same state
  int _consecutiveInsideReadings = 0;
  int _consecutiveOutsideReadings = 0;

  /// Offline attendance queue for entries that couldn't be synced
  final List<OfflineAttendanceEntry> _offlineQueue = [];

  /// Stream of geofence status updates
  Stream<GeoFenceStatus> get statusStream => _statusController.stream;

  /// Whether monitoring is currently active
  bool get isMonitoring => _isMonitoring;

  /// Current geofence status
  GeoFenceStatus? get currentStatus => _previousStatus;

  /// Pending offline entries count
  int get offlineQueueCount => _offlineQueue.length;

  // ═══════════════════════════════════════════════════════════════════════════
  // MONITORING CONTROL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Start periodic geofence monitoring
  ///
  /// This will check the user's location at regular intervals and emit
  /// status updates through [statusStream].
  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      return; // Already monitoring
    }

    // Check permissions first
    final permissionResult = await _locationService
        .requestPermissionWithStatus();
    if (!permissionResult.granted) {
      _emitError(
        'Location permission not granted: ${permissionResult.message}',
      );
      return;
    }

    _isMonitoring = true;

    // Initial check
    await _performLocationCheck(isBackground: false);

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(
      Duration(seconds: _config.monitoringIntervalSeconds),
      (_) => _performLocationCheck(
        isBackground: _config.enableBackgroundMonitoring,
      ),
    );
  }

  /// Stop periodic geofence monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
  }

  /// Perform a single location check (manual refresh)
  Future<void> refreshStatus() async {
    await _performLocationCheck(isBackground: false);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CORE LOCATION CHECKING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Perform a single location check and update status
  Future<void> _performLocationCheck({required bool isBackground}) async {
    try {
      // Get current position
      final position = await _locationService.currentPosition();

      // Validate the location reading
      final validationResult = _validateLocation(position);

      if (!validationResult.isValid) {
        // Invalid reading - emit status but mark as poor quality
        _emitStatus(
          isInside: _previousStatus?.isInside ?? false,
          distanceMeters: _previousStatus?.distanceMeters ?? 0,
          position: position,
          quality: LocationQuality.invalid,
          isBackground: isBackground,
          errorMessage: validationResult.rejectionReason,
        );
        return;
      }

      // Calculate distance from geofence center
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _appConfig.defaultGeoLatitude,
        _appConfig.defaultGeoLongitude,
      );

      // Determine if inside geofence
      final isInside = distance <= _appConfig.geoFenceRadiusMeters;

      // Emit the validated status
      _emitStatus(
        isInside: isInside,
        distanceMeters: distance,
        position: position,
        quality: validationResult.quality,
        isBackground: isBackground,
      );
    } on LocationException catch (e) {
      _emitError(e.message);
    } catch (e) {
      _emitError('Failed to get location: $e');
    }
  }

  /// Emit a new geofence status with state change detection
  void _emitStatus({
    required bool isInside,
    required double distanceMeters,
    required Position position,
    required LocationQuality quality,
    required bool isBackground,
    String? errorMessage,
  }) {
    // Update consecutive reading counts
    if (isInside) {
      _consecutiveInsideReadings++;
      _consecutiveOutsideReadings = 0;
    } else {
      _consecutiveOutsideReadings++;
      _consecutiveInsideReadings = 0;
    }

    // Determine presence state change
    final presenceState = _determinePresenceState(isInside);

    // Check for mock location
    final isMockLocation = _checkMockLocation(position);

    // Build the status
    final status = GeoFenceStatus(
      isInside: isInside,
      distanceMeters: distanceMeters,
      lastUpdated: DateTime.now(),
      presenceState: presenceState,
      locationQuality: quality,
      accuracyMeters: position.accuracy,
      latitude: position.latitude,
      longitude: position.longitude,
      isMockLocation: isMockLocation,
      isFromBackground: isBackground,
      consecutiveReadings: isInside
          ? _consecutiveInsideReadings
          : _consecutiveOutsideReadings,
      errorMessage: errorMessage,
    );

    // Store as previous status
    _previousStatus = status;

    // Emit to stream
    _statusController.add(status);

    // Handle entry/exit events
    _handleStateChangeEvents(status);
  }

  /// Emit an error status
  void _emitError(String message) {
    final errorStatus = GeoFenceStatus.error(message);
    _statusController.add(errorStatus);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE CHANGE DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Determine the presence state based on current and previous readings
  GeoFencePresenceState _determinePresenceState(bool isCurrentlyInside) {
    final wasInside = _previousStatus?.isInside;

    // First reading
    if (wasInside == null) {
      return isCurrentlyInside
          ? GeoFencePresenceState.stillInside
          : GeoFencePresenceState.stillOutside;
    }

    // State changed: was outside, now inside
    if (!wasInside && isCurrentlyInside) {
      // Only emit "entered" if we have enough consecutive readings
      if (_consecutiveInsideReadings >=
          _config.minConsecutiveReadingsForEntry) {
        return GeoFencePresenceState.entered;
      }
      return GeoFencePresenceState.stillInside;
    }

    // State changed: was inside, now outside
    if (wasInside && !isCurrentlyInside) {
      // Only emit "exited" if we have enough consecutive readings
      if (_consecutiveOutsideReadings >=
          _config.minConsecutiveReadingsForExit) {
        return GeoFencePresenceState.exited;
      }
      return GeoFencePresenceState.stillOutside;
    }

    // No state change
    return isCurrentlyInside
        ? GeoFencePresenceState.stillInside
        : GeoFencePresenceState.stillOutside;
  }

  /// Handle state change events (entry/exit)
  void _handleStateChangeEvents(GeoFenceStatus status) {
    if (status.presenceState == GeoFencePresenceState.entered) {
      _onGeofenceEntered(status);
    } else if (status.presenceState == GeoFencePresenceState.exited) {
      _onGeofenceExited(status);
    }
  }

  /// Called when user enters the geofence
  void _onGeofenceEntered(GeoFenceStatus status) {
    // TODO: Integrate with attendance marking use case
    // This is where you would call the attendance repository
    // to mark automatic check-in

    // If offline, queue the entry
    if (!_isNetworkAvailable()) {
      _queueOfflineEntry(status, AttendanceType.checkIn);
    }
  }

  /// Called when user exits the geofence
  void _onGeofenceExited(GeoFenceStatus status) {
    // TODO: Integrate with attendance marking use case
    // This is where you would call the attendance repository
    // to mark automatic check-out

    // If offline, queue the entry
    if (!_isNetworkAvailable()) {
      _queueOfflineEntry(status, AttendanceType.checkOut);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION VALIDATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Validate a location reading for accuracy and potential spoofing
  LocationValidationResult _validateLocation(Position position) {
    // Check GPS accuracy
    if (position.accuracy > _config.maxAccuracyMeters) {
      return LocationValidationResult.invalid(
        'GPS accuracy too low: ${position.accuracy.toStringAsFixed(1)}m '
        '(max: ${_config.maxAccuracyMeters}m)',
      );
    }

    // Check for mock location (if enabled)
    if (_config.enableAntiSpoofing) {
      if (position.isMocked) {
        return LocationValidationResult.invalid('Mock location detected');
      }

      // TODO: Add additional anti-spoofing checks:
      // - Check if developer options are enabled
      // - Check for known mock location apps
      // - Check for unrealistic movement speeds
      // - Validate location against cell tower/WiFi triangulation
      // - Check for rooted/jailbroken device
    }

    // Determine quality rating
    LocationQuality quality;
    if (position.accuracy < 10) {
      quality = LocationQuality.high;
    } else if (position.accuracy <= 30) {
      quality = LocationQuality.good;
    } else {
      quality = LocationQuality.poor;
    }

    return LocationValidationResult.valid(quality);
  }

  /// Check if location appears to be mocked
  bool _checkMockLocation(Position position) {
    // Primary check: isMocked flag from Geolocator
    if (position.isMocked) {
      return true;
    }

    // TODO: Add additional mock location detection:
    // - Check for MockLocationApps
    // - Verify with multiple location sources
    // - Check for suspicious patterns (instant teleportation, etc.)

    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFLINE QUEUE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if network is available (placeholder)
  bool _isNetworkAvailable() {
    // TODO: Implement actual network connectivity check
    // Use connectivity_plus package or similar
    return true;
  }

  /// Queue an attendance entry for later sync
  void _queueOfflineEntry(GeoFenceStatus status, AttendanceType type) {
    final entry = OfflineAttendanceEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      timestamp: status.lastUpdated,
      latitude: status.latitude,
      longitude: status.longitude,
      distanceMeters: status.distanceMeters,
      accuracyMeters: status.accuracyMeters,
    );

    _offlineQueue.add(entry);

    // TODO: Persist to local storage using SharedPreferences or SQLite
    // so entries survive app restart
  }

  /// Get all pending offline entries
  List<OfflineAttendanceEntry> getOfflineQueue() {
    return List.unmodifiable(_offlineQueue);
  }

  /// Sync offline entries when network is available
  Future<void> syncOfflineEntries() async {
    if (_offlineQueue.isEmpty) return;

    final entriesToSync = List<OfflineAttendanceEntry>.from(_offlineQueue);

    for (final entry in entriesToSync) {
      try {
        // TODO: Call attendance repository to sync entry
        // await _attendanceRepository.syncOfflineEntry(entry);

        // Remove from queue on success
        _offlineQueue.remove(entry);
      } catch (e) {
        // Keep in queue for retry
        // TODO: Implement exponential backoff
      }
    }
  }

  /// Clear the offline queue (use with caution)
  void clearOfflineQueue() {
    _offlineQueue.clear();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANTI-SPOOFING UTILITIES (PLACEHOLDERS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if developer options are enabled
  ///
  /// TODO: Implement using platform channel or package
  Future<bool> isDeveloperModeEnabled() async {
    if (Platform.isAndroid) {
      // TODO: Check Settings.Global.DEVELOPMENT_SETTINGS_ENABLED
      // Use platform channel to check:
      // Settings.Secure.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0)
    }
    return false;
  }

  /// Check if device is rooted/jailbroken
  ///
  /// TODO: Implement using flutter_jailbreak_detection or similar
  Future<bool> isDeviceRooted() async {
    // TODO: Implement root/jailbreak detection
    // Consider using: flutter_jailbreak_detection, root_checker
    return false;
  }

  /// Check for mock location apps
  ///
  /// TODO: Implement by checking installed packages
  Future<List<String>> detectMockLocationApps() async {
    // TODO: Check for known mock location apps:
    // - Fake GPS location
    // - Mock GPS with Joystick
    // - Fake GPS Pro
    // etc.
    return [];
  }

  /// Validate location with cellular/WiFi triangulation
  ///
  /// TODO: Implement cross-validation
  Future<bool> validateWithAlternativeSources() async {
    // TODO: Compare GPS location with:
    // - Cell tower triangulation
    // - WiFi positioning
    // - IP-based geolocation
    return true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dispose of resources
  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING DATA CLASSES
// ═══════════════════════════════════════════════════════════════════════════

/// Type of attendance record
enum AttendanceType { checkIn, checkOut }

/// Represents an attendance entry queued for offline sync
class OfflineAttendanceEntry {
  const OfflineAttendanceEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.accuracyMeters,
    this.syncAttempts = 0,
    this.note,
  });

  final String id;
  final AttendanceType type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double accuracyMeters;
  final int syncAttempts;
  final String? note;

  OfflineAttendanceEntry copyWith({int? syncAttempts, String? note}) {
    return OfflineAttendanceEntry(
      id: id,
      type: type,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      accuracyMeters: accuracyMeters,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'accuracyMeters': accuracyMeters,
      'syncAttempts': syncAttempts,
      'note': note,
    };
  }

  factory OfflineAttendanceEntry.fromJson(Map<String, dynamic> json) {
    return OfflineAttendanceEntry(
      id: json['id'] as String,
      type: AttendanceType.values.firstWhere((e) => e.name == json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      distanceMeters: json['distanceMeters'] as double,
      accuracyMeters: json['accuracyMeters'] as double,
      syncAttempts: json['syncAttempts'] as int? ?? 0,
      note: json['note'] as String?,
    );
  }
}
