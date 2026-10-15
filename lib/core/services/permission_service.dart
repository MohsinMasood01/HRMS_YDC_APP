import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions
///
/// This service handles:
/// - Checking permission status
/// - Requesting permissions
/// - Showing rationale dialogs
class PermissionService {
  /// Request all required app permissions
  Future<PermissionResults> requestAllPermissions() async {
    final results = PermissionResults();

    // Request location permission
    results.location = await _requestLocationPermission();

    // Request notification permission (Android 13+)
    results.notification = await _requestNotificationPermission();

    return results;
  }

  /// Request location permission
  Future<PermissionStatus> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }
    
    return status;
  }

  /// Request notification permission (Android 13+)
  Future<PermissionStatus> _requestNotificationPermission() async {
    var status = await Permission.notification.status;
    
    if (status.isDenied) {
      status = await Permission.notification.request();
    }
    
    return status;
  }

  /// Check if location permission is granted
  Future<bool> isLocationGranted() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  /// Check if notification permission is granted
  Future<bool> isNotificationGranted() async {
    return await Permission.notification.isGranted;
  }

  /// Open app settings
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  // ---------------------------------------------------------------------
  // Background location
  // ---------------------------------------------------------------------
  //
  // Scheduled location tracking runs while the app is minimised, locked or
  // killed. On Android 10+ that needs ACCESS_BACKGROUND_LOCATION ("Allow all
  // the time"), which is separate from the while-in-use grant. On Android 11+
  // the system refuses to show a dialog for it at all -- the user must switch
  // it on in app settings -- so the app has to detect that and guide them.

  /// Whether "Allow all the time" location is granted.
  Future<bool> isBackgroundLocationGranted() async {
    return Permission.locationAlways.isGranted;
  }

  /// Requests background location, escalating from while-in-use.
  ///
  /// Returns what actually happened so the caller can decide whether to show
  /// guidance rather than silently continuing with a grant that will not
  /// deliver background fixes.
  Future<BackgroundLocationResult> requestBackgroundLocation() async {
    // Android requires the foreground grant before the background one can
    // even be asked for.
    var whenInUse = await Permission.locationWhenInUse.status;
    if (!whenInUse.isGranted) {
      whenInUse = await Permission.locationWhenInUse.request();
    }
    if (!whenInUse.isGranted) {
      return BackgroundLocationResult.foregroundDenied;
    }

    final always = await Permission.locationAlways.status;
    if (always.isGranted) return BackgroundLocationResult.granted;

    // On Android 11+ this typically resolves to denied without any dialog.
    final requested = await Permission.locationAlways.request();
    if (requested.isGranted) return BackgroundLocationResult.granted;

    return requested.isPermanentlyDenied
        ? BackgroundLocationResult.permanentlyDenied
        : BackgroundLocationResult.needsSettings;
  }

  /// Show permission rationale dialog
  static Future<bool> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String settingsButtonText,
    String cancelButtonText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelButtonText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(settingsButtonText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Results of permission requests
class PermissionResults {
  PermissionStatus location = PermissionStatus.denied;
  PermissionStatus notification = PermissionStatus.denied;

  bool get allGranted =>
      location.isGranted && notification.isGranted;

  bool get locationGranted => location.isGranted;
  bool get notificationGranted => notification.isGranted;
}

/// Outcome of a background-location request.
enum BackgroundLocationResult {
  /// "Allow all the time" is granted -- scheduled tracking will work.
  granted,

  /// Basic location was refused, so background cannot even be requested.
  foregroundDenied,

  /// Only while-in-use is granted. Android will not prompt for the upgrade;
  /// the user has to enable it in app settings.
  needsSettings,

  /// The user blocked it permanently. Only app settings can undo this.
  permanentlyDenied;

  /// Whether scheduled background capture can actually be relied upon.
  bool get isUsable => this == BackgroundLocationResult.granted;
}
