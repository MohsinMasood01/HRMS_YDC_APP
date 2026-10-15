import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/services/attendance_file_service.dart';
import '../../../../core/services/location_tracking_config_service.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/attendance_validation_service.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../di/service_locator.dart';
import '../../../authentication/domain/repositories/auth_repository.dart';
import '../../../face_auth/domain/entities/face_identify_response.dart';
import '../../../face_auth/domain/usecases/face_status_usecase.dart';
import '../../../face_auth/domain/usecases/identify_face_usecase.dart';
import '../../../face_auth/domain/usecases/verify_face_usecase.dart';
import '../../../face_verification/data/datasources/face_camera_datasource.dart';
import '../../../location_tracking/domain/entities/tracking_session.dart';
import '../../domain/entities/biometric_attendance.dart';
import '../../domain/entities/location_info.dart';
import '../../domain/usecases/get_today_attendance_state_usecase.dart';
import '../../domain/usecases/mark_biometric_attendance_usecase.dart';

part 'biometric_attendance_event.dart';
part 'biometric_attendance_state.dart';

/// BLoC for managing biometric attendance marking
///
/// This BLoC handles:
/// - Biometric authentication (fingerprint/face)
/// - Location fetching with landmarks
/// - Duplicate check-in/check-out prevention (same location not allowed)
/// - Attendance saving to local text file
class BiometricAttendanceBloc
    extends Bloc<BiometricAttendanceEvent, BiometricAttendanceState> {
  BiometricAttendanceBloc({
    required BiometricService biometricService,
    required GeocodingService geocodingService,
    required AttendanceFileService attendanceFileService,
    required AttendanceValidationService validationService,
    required AppConfig appConfig,
    required String employeeId,
    this.identifyMode = false,
    LocationService? locationService,
    AuthRepository? authRepository,
    MarkBiometricAttendanceUseCase? markBiometricAttendanceUseCase,
    FaceStatusUseCase? faceStatusUseCase,
    VerifyFaceUseCase? verifyFaceUseCase,
    IdentifyFaceUseCase? identifyFaceUseCase,
    FaceCameraDataSource? faceCameraDataSource,
    GetTodayAttendanceStateUseCase? todayAttendanceStateUseCase,
  }) : _biometricService = biometricService,
       _geocodingService = geocodingService,
       _attendanceFileService = attendanceFileService,
       _validationService = validationService,
       _appConfig = appConfig,
       _employeeId = employeeId,
       _locationService = locationService ?? getIt<LocationService>(),
       _authRepository = authRepository,
       _markBiometricAttendanceUseCase =
           markBiometricAttendanceUseCase ??
           getIt<MarkBiometricAttendanceUseCase>(),
       _faceStatusUseCase = faceStatusUseCase ?? getIt<FaceStatusUseCase>(),
       _verifyFaceUseCase = verifyFaceUseCase ?? getIt<VerifyFaceUseCase>(),
       _identifyFaceUseCase =
           identifyFaceUseCase ?? getIt<IdentifyFaceUseCase>(),
       _faceCameraDataSource =
           faceCameraDataSource ?? getIt<FaceCameraDataSource>(),
       _todayAttendanceStateUseCase =
           todayAttendanceStateUseCase ??
           getIt<GetTodayAttendanceStateUseCase>(),
       super(const BiometricAttendanceState()) {
    on<BiometricAttendanceInitialized>(_onInitialized);
    on<BiometricAttendanceLocationRequested>(_onLocationRequested);
    on<BiometricAttendanceMarkRequested>(_onMarkRequested);
    on<BiometricAttendanceTypeChanged>(_onTypeChanged);
    on<BiometricAttendanceReset>(_onReset);
    on<BiometricAttendanceCheckTodayStatus>(_onCheckTodayStatus);
    on<BiometricAttendanceOpenLocationSettings>(_onOpenLocationSettings);
  }

  final BiometricService _biometricService;
  final GeocodingService _geocodingService;
  final AttendanceFileService _attendanceFileService;
  final AttendanceValidationService _validationService;
  final AppConfig _appConfig;
  final String _employeeId;
  final LocationService _locationService;
  // ignore: unused_field - Kept for potential future use
  final AuthRepository? _authRepository;
  final MarkBiometricAttendanceUseCase _markBiometricAttendanceUseCase;
  final FaceStatusUseCase _faceStatusUseCase;
  final VerifyFaceUseCase _verifyFaceUseCase;
  final IdentifyFaceUseCase _identifyFaceUseCase;
  final FaceCameraDataSource _faceCameraDataSource;
  final GetTodayAttendanceStateUseCase _todayAttendanceStateUseCase;
  final bool identifyMode;

  CameraController? _cameraController;
  bool _isCapturing = false;

  final _uuid = const Uuid();

  /// Today as the server last reported it; null when it could not be reached.
  TodayAttendanceState? _serverToday;

  /// Initialize the bloc - STEP 1: Check face registration status
  ///
  /// FLOW: Face Status Check → If registered → Ready, else → Face Not Registered
  Future<void> _onInitialized(
    BiometricAttendanceInitialized event,
    Emitter<BiometricAttendanceState> emit,
  ) async {
    emit(state.copyWith(status: BiometricAttendanceStatus.checkingFaceStatus));

    try {
      if (identifyMode) {
        // IDENTIFY MODE: Skip face status check, go straight to ready
        debugPrint('BiometricAttendanceBloc: Identify mode — skipping face status check');

        final isLocationEnabled = await _locationService.isLocationServiceEnabled();
        final biometrics = await _biometricService.getAvailableBiometrics();

        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.ready,
            isFaceRegistered: true,
            hasFaceId: biometrics.contains(BiometricType.face),
            hasFingerprint: biometrics.contains(BiometricType.fingerprint),
            availableBiometrics: biometrics,
            isLocationServiceEnabled: isLocationEnabled,
          ),
        );

        if (isLocationEnabled) {
          add(const BiometricAttendanceLocationRequested());
        }

        // Auto-trigger mark immediately in identify mode
        add(const BiometricAttendanceMarkRequested());
        return;
      }

      // NORMAL MODE: Check face registration status
      // Get card_no from secure storage — prefer card_no1 (set by Mark Attendance
      // dialog on login page), fall back to card_no (set during normal login).
      final secureStorage = getIt<SecureStorageService>();
      final cardNo1 = await secureStorage.read('card_no1') ??
          await secureStorage.read('card_no') ??
          '';

      if (cardNo1.isEmpty) {
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.error,
            errorMessage: 'Employee ID not found. Please login again.',
          ),
        );
        return;
      }

      // Scope the validation service to this user so different employees
      // on the same phone don't share check-in / check-out state.
      _validationService.setCurrentUser(cardNo1);

      // STEP 1: Check face registration status via API
      debugPrint(
        'BiometricAttendanceBloc: Checking face status for card_no: $cardNo1',
      );
      final faceStatusResponse = await _faceStatusUseCase.call(cardNo1);

      if (!faceStatusResponse.isRegistered) {
        // Face not registered - STOP flow
        debugPrint(
          'BiometricAttendanceBloc: Face not registered for card_no: $cardNo1',
        );
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.faceNotRegistered,
            errorMessage: 'Face not registered. Please register face first.',
            isFaceRegistered: false,
          ),
        );
        return;
      }

      // Face is registered - proceed to ready state
      debugPrint(
        'BiometricAttendanceBloc: Face is registered for card_no: $cardNo1',
      );

      // Check location service status
      final isLocationEnabled = await _locationService
          .isLocationServiceEnabled();

      // Get available biometric types (for UI display)
      final biometrics = await _biometricService.getAvailableBiometrics();
      final hasFace = biometrics.contains(BiometricType.face);
      final hasFingerprint = biometrics.contains(BiometricType.fingerprint);

      emit(
        state.copyWith(
          status: BiometricAttendanceStatus.ready,
          isFaceRegistered: true,
          hasFaceId: hasFace,
          hasFingerprint: hasFingerprint,
          availableBiometrics: biometrics,
          isLocationServiceEnabled: isLocationEnabled,
        ),
      );

      // Check today's attendance status
      add(const BiometricAttendanceCheckTodayStatus());

      // Start fetching location only if location services are enabled
      if (isLocationEnabled) {
        add(const BiometricAttendanceLocationRequested());
      } else {
        emit(
          state.copyWith(
            locationError:
                'Location services are disabled. Please enable GPS/location to mark attendance.',
          ),
        );
      }
    } catch (e) {
      debugPrint('BiometricAttendanceBloc: Error during initialization: $e');
      emit(
        state.copyWith(
          status: BiometricAttendanceStatus.error,
          errorMessage: 'Failed to check face status: ${e.toString()}',
        ),
      );
    }
  }

  /// Check today's attendance status
  Future<void> _onCheckTodayStatus(
    BiometricAttendanceCheckTodayStatus event,
    Emitter<BiometricAttendanceState> emit,
  ) async {
    // Show the local record first so the card is never blank, then correct it
    // from the server.
    final localStatus = _validationService.getTodayStatus();

    var hasCheckedIn = localStatus.hasCheckedIn;
    var hasCheckedOut = localStatus.hasCheckedOut;
    var checkInTime = localStatus.checkInTime;
    var checkOutTime = localStatus.checkOutTime;

    emit(
      state.copyWith(
        hasCheckedInToday: hasCheckedIn,
        hasCheckedOutToday: hasCheckedOut,
        todayCheckInTime: checkInTime,
        todayCheckOutTime: checkOutTime,
        replaceTodayTimes: true,
        todayFromServer: false,
      ),
    );

    // The SERVER decides what today looks like. Most re-tapping happens when
    // the employee cannot tell whether the earlier tap worked -- and a second
    // tap is what becomes an accidental check-out. A null result means the
    // server was unreachable, so we keep the local view rather than wrongly
    // showing "not marked yet".
    final serverState = await _todayAttendanceStateUseCase();
    _serverToday = serverState;
    if (serverState != null) {
      // Server wins completely. A local time must never fill a gap the server
      // left: a punch the phone thinks succeeded but HR does not have has to
      // show as missing, not as present.
      hasCheckedIn = serverState.hasCheckedIn;
      hasCheckedOut = serverState.hasCheckedOut;
      checkInTime = serverState.checkInTime;
      checkOutTime = serverState.checkOutTime;

      emit(
        state.copyWith(
          hasCheckedInToday: hasCheckedIn,
          hasCheckedOutToday: hasCheckedOut,
          todayCheckInTime: checkInTime,
          todayCheckOutTime: checkOutTime,
          replaceTodayTimes: true,
          todayFromServer: true,
        ),
      );
    }

    // Auto-select appropriate attendance type
    if (!hasCheckedIn) {
      emit(state.copyWith(attendanceType: 'check_in'));
    } else if (!hasCheckedOut) {
      emit(state.copyWith(attendanceType: 'check_out'));
    }
  }

  /// Fetch current location with address and landmarks
  Future<void> _onLocationRequested(
    BiometricAttendanceLocationRequested event,
    Emitter<BiometricAttendanceState> emit,
  ) async {
    emit(state.copyWith(isLoadingLocation: true));

    try {
      final locationInfo = await _geocodingService.getLocationInfo();

      emit(
        state.copyWith(isLoadingLocation: false, locationInfo: locationInfo),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingLocation: false,
          locationError: 'Failed to get location: $e',
        ),
      );
    }
  }

  /// Validate that the employee is within their attendance geofence.
  ///
  /// Returns `null` when attendance may proceed — geofence disabled for this
  /// employee, the employee is within range, or the check could not be
  /// completed (config/GPS error — we never lock the workforce out on a
  /// transient failure). Returns an error message when the employee is
  /// outside the allowed radius defined in HR_EMP_MASTER.
  Future<String?> _checkGeofence(String empCode) async {
    if (empCode.isEmpty) return null;
    try {
      final configService = getIt<LocationTrackingConfigService>();
      final geofence = await configService.getGeofenceSettings(empCode);

      if (geofence == null || !geofence.isEnforced) {
        debugPrint(
          'BiometricAttendanceBloc: Geofence not enforced for $empCode — '
          'attendance allowed from any location',
        );
        return null;
      }

      final position = await _locationService.currentPosition();
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        geofence.latitude!,
        geofence.longitude!,
      );
      debugPrint(
        'BiometricAttendanceBloc: Geofence check for $empCode — '
        'distance=${distance.toStringAsFixed(1)}m, '
        'margin=${geofence.margin.toStringAsFixed(0)}m',
      );

      if (distance > geofence.margin) {
        return 'You are ${distance.round()} m away from your designated work '
            'location. You must be within ${geofence.margin.round()} m to '
            'mark attendance.';
      }
      return null; // Within range
    } catch (e) {
      // Never block attendance on a config/GPS error — log and allow.
      debugPrint(
        'BiometricAttendanceBloc: Geofence check failed (allowing attendance): $e',
      );
      return null;
    }
  }

  /// Mark attendance with face verification
  ///
  /// FLOW: STEP 2: Face Verification → STEP 3: Mark Attendance (only if verification succeeds)
  Future<void> _onMarkRequested(
    BiometricAttendanceMarkRequested event,
    Emitter<BiometricAttendanceState> emit,
  ) async {
    debugPrint('=== MARK ATTENDANCE REQUESTED ===');
    // One deliberate tap == one idempotency key, minted BEFORE anything is
    // sent. Every network retry of THIS tap reuses it (see the retry loop in
    // AttendanceRemoteDataSourceImpl), so a lost response cannot become a
    // second punch. A further deliberate tap is a new punch and gets a new id.
    final clientEventId = _uuid.v4();
    debugPrint('Client event id: $clientEventId');
    debugPrint('Current state: ${state.status}');
    debugPrint('Attendance type: ${state.attendanceType}');
    debugPrint('Can mark: ${state.canMarkAttendance}');

    // In identify mode, skip face registration check and card_no lookup
    String cardNo1 = '';
    if (!identifyMode) {
      // Verify face is registered (should already be checked in initialization)
      if (!state.isFaceRegistered) {
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.faceNotRegistered,
            errorMessage: 'Face not registered. Please register face first.',
          ),
        );
        return;
      }

      // Get card_no — prefer card_no1, fall back to card_no
      final secureStorage = getIt<SecureStorageService>();
      cardNo1 = await secureStorage.read('card_no1') ??
          await secureStorage.read('card_no') ??
          '';

      if (cardNo1.isEmpty) {
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.error,
            errorMessage: 'Employee ID not found. Please login again.',
          ),
        );
        return;
      }

      // Validate duplicate check-in/check-out. When the server has told us
      // what today looks like, ITS record decides: the phone's own history
      // can claim a punch HR never received, and must not block the employee
      // from punching again. The local record is only a fallback when the
      // server could not be reached.
      final serverToday = _serverToday;
      AttendanceValidationResult validationResult;
      if (serverToday != null) {
        if (state.attendanceType == 'check_in' && serverToday.hasCheckedIn) {
          validationResult = AttendanceValidationResult(
            canProceed: false,
            reason: 'You have already checked in today'
                '${serverToday.checkInTime != null ? ' at ${serverToday.checkInTime}' : ''}.',
            errorType: AttendanceErrorType.duplicateCheckIn,
          );
        } else if (state.attendanceType == 'check_out' &&
            !serverToday.hasCheckedIn) {
          validationResult = const AttendanceValidationResult(
            canProceed: false,
            reason: 'You must check in first before checking out',
            errorType: AttendanceErrorType.noCheckIn,
          );
        } else if (state.attendanceType == 'check_out' &&
            serverToday.hasCheckedOut) {
          validationResult = AttendanceValidationResult(
            canProceed: false,
            reason: 'You have already checked out today'
                '${serverToday.checkOutTime != null ? ' at ${serverToday.checkOutTime}' : ''}.',
            errorType: AttendanceErrorType.duplicateCheckOut,
          );
        } else {
          validationResult = const AttendanceValidationResult(
            canProceed: true,
            reason: 'Allowed by server record',
          );
        }
      } else {
        final refreshedStatus = _validationService.getTodayStatus();
        emit(
          state.copyWith(
            hasCheckedInToday: refreshedStatus.hasCheckedIn,
            hasCheckedOutToday: refreshedStatus.hasCheckedOut,
            todayCheckInTime: refreshedStatus.checkInTime,
            todayCheckOutTime: refreshedStatus.checkOutTime,
            replaceTodayTimes: true,
            todayFromServer: false,
          ),
        );

        final latitude =
            state.locationInfo?.latitude ?? _appConfig.defaultGeoLatitude;
        final longitude =
            state.locationInfo?.longitude ?? _appConfig.defaultGeoLongitude;

        if (state.attendanceType == 'check_in') {
          validationResult = _validationService.canCheckIn(
            latitude: latitude,
            longitude: longitude,
          );
        } else if (!refreshedStatus.hasCheckedIn) {
          validationResult = const AttendanceValidationResult(
            canProceed: false,
            reason: 'You must check in first before checking out',
            errorType: AttendanceErrorType.noCheckIn,
          );
        } else {
          validationResult = _validationService.canCheckOut();
        }
      }

      if (!validationResult.canProceed) {
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.ready,
            errorMessage: validationResult.reason,
          ),
        );
        return;
      }
    }

    // Check location service status
    final isLocationEnabled = await _locationService.isLocationServiceEnabled();

    if (!isLocationEnabled) {
      emit(
        state.copyWith(
          status: BiometricAttendanceStatus.error,
          errorMessage:
              'Please turn on your mobile location or GPS to mark attendance.',
        ),
      );
      return;
    }

    // ============================================================
    // GEOFENCE CHECK — block if FIXED_LOCATION='Y' and outside MARGIN.
    // Normal mode: card_no is known up-front, so check before the camera
    // opens to save the user from a pointless face scan.
    // ============================================================
    if (!identifyMode) {
      emit(state.copyWith(isLoadingLocation: true));
      final geoError = await _checkGeofence(cardNo1);
      emit(state.copyWith(isLoadingLocation: false));
      if (geoError != null) {
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.ready,
            errorMessage: geoError,
          ),
        );
        return;
      }
    }

    // Use location if available, otherwise use default coordinates
    final latitude =
        state.locationInfo?.latitude ?? _appConfig.defaultGeoLatitude;
    final longitude =
        state.locationInfo?.longitude ?? _appConfig.defaultGeoLongitude;

    // Try to get location if we don't have it yet
    if (state.locationInfo == null && !state.isLoadingLocation) {
      emit(state.copyWith(isLoadingLocation: true));
      try {
        final locationInfo = await _geocodingService.getLocationInfo();
        emit(
          state.copyWith(isLoadingLocation: false, locationInfo: locationInfo),
        );
      } catch (e) {
        emit(
          state.copyWith(
            isLoadingLocation: false,
            locationError: 'Location unavailable: $e',
          ),
        );
      }
    }

    // Wait for the user to see the location before starting face capture
    await Future.delayed(const Duration(seconds: 2));

    // ============================================================
    // STEP 2: FACE VERIFICATION
    // ============================================================

    // Initialize camera for face capture
    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.capturingFaceFrames,
            totalFramesToCapture: 10,
            capturedFramesCount: 0,
          ),
        );
        _cameraController = await _faceCameraDataSource.initializeCamera();
      }
    } catch (e) {
      debugPrint('BiometricAttendanceBloc: Failed to initialize camera: $e');
      emit(
        state.copyWith(
          status: BiometricAttendanceStatus.error,
          errorMessage: 'Failed to initialize camera: ${e.toString()}',
        ),
      );
      return;
    }

    // Capture minimum 5 frames for verification
    if (_isCapturing) {
      return; // Prevent multiple simultaneous captures
    }

    _isCapturing = true;

    try {
      emit(
        state.copyWith(
          status: BiometricAttendanceStatus.capturingFaceFrames,
          totalFramesToCapture: 10,
          capturedFramesCount: 0,
          errorMessage: null,
        ),
      );

      // 10 frames is plenty for InsightFace verification — server logs show
      // only 3-4 of 20 frames typically contain a detectable face anyway.
      // Halving the target keeps slow-camera devices well inside the timeout
      // budget while keeping verification accuracy high.
      const int numFrames = 10;
      debugPrint(
        'BiometricAttendanceBloc: Starting face frame capture - $numFrames frames',
      );

      final frames = await _faceCameraDataSource.captureBurstFrames(
        _cameraController!,
        numFrames,
        onProgress: (frameCount) {
          emit(
            state.copyWith(
              capturedFramesCount: frameCount,
              status: BiometricAttendanceStatus.capturingFaceFrames,
            ),
          );
        },
      );

      // Accept partial captures: slow devices may not complete all 20 frames
      // in time. The backend can verify with as few as 5 frames; the more we
      // send the higher the confidence. Require a minimum to avoid sending
      // garbage when the camera failed entirely.
      const int minFramesForVerification = 5;
      if (frames.length < minFramesForVerification) {
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.faceVerificationFailed,
            errorMessage:
                'Failed to capture enough frames (${frames.length}/$numFrames). '
                'Please ensure your face is clearly visible and try again.',
          ),
        );
        _isCapturing = false;
        return;
      }
      if (frames.length < numFrames) {
        debugPrint(
          'BiometricAttendanceBloc: Proceeding with partial capture '
          '(${frames.length}/$numFrames frames)',
        );
      }

      // Convert frames to base64 JPEG
      final List<String> base64Frames = [];
      for (int i = 0; i < frames.length; i++) {
        final img.Image f = frames[i];
        final jpg = img.encodeJpg(f, quality: 85);
        base64Frames.add(base64Encode(jpg));
      }

      debugPrint(
        'BiometricAttendanceBloc: Captured ${base64Frames.length} frames, verifying...',
      );

      // Verify/Identify face with backend
      emit(
        state.copyWith(
          status: BiometricAttendanceStatus.verifyingFace,
          capturedFramesCount: base64Frames.length,
          errorMessage: null,
        ),
      );

      // The employeeId to use for attendance marking
      // In normal mode, use cardNo1 from secure storage (not _employeeId which
      // may be a phone number from AuthBloc).  cardNo1 was already read above.
      String effectiveEmployeeId = cardNo1.isNotEmpty ? cardNo1 : _employeeId;

      // Employee display name captured from whichever verification path runs.
      // Used in the success message and toast so the user sees who was marked.
      String? verifiedEmpName;

      if (identifyMode) {
        // IDENTIFY MODE: 1:N face search — returns who this person is
        debugPrint('BiometricAttendanceBloc: Calling face identify (1:N)...');
        final FaceIdentifyResponse identifyResponse =
            await _identifyFaceUseCase.call(frames: base64Frames);

        debugPrint(
          'BiometricAttendanceBloc: Face identify result - '
          'identified: ${identifyResponse.identified}, '
          'card_no: ${identifyResponse.cardNo}, '
          'emp_name: ${identifyResponse.empName}, '
          'confidence: ${identifyResponse.confidence}',
        );

        if (!identifyResponse.identified || identifyResponse.cardNo == null) {
          emit(
            state.copyWith(
              status: BiometricAttendanceStatus.faceVerificationFailed,
              faceVerificationMessage:
                  identifyResponse.message ?? 'Face not recognized',
              faceVerificationConfidence: identifyResponse.confidence,
              errorMessage:
                  identifyResponse.message ??
                  'Face not recognized. Please register your face first.',
            ),
          );
          _isCapturing = false;
          return;
        }

        // Use the identified card_no for attendance
        effectiveEmployeeId = identifyResponse.cardNo!;
        cardNo1 = effectiveEmployeeId;
        verifiedEmpName = identifyResponse.empName;

        // Scope validation service to identified user
        _validationService.setCurrentUser(effectiveEmployeeId);

        debugPrint(
          'BiometricAttendanceBloc: Face identified as ${identifyResponse.empName} '
          '(card_no: $effectiveEmployeeId)',
        );

        // GEOFENCE CHECK (identify mode) — only possible now that the face
        // scan has revealed which employee this is.
        final geoError = await _checkGeofence(effectiveEmployeeId);
        if (geoError != null) {
          emit(
            state.copyWith(
              status: BiometricAttendanceStatus.ready,
              errorMessage: geoError,
            ),
          );
          _isCapturing = false;
          return;
        }

        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.markingAttendance,
            faceVerificationMessage:
                'Face identified as ${identifyResponse.empName}',
            faceVerificationConfidence: identifyResponse.confidence,
            errorMessage: null,
          ),
        );
      } else {
        // NORMAL MODE: 1:1 face verification
        final verifyResponse = await _verifyFaceUseCase.call(
          cardNo1: cardNo1,
          frames: base64Frames,
        );

        debugPrint(
          'BiometricAttendanceBloc: Face verification result - '
          'isMatch: ${verifyResponse.isMatch}, '
          'confidence: ${verifyResponse.confidence}, '
          'message: ${verifyResponse.message}',
        );

        if (!verifyResponse.isMatch) {
          emit(
            state.copyWith(
              status: BiometricAttendanceStatus.faceVerificationFailed,
              faceVerificationMessage:
                  verifyResponse.message ?? 'Face verification failed',
              faceVerificationConfidence: verifyResponse.confidence,
              errorMessage:
                  verifyResponse.message ??
                  'Face verification failed. Please try again.',
            ),
          );
          _isCapturing = false;
          return;
        }

        debugPrint(
          'BiometricAttendanceBloc: Face verification succeeded - proceeding to mark attendance',
        );

        verifiedEmpName = verifyResponse.empName;

        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.markingAttendance,
            faceVerificationMessage:
                verifyResponse.message ?? 'Face verified successfully',
            faceVerificationConfidence: verifyResponse.confidence,
            errorMessage: null,
          ),
        );
      }

      // ============================================================
      // STEP 3: MARK ATTENDANCE (only if face verification succeeded)
      // ============================================================

      final now = DateTime.now();

      // Create location info if we don't have it
      final locationInfoToSave =
          state.locationInfo ??
          LocationInfo.coordinates(
            latitude: latitude,
            longitude: longitude,
            accuracy: 0.0,
          );

      // Get device info
      String? deviceId;
      String? deviceModel;
      String? appVersion;
      int? appBuild;
      try {
        final deviceInfo = DeviceInfoPlugin();
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
        appBuild = int.tryParse(packageInfo.buildNumber);

        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
          deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor;
          deviceModel = '${iosInfo.name} ${iosInfo.model}';
        }
      } catch (e) {
        // Device info is optional, continue without it
        debugPrint('Failed to get device info: $e');
      }

      // Mark attendance via API (biometric_type: 'face')
      // Send the same face frames we just captured so the backend re-identifies
      // the scanned person and marks WHOEVER scanned — making the mark
      // tamper-proof even if the card_no belongs to a previously logged-in user.
      BiometricAttendanceResponse? apiResponse;
      Object? apiError;
      try {
        debugPrint('BiometricAttendanceBloc: Calling attendance API for $effectiveEmployeeId...');
        apiResponse = await _markBiometricAttendanceUseCase.call(
          employeeId: effectiveEmployeeId,
          attendanceType: state.attendanceType,
          biometricType: 'face', // Always 'face' for face login
          locationInfo: locationInfoToSave,
          deviceId: deviceId,
          deviceModel: deviceModel,
          appVersion: appVersion,
          appBuild: appBuild,
          frames: base64Frames,
          clientEventId: clientEventId,
        );
        debugPrint(
          'BiometricAttendanceBloc: Attendance API response - '
          'success: ${apiResponse.success}, '
          'message: ${apiResponse.message}, '
          'markedFor: ${apiResponse.markedFor}, '
          'markedCardNo: ${apiResponse.markedCardNo}',
        );
      } on FaceNotRecognizedException catch (e) {
        // Backend could not identify the scanned face — no attendance was
        // recorded server-side. Show the rejection and STOP: do not record
        // locally and do not show a success screen.
        debugPrint('BiometricAttendanceBloc: Face not recognized: ${e.message}');
        emit(
          state.copyWith(
            status: BiometricAttendanceStatus.faceVerificationFailed,
            faceVerificationMessage: e.message,
            errorMessage: e.message,
          ),
        );
        _isCapturing = false;
        return;
      } catch (e, stackTrace) {
        debugPrint('BiometricAttendanceBloc: Attendance API call failed: $e');
        debugPrint('Stack trace: $stackTrace');
        apiError = e;
        apiResponse = null;
      }

      // Attendance is ONLINE-ONLY. There is no offline queue and no local
      // fallback: unless the server confirms the mark, nothing is recorded,
      // no local state moves, and the user is told what happened.
      // (Offline buffering applies to LOCATION TRACKING only -- never here.)
      if (apiResponse == null || !apiResponse.success) {
        // Two different outcomes, and the wording must not blur them:
        //  - the server ANSWERED and said no  -> the punch was NOT saved,
        //    show its reason, retrying is safe;
        //  - we never got an answer           -> the punch may or may not be
        //    on file. The retries with the same client_event_id are already
        //    spent by now, so say we could not confirm rather than claiming
        //    a failure the employee would tap through again.
        final String errorMsg;
        if (apiResponse != null) {
          final serverMessage = apiResponse.message.trim();
          errorMsg = serverMessage.isNotEmpty
              ? serverMessage
              : 'Attendance was not marked. Please try again.';
        } else {
          errorMsg = ErrorMessages.from(
            apiError,
            fallback: 'Could not confirm your attendance — check your '
                'connection and try again.',
          );
        }
        debugPrint('Attendance not marked (server did not confirm): $errorMsg');
        emit(
          state.copyWith(
            // Back to ready so the user can retry once they are online.
            status: BiometricAttendanceStatus.ready,
            errorMessage: errorMsg,
            successMessage: null,
          ),
        );
        return;
      }

      // From here on the server has answered with a 2xx. Mirror locally only
      // what the SERVER says it did -- it decides in/out itself, and a
      // `noop` / `already_done` answer means nothing new is on file. The local
      // mirror is just the offline fallback for today's card.
      final serverAction = apiResponse.action?.toLowerCase().trim();
      final recordedType = apiResponse.isNoop
          ? null
          : (serverAction == 'check_in' || serverAction == 'check_out')
              ? serverAction
              : state.attendanceType;
      if (recordedType == 'check_in') {
        await _validationService.recordCheckIn(
          latitude: latitude,
          longitude: longitude,
        );
      } else if (recordedType == 'check_out') {
        await _validationService.recordCheckOut(
          latitude: latitude,
          longitude: longitude,
        );
      }

      // Mirror the server-confirmed mark to a local file (audit trail only --
      // this is never replayed or synced).
      final fileResult = await _attendanceFileService.saveAttendance(
        employeeId: effectiveEmployeeId,
        attendanceType: state.attendanceType,
        biometricType: 'face',
        locationInfo: locationInfoToSave,
        timestamp: now,
      );

      // Update today's status
      final todayStatus = _validationService.getTodayStatus();

      // Prepare next available type (if any)
      final nextType = (!todayStatus.hasCheckedIn)
          ? 'check_in'
          : (!todayStatus.hasCheckedOut ? 'check_out' : state.attendanceType);

      // Source of truth for WHO was marked: the backend response, which
      // re-identified the scanned person from the frames. The server's card_no
      // overrides whatever we sent, so trust it for both display and tracking.
      final serverMarkedFor = apiResponse.markedFor?.trim();
      final serverMarkedCardNo = apiResponse.markedCardNo?.trim();
      final markedEmployeeId =
          (serverMarkedCardNo != null && serverMarkedCardNo.isNotEmpty)
              ? serverMarkedCardNo
              : effectiveEmployeeId;

        // Show WHO the backend actually marked — never the pre-filled user.
        // Prefer the server's name, then its card_no, then the locally
        // verified name, then the card we sent.
        final displayName =
            (serverMarkedFor != null && serverMarkedFor.isNotEmpty)
                ? serverMarkedFor
                : (serverMarkedCardNo != null && serverMarkedCardNo.isNotEmpty)
                    ? serverMarkedCardNo
                    : (verifiedEmpName != null &&
                            verifiedEmpName.trim().isNotEmpty)
                        ? verifiedEmpName.trim()
                        : effectiveEmployeeId;
        // Everything shown to the employee comes from the SERVER's answer,
        // never from what the phone assumed. `noop` means the punch matched
        // one already on file, so we say that instead of celebrating a fresh
        // check-in.
        final String successMsg;
        if (serverAction == 'already_done') {
          final serverMessage = apiResponse.message.trim();
          successMsg = serverMessage.isNotEmpty
              ? '$serverMessage — $displayName'
              : 'Attendance already completed for today — $displayName';
        } else if (apiResponse.isNoop) {
          successMsg = state.attendanceType == 'check_out'
              ? 'You were already checked out — $displayName'
              : 'You were already checked in — $displayName';
        } else {
          successMsg = 'Marked for $displayName';
        }

        debugPrint('=== ATTENDANCE MARKED SUCCESSFULLY ===');
        debugPrint('Success message: $successMsg');
        debugPrint(
          'Today status - Checked in: ${todayStatus.hasCheckedIn}, Checked out: ${todayStatus.hasCheckedOut}',
        );
        debugPrint('Next type: $nextType');

        // What the SERVER did drives tracking; the type we sent is only a
        // fallback for a backend that does not report `action`. A `noop`
        // changes nothing, so it must not move tracking either.
        final markedType = (serverAction == 'check_in' ||
                serverAction == 'check_out')
            ? serverAction!
            : (apiResponse.isNoop ? 'noop' : state.attendanceType);

        // Emit success state - the UI will show dialog. errorMessage is
        // explicitly cleared so the inline red warning banner doesn't linger
        // after a successful mark. An unconfirmed mark never reaches here.
        final newState = state.copyWith(
          status: BiometricAttendanceStatus.success,
          successMessage: successMsg,
          // The server's timestamp, not the phone's clock.
          markedAt: apiResponse.markedAt,
          // Saved, but the ERP roster did not take it: a soft note, not a
          // failure. Nothing is retried or queued because of this.
          hrSyncPending: apiResponse.isHrSyncPending,
          markedAction: apiResponse.action,
          savedFilePath: fileResult.filePath,
          hasCheckedInToday: todayStatus.hasCheckedIn,
          hasCheckedOutToday: todayStatus.hasCheckedOut,
          todayCheckInTime: todayStatus.checkInTime,
          todayCheckOutTime: todayStatus.checkOutTime,
          replaceTodayTimes: true,
          // Phone mirror only until the server refresh below replaces it.
          todayFromServer: false,
          attendanceType: nextType,
          errorMessage: null,
        );

        emit(newState);
        debugPrint(
          'Success state emitted. Status: ${newState.status}, HasCheckedIn: ${newState.hasCheckedInToday}, AttendanceType: ${newState.attendanceType}',
        );

        // The card above was filled from the phone's mirror. Replace it with
        // what the server actually has on file, so a punch that did not reach
        // the roster shows as missing instead of present. Identify mode is
        // skipped: the report is fetched for the logged-in card, which may not
        // be the person who was just scanned.
        if (!identifyMode) {
          add(const BiometricAttendanceCheckTodayStatus());
        }

        // ============================================================
        // LOCATION TRACKING (attendance itself is unchanged above)
        // ============================================================
        // Only a mark the SERVER confirmed may move tracking state, which is
        // always the case here (an unconfirmed mark returns early above).
        final trackingService = getIt<LocationTrackingService>();

        if (markedType == 'check_in') {
          // Track the person the server actually marked, not the pre-filled
          // user. Tracking starts only here -- never on screen open.
          unawaited(
            trackingService.startSessionAfterCheckIn(
              cardNo: markedEmployeeId,
              // Shift end + grace, from the backend: capture stops there if
              // no checkout comes first, so a forgotten checkout is never
              // tracked into the next day.
              cutoffAt: apiResponse.trackingCutoffAt,
              attendanceDate: apiResponse.attendanceDate,
            ),
          );
        } else if (markedType == 'check_out') {
          // Our system allows several checkouts per shift, so the phone must
          // NOT stop tracking on its own. The backend says whether this was
          // the final checkout; we only relay its ruling. When it says
          // nothing, the checkout is treated as intermediate (tracking
          // pauses, the session survives).
          unawaited(
            trackingService.applyCheckoutDirective(
              cardNo: markedEmployeeId,
              isFinalCheckout: apiResponse.isFinalCheckout,
              directive: BackendTrackingDirective.fromWire(
                apiResponse.trackingState,
              ),
            ),
          );
        }
    } catch (e) {
      debugPrint(
        'BiometricAttendanceBloc: Error during attendance marking: $e',
      );
      emit(
        state.copyWith(
          status: BiometricAttendanceStatus.error,
          errorMessage: 'Error saving attendance: ${e.toString()}',
        ),
      );
    } finally {
      _isCapturing = false;
      // Dispose camera after use
      if (_cameraController != null) {
        try {
          await _faceCameraDataSource.disposeCamera(_cameraController!);
          _cameraController = null;
        } catch (e) {
          debugPrint('BiometricAttendanceBloc: Error disposing camera: $e');
        }
      }
    }
  }

  /// Change attendance type (check-in/check-out)
  void _onTypeChanged(
    BiometricAttendanceTypeChanged event,
    Emitter<BiometricAttendanceState> emit,
  ) {
    emit(state.copyWith(attendanceType: event.type));
  }

  /// Reset state for new attendance marking
  Future<void> _onReset(
    BiometricAttendanceReset event,
    Emitter<BiometricAttendanceState> emit,
  ) async {
    // Dispose camera if active
    if (_cameraController != null) {
      try {
        await _faceCameraDataSource.disposeCamera(_cameraController!);
        _cameraController = null;
      } catch (e) {
        debugPrint(
          'BiometricAttendanceBloc: Error disposing camera on reset: $e',
        );
      }
    }

    _isCapturing = false;

    emit(
      state.copyWith(
        status: BiometricAttendanceStatus.ready,
        errorMessage: null,
        successMessage: null,
        markedAt: null,
        faceVerificationMessage: null,
        faceVerificationConfidence: null,
        capturedFramesCount: 0,
        totalFramesToCapture: 10,
      ),
    );

    // Refresh location
    add(const BiometricAttendanceLocationRequested());
  }

  /// Open location settings
  Future<void> _onOpenLocationSettings(
    BiometricAttendanceOpenLocationSettings event,
    Emitter<BiometricAttendanceState> emit,
  ) async {
    await _locationService.openLocationSettings();
    // Refresh location status after opening settings
    Future.delayed(const Duration(seconds: 1), () {
      add(const BiometricAttendanceInitialized());
    });
  }

  @override
  Future<void> close() async {
    // Dispose camera if active
    if (_cameraController != null) {
      try {
        await _faceCameraDataSource.disposeCamera(_cameraController!);
        _cameraController = null;
      } catch (e) {
        debugPrint(
          'BiometricAttendanceBloc: Error disposing camera on close: $e',
        );
      }
    }
    return super.close();
  }
}
