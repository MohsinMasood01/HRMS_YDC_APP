import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service for handling biometric authentication
/// 
/// This service handles:
/// - Checking biometric availability
/// - Getting available biometric types
/// - Authenticating with biometrics
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if the device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Check if biometrics can be used (device supports it AND user has enrolled)
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isDeviceSupported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  /// Get the list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if fingerprint is available
  Future<bool> isFingerprintAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// Check if face ID is available
  Future<bool> isFaceIdAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Authenticate with biometrics
  /// Returns true if authentication is successful
  Future<BiometricResult> authenticate({
    String reason = 'Please authenticate to continue',
    bool biometricOnly = false,
  }) async {
    try {
      // Only bail out when the device has no secure lock at all. When a lock
      // exists but nothing is enrolled, let the platform prompt run so it can
      // report NotEnrolled with actionable guidance.
      final isAvailable =
          await isBiometricAvailable() || await isDeviceSupported();
      if (!isAvailable) {
        return BiometricResult(
          success: false,
          error: BiometricError.notAvailable,
          message: 'Biometric authentication is not available on this device.',
        );
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        return BiometricResult(
          success: true,
          error: null,
          message: 'Authentication successful',
        );
      } else {
        return BiometricResult(
          success: false,
          error: BiometricError.failed,
          message: 'Authentication failed. Please try again.',
        );
      }
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    }
  }

  /// Handle platform exceptions from local_auth
  BiometricResult _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return BiometricResult(
          success: false,
          error: BiometricError.notAvailable,
          message: 'Biometric authentication is not available.',
        );
      case 'NotEnrolled':
        return BiometricResult(
          success: false,
          error: BiometricError.notEnrolled,
          message: 'You have to link your fingerprint or Face ID first. '
              'Please set it up in your device settings, then try again.',
        );
      case 'LockedOut':
        return BiometricResult(
          success: false,
          error: BiometricError.lockedOut,
          message: 'Too many failed attempts. Please try again later.',
        );
      case 'PermanentlyLockedOut':
        return BiometricResult(
          success: false,
          error: BiometricError.permanentlyLockedOut,
          message: 'Biometric authentication is permanently locked. Please use your device password.',
        );
      case 'PasscodeNotSet':
        return BiometricResult(
          success: false,
          error: BiometricError.passcodeNotSet,
          message: 'Please set up a passcode on your device first.',
        );
      default:
        return BiometricResult(
          success: false,
          error: BiometricError.unknown,
          message: e.message ?? 'An unknown error occurred.',
        );
    }
  }

  /// Stop any ongoing authentication
  Future<bool> stopAuthentication() async {
    try {
      return await _localAuth.stopAuthentication();
    } catch (_) {
      return false;
    }
  }
}

/// Result of biometric authentication
class BiometricResult {
  final bool success;
  final BiometricError? error;
  final String message;

  BiometricResult({
    required this.success,
    required this.error,
    required this.message,
  });
}

/// Types of biometric errors
enum BiometricError {
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  passcodeNotSet,
  failed,
  unknown,
}
