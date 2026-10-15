import 'package:geolocator/geolocator.dart';

/// Service for handling location-related functionality
/// 
/// This service handles:
/// - Checking and requesting location permissions
/// - Getting the current position
/// - Location service status checks
class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission from the user
  /// Returns true if permission is granted (always or whileInUse)
  Future<bool> ensurePermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, prompt user to enable
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permission permanently denied, guide user to settings
      return false;
    }
    
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  /// Request permission and open settings if needed
  Future<PermissionResult> requestPermissionWithStatus() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return PermissionResult(
        granted: false,
        status: PermissionStatus.serviceDisabled,
        message: 'Location services are disabled. Please enable location services in your device settings.',
      );
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return PermissionResult(
          granted: false,
          status: PermissionStatus.denied,
          message: 'Location permission was denied. Please grant location access to use this feature.',
        );
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return PermissionResult(
        granted: false,
        status: PermissionStatus.deniedForever,
        message: 'Location permission is permanently denied. Please enable it in app settings.',
      );
    }

    return PermissionResult(
      granted: true,
      status: PermissionStatus.granted,
      message: 'Location permission granted.',
    );
  }

  /// Open location settings on the device
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings to allow user to grant permissions
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Get the current position
  /// Throws exception if permission is not granted
  Future<Position> currentPosition() async {
    final permissionResult = await requestPermissionWithStatus();
    
    if (!permissionResult.granted) {
      throw LocationException(permissionResult.message);
    }
    
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Get current position with timeout
  Future<Position> currentPositionWithTimeout({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final permissionResult = await requestPermissionWithStatus();
    
    if (!permissionResult.granted) {
      throw LocationException(permissionResult.message);
    }
    
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(timeout);
  }
}

/// Result of permission request
class PermissionResult {
  final bool granted;
  final PermissionStatus status;
  final String message;

  PermissionResult({
    required this.granted,
    required this.status,
    required this.message,
  });
}

/// Status of location permission
enum PermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Exception for location-related errors
class LocationException implements Exception {
  final String message;

  LocationException(this.message);

  @override
  String toString() => 'LocationException: $message';
}
