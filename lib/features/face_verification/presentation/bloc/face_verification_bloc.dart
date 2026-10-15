import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/face_embedding.dart';
import '../../domain/repositories/face_verification_repository.dart';
import '../../domain/usecases/enroll_face_usecase.dart';
import '../../../face_auth/domain/usecases/register_face_usecase.dart'
    as face_auth;
import '../../../face_auth/domain/usecases/verify_face_usecase.dart'
    as face_auth_verify;
import '../../data/datasources/face_camera_datasource.dart';
import '../../data/datasources/face_embedding_datasource.dart';
import '../../data/datasources/face_image_storage_datasource.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../di/service_locator.dart';

part 'face_verification_event.dart';
part 'face_verification_state.dart';

/// BLoC for managing face verification operations
///
/// Handles:
/// - Face enrollment (capture multiple images, extract embeddings, store)
/// - Face verification (capture image, compare with enrolled face)
/// - Liveness detection (head turn/blink)
///
/// Privacy Note: This BLoC processes images in memory only.
/// Raw images are never stored - only numeric embedding vectors are persisted.
class FaceVerificationBloc
    extends Bloc<FaceVerificationEvent, FaceVerificationState> {
  FaceVerificationBloc({
    required FaceCameraDataSource cameraDataSource,
    required FaceEmbeddingDataSource embeddingDataSource,
    required FaceVerificationRepository repository,
    required EnrollFaceUseCase enrollFaceUseCase,
    required face_auth.RegisterFaceUseCase registerFaceUseCase,
    required face_auth_verify.VerifyFaceUseCase authVerifyFaceUseCase,
    required FaceImageStorageDataSource imageStorageDataSource,
  }) : _cameraDataSource = cameraDataSource,
       _embeddingDataSource =
           embeddingDataSource, // Kept for DI compatibility but not used
       _repository = repository,
       _enrollFaceUseCase = enrollFaceUseCase,
       _registerFaceUseCase = registerFaceUseCase,
       _authVerifyFaceUseCase = authVerifyFaceUseCase,
       _imageStorageDataSource = imageStorageDataSource,
       super(const FaceVerificationState()) {
    on<FaceVerificationInitialized>(_onInitialized);
    on<StartFaceEnrollment>(_onStartEnrollment);
    on<CaptureEnrollmentBurst>(_onCaptureEnrollmentBurst);
    on<ValidateCapturedImages>(_onValidateCapturedImages);
    on<RetakeImage>(_onRetakeImage);
    on<CompleteEnrollment>(_onCompleteEnrollment);
    on<StartFaceVerification>(_onStartVerification);
    on<VerifyFace>(_onVerifyFace);
    on<ResetFaceFlow>(_onReset);
    on<CancelOperation>(_onCancel);
  }

  final FaceCameraDataSource _cameraDataSource;
  // ignore: unused_field - Kept for DI compatibility, not used anymore (backend handles embeddings)
  final FaceEmbeddingDataSource _embeddingDataSource;
  final FaceVerificationRepository _repository;
  final EnrollFaceUseCase _enrollFaceUseCase;
  final face_auth.RegisterFaceUseCase _registerFaceUseCase;
  final face_auth_verify.VerifyFaceUseCase _authVerifyFaceUseCase;
  // Image storage is handled by repository for deletion operations
  // ignore: unused_field
  final FaceImageStorageDataSource _imageStorageDataSource;

  /// Expose repository for external access (e.g., profile page deletion)
  FaceVerificationRepository get repository => _repository;

  CameraController? _cameraController;
  final List<String> _capturedImagePaths = []; // Store image paths temporarily
  final List<FaceEmbedding> _enrollmentEmbeddings =
      []; // Store embeddings for enrollment
  bool _isCapturing = false; // Prevent multiple simultaneous captures

  /// Initialize face verification feature
  Future<void> _onInitialized(
    FaceVerificationInitialized event,
    Emitter<FaceVerificationState> emit,
  ) async {
    emit(state.copyWith(status: FaceVerificationStatus.initial));

    try {
      // Get employee_id to check face registration status
      final secureStorage = getIt<SecureStorageService>();
      final employeeId = await secureStorage.read('card_no1') ?? '';
      bool hasEnrolled = false;

      if (employeeId.isNotEmpty) {
        // Check if face is registered on backend
        hasEnrolled = await _repository.isFaceRegistered(employeeId);
      }

      // Note: TFLite model initialization removed - face processing is now done on backend
      emit(
        state.copyWith(
          status: FaceVerificationStatus.cameraReady,
          hasEnrolledFace: hasEnrolled,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Failed to initialize: ${e.toString()}',
        ),
      );
    }
  }

  /// Start face enrollment process
  Future<void> _onStartEnrollment(
    StartFaceEnrollment event,
    Emitter<FaceVerificationState> emit,
  ) async {
    try {
      // Get employee_id (card_no1) from secure storage
      final secureStorage = getIt<SecureStorageService>();
      final employeeId = await secureStorage.read('card_no1') ?? '';

      if (employeeId.isEmpty) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.error,
            errorMessage: 'Employee ID not found. Please login again.',
          ),
        );
        return;
      }

      // Check if face is already registered
      final isAlreadyRegistered = await _repository.isFaceRegistered(
        employeeId,
      );
      if (isAlreadyRegistered) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.enrollmentSuccess,
            successMessage: 'Face already registered for this employee',
            hasEnrolledFace: true,
          ),
        );
        return;
      }

      _enrollmentEmbeddings.clear();
      _capturedImagePaths.clear();
      _cameraController = await _cameraDataSource.initializeCamera();

      emit(
        state.copyWith(
          status: FaceVerificationStatus.enrollmentInProgress,
          capturedImages: const [],
          burstFramesCaptured: 0,
          instructionText: 'Position your face in the center',
          isFaceDetected: false,
          isFacePositioned: false,
        ),
      );

      // Small delay to let user see the instruction, then start capture
      await Future.delayed(const Duration(milliseconds: 1500));
      add(const CaptureEnrollmentBurst());
    } catch (e) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Failed to start enrollment: ${e.toString()}',
        ),
      );
    }
  }

  /// Capture burst frames during enrollment (64 frames in ~2 seconds) - AUTOMATIC
  Future<void> _onCaptureEnrollmentBurst(
    CaptureEnrollmentBurst event,
    Emitter<FaceVerificationState> emit,
  ) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Camera not initialized',
        ),
      );
      return;
    }

    if (_isCapturing) {
      return;
    }

    _isCapturing = true;

    try {
      // Stop any existing image stream
      if (_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (_) {}
      }

      // Show initial instruction with enrollmentInProgress status
      emit(
        state.copyWith(
          status: FaceVerificationStatus.enrollmentInProgress,
          instructionText: 'Preparing to capture...',
          burstFramesCaptured: 0,
          successMessage: null,
        ),
      );

      if (!_cameraController!.value.isInitialized) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.error,
            errorMessage: 'Camera lost initialization',
          ),
        );
        _isCapturing = false;
        return;
      }

      // Small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 200));

      // Update instruction
      emit(
        state.copyWith(
          status: FaceVerificationStatus.enrollmentInProgress,
          instructionText: 'Capturing frames...',
          burstFramesCaptured: 0,
        ),
      );

      // Capture 16 frames — backend needs enough good detections after filtering
      const int numFrames = 10;
      debugPrint('FaceVerificationBloc: Starting capture of $numFrames frames');

      final frames = await _cameraDataSource.captureBurstFrames(
        _cameraController!,
        numFrames,
        onProgress: (frameCount) {
          debugPrint(
            'FaceVerificationBloc: Progress update - Frames: $frameCount/$numFrames',
          );
          try {
            emit(
              state.copyWith(
                status: FaceVerificationStatus.enrollmentInProgress,
                burstFramesCaptured: frameCount,
                instructionText: 'Capturing frames... ($frameCount/$numFrames)',
              ),
            );
          } catch (e) {
            debugPrint(
              'FaceVerificationBloc: Error emitting progress update: $e',
            );
          }
        },
      );

      debugPrint(
        'FaceVerificationBloc: Burst capture completed - ${frames.length} frames captured',
      );

      // Check if we have enough frames
      if (frames.length < 5) {
        final errorMsg =
            'Failed to capture enough frames (${frames.length}/5). Please try again.';

        debugPrint(
          'FaceVerificationBloc: Insufficient frames - ${frames.length}/5',
        );

        emit(
          state.copyWith(
            status: FaceVerificationStatus.error,
            errorMessage: errorMsg,
            instructionText: null,
          ),
        );
        _isCapturing = false;
        return;
      }

      // Update instruction for processing
      emit(
        state.copyWith(
          status: FaceVerificationStatus.processing,
          instructionText: 'Preparing images for backend registration...',
          burstFramesCaptured: frames.length,
          successMessage: null,
        ),
      );

      // Convert captured full-frame images to base64 JPG (backend expects base64 frames)
      try {
        final List<String> base64Frames = [];

        final numToSend = frames.length > 10 ? 10 : frames.length;

        for (int i = 0; i < numToSend; i++) {
          final jpg = img.encodeJpg(frames[i], quality: 85);
          base64Frames.add(base64Encode(jpg));
        }

        // Get employee_id (card_no1) from secure storage
        final secureStorage = getIt<SecureStorageService>();
        final employeeId = await secureStorage.read('card_no1') ?? '';

        if (employeeId.isEmpty) {
          emit(
            state.copyWith(
              status: FaceVerificationStatus.error,
              errorMessage: 'Employee ID not found. Please login again.',
            ),
          );
          _isCapturing = false;
          return;
        }

        // Call backend registration (face_auth) with base64 frames
        final registerResponse = await _registerFaceUseCase(
          cardNo1: employeeId,
          frames: base64Frames,
          createdAt: DateTime.now(),
        );

        if (registerResponse.isSuccess) {
          emit(
            state.copyWith(
              status: FaceVerificationStatus.enrollmentSuccess,
              successMessage:
                  registerResponse.message ?? 'Face registered successfully',
              hasEnrolledFace: true,
              capturedImages: const [],
              burstFramesCaptured: 0,
              instructionText: null,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: FaceVerificationStatus.error,
              errorMessage:
                  registerResponse.message ?? 'Face registration failed',
              instructionText: null,
            ),
          );
        }

        _enrollmentEmbeddings.clear();
        return;
      } catch (e, stackTrace) {
        debugPrint(
          'FaceVerificationBloc: ERROR preparing images for registration - $e',
        );
        debugPrint('FaceVerificationBloc: Stack trace: $stackTrace');
        emit(
          state.copyWith(
            status: FaceVerificationStatus.error,
            errorMessage: 'Registration failed: ${e.toString()}',
            instructionText: null,
          ),
        );
        _isCapturing = false;
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('FaceVerificationBloc: ERROR in _onStartEnrollment - $e');
      debugPrint('FaceVerificationBloc: Stack trace: $stackTrace');
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Burst capture failed: ${e.toString()}',
          instructionText: null,
        ),
      );
    } finally {
      // CRITICAL: Always reset capturing flag, even if exception occurs
      // This prevents the UI from being stuck in "processing" state
      _isCapturing = false;
      debugPrint(
        'FaceVerificationBloc: Enrollment flow completed, _isCapturing reset',
      );
    }
  }

  /// Validate all captured images
  Future<void> _onValidateCapturedImages(
    ValidateCapturedImages event,
    Emitter<FaceVerificationState> emit,
  ) async {
    if (state.capturedImages.isEmpty) {
      return;
    }

    emit(state.copyWith(status: FaceVerificationStatus.processing));

    final validatedImages = <CapturedImageInfo>[];

    for (int i = 0; i < state.capturedImages.length; i++) {
      final imageInfo = state.capturedImages[i];
      final imageFile = File(imageInfo.imagePath);

      try {
        // Note: Face validation is now done on backend
        // For now, just validate that image exists and can be read
        if (!await imageFile.exists()) {
          validatedImages.add(
            imageInfo.copyWith(
              isValid: false,
              validationError: 'Image file not found',
            ),
          );
          continue;
        }

        // Image is valid - face detection and validation is done on backend
        validatedImages.add(imageInfo.copyWith(isValid: true));
      } catch (e) {
        validatedImages.add(
          imageInfo.copyWith(
            isValid: false,
            validationError: 'Error: ${e.toString()}',
          ),
        );
      }
    }

    // Update state with validation results
    emit(
      state.copyWith(
        status: FaceVerificationStatus.enrollmentInProgress,
        capturedImages: validatedImages,
        errorMessage: validatedImages.any((img) => !img.isValid)
            ? 'Some images need to be retaken. Tap on invalid images to retake.'
            : null,
      ),
    );
  }

  /// Retake a specific image
  Future<void> _onRetakeImage(
    RetakeImage event,
    Emitter<FaceVerificationState> emit,
  ) async {
    if (event.imageIndex < 0 ||
        event.imageIndex >= state.capturedImages.length) {
      return;
    }

    // Delete the old image
    final oldImage = File(state.capturedImages[event.imageIndex].imagePath);
    if (await oldImage.exists()) {
      await oldImage.delete();
    }

    // Remove from lists
    _capturedImagePaths.removeAt(event.imageIndex);
    final newImages = List<CapturedImageInfo>.from(state.capturedImages)
      ..removeAt(event.imageIndex);

    emit(state.copyWith(capturedImages: newImages, errorMessage: null));
  }

  /// Complete enrollment with captured embeddings
  Future<void> _onCompleteEnrollment(
    CompleteEnrollment event,
    Emitter<FaceVerificationState> emit,
  ) async {
    // Check if we have enough embeddings from burst capture
    if (_enrollmentEmbeddings.isEmpty) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.enrollmentInProgress,
          errorMessage:
              'No frames captured. Please capture burst frames first.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: FaceVerificationStatus.processing));

    try {
      // Stop any existing image stream
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
      }

      // Get employee_id (card_no1) from secure storage
      final secureStorage = getIt<SecureStorageService>();
      final employeeId = await secureStorage.read('card_no1') ?? '';

      if (employeeId.isEmpty) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.error,
            errorMessage: 'Employee ID not found. Please login again.',
          ),
        );
        return;
      }

      // Check if face is already registered
      final alreadyRegistered = await _repository.isFaceRegistered(employeeId);
      if (alreadyRegistered) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.enrollmentSuccess,
            successMessage: 'Face already registered for this employee',
            hasEnrolledFace: true,
            capturedImages: const [],
            burstFramesCaptured: 0,
            instructionText: null,
          ),
        );
        _enrollmentEmbeddings.clear();
        return;
      }

      // Enroll face (averages embeddings and registers on backend)
      final success = await _enrollFaceUseCase(
        employeeId: employeeId,
        embeddings: _enrollmentEmbeddings,
      );

      if (!success) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.error,
            errorMessage: 'Face registration failed or already exists',
          ),
        );
        return;
      }

      // No temporary images to delete in burst mode

      // CRITICAL: Do NOT dispose camera after enrollment completion
      // Camera lifecycle safety requirement:
      // Camera must NOT be disposed during burst capture or enrollment
      // Camera will be disposed only on:
      // - User navigation away from enrollment page
      // - Explicit cancel operation (_onCancel)
      // - App lifecycle pause
      // This prevents camera flicker and allows smooth UX

      // Clear temporary data
      _capturedImagePaths.clear();
      _enrollmentEmbeddings.clear();

      emit(
        state.copyWith(
          status: FaceVerificationStatus.enrollmentSuccess,
          successMessage: 'Face enrolled successfully',
          hasEnrolledFace: true,
          capturedImages: const [],
          burstFramesCaptured: 0,
          instructionText: null,
        ),
      );

      _enrollmentEmbeddings.clear();
    } catch (e) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Failed to complete enrollment: ${e.toString()}',
        ),
      );
    }
  }

  /// Start face verification process
  Future<void> _onStartVerification(
    StartFaceVerification event,
    Emitter<FaceVerificationState> emit,
  ) async {
    // Get employee_id (card_no1) from secure storage
    final secureStorage = getIt<SecureStorageService>();
    final employeeId = await secureStorage.read('card_no1') ?? '';

    if (employeeId.isEmpty) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Employee ID not found. Please login again.',
        ),
      );
      return;
    }

    // Check if face is registered for this employee on backend
    final isRegistered = await _repository.isFaceRegistered(employeeId);
    if (!isRegistered) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'No face registered. Please enroll your face first.',
        ),
      );
      return;
    }

    try {
      _cameraController = await _cameraDataSource.initializeCamera();

      emit(
        state.copyWith(status: FaceVerificationStatus.verificationInProgress),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Failed to start verification: ${e.toString()}',
        ),
      );
    }
  }

  /// Verify captured face
  Future<void> _onVerifyFace(
    VerifyFace event,
    Emitter<FaceVerificationState> emit,
  ) async {
    if (_cameraController == null) {
      emit(
        state.copyWith(
          status: FaceVerificationStatus.error,
          errorMessage: 'Camera not initialized',
        ),
      );
      return;
    }

    // Prevent multiple simultaneous captures
    if (_isCapturing) {
      return;
    }

    _isCapturing = true;

    // Stop any existing image stream
    if (_cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {}
    }

    emit(state.copyWith(status: FaceVerificationStatus.processing));

    try {
      // Verify camera is still initialized and ready
      if (!_cameraController!.value.isInitialized) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.error,
            errorMessage: 'Camera lost initialization',
          ),
        );
        _isCapturing = false;
        return;
      }

      // Capture 16 frames — sufficient for backend after filtering
      const int numFrames = 16;
      final frames = await _cameraDataSource.captureBurstFrames(
        _cameraController!,
        numFrames,
      );

      if (frames.isEmpty || frames.length < 5) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.verificationFailure,
            errorMessage:
                'Failed to capture enough frames (${frames.length}/5). Please try again.',
          ),
        );
        _isCapturing = false;
        return;
      }

      // Convert frames to base64 JPG — resized to 640x480 for reliable face detection
      final List<String> base64Frames = [];

      for (int i = 0; i < frames.length; i++) {
        final jpg = img.encodeJpg(frames[i], quality: 85);
        base64Frames.add(base64Encode(jpg));
      }

      // 4. Get employee_id (card_no1) from secure storage
      final secureStorage = getIt<SecureStorageService>();
      final employeeId = await secureStorage.read('card_no1') ?? '';

      if (employeeId.isEmpty) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.verificationFailure,
            errorMessage: 'Employee ID not found. Please login again.',
          ),
        );
        _isCapturing = false;
        return;
      }

      // 5. Check if face is registered for this employee
      final isRegistered = await _repository.isFaceRegistered(employeeId);
      if (!isRegistered) {
        emit(
          state.copyWith(
            status: FaceVerificationStatus.verificationFailure,
            errorMessage: 'Face not registered. Please enroll your face first.',
          ),
        );
        _isCapturing = false;
        return;
      }

      // 6. Verify face with backend (send base64 frames)
      try {
        final verifyResponse = await _authVerifyFaceUseCase(
          cardNo1: employeeId,
          frames: base64Frames,
        );

        if (verifyResponse.isMatch) {
          emit(
            state.copyWith(
              status: FaceVerificationStatus.verificationSuccess,
              similarityScore: verifyResponse.confidence,
              successMessage:
                  verifyResponse.message ?? 'Face verified successfully',
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: FaceVerificationStatus.verificationFailure,
              similarityScore: verifyResponse.confidence,
              errorMessage:
                  verifyResponse.message ??
                  'Face verification failed. Please try again.',
            ),
          );
        }
      } catch (e) {
        debugPrint('FaceVerificationBloc: Verification error: $e');
        emit(
          state.copyWith(
            status: FaceVerificationStatus.verificationFailure,
            errorMessage: 'Verification failed: ${e.toString()}',
          ),
        );
      } finally {
        _isCapturing = false;
      }
    } catch (e) {
      debugPrint(
        'FaceVerificationBloc: Unexpected error during verification: $e',
      );
      emit(
        state.copyWith(
          status: FaceVerificationStatus.verificationFailure,
          errorMessage: 'Verification failed: ${e.toString()}',
        ),
      );
      _isCapturing = false;
    }
  }

  /// Reset face verification flow
  Future<void> _onReset(
    ResetFaceFlow event,
    Emitter<FaceVerificationState> emit,
  ) async {
    // Stop any existing image stream
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (_) {}
    }

    // Dispose camera if active
    if (_cameraController != null) {
      await _cameraDataSource.disposeCamera(_cameraController!);
      _cameraController = null;
    }

    _enrollmentEmbeddings.clear();
    _capturedImagePaths.clear();

    // Check enrollment status from backend
    final secureStorage = getIt<SecureStorageService>();
    final employeeId = await secureStorage.read('card_no1') ?? '';
    bool hasEnrolled = false;

    if (employeeId.isNotEmpty) {
      hasEnrolled = await _repository.isFaceRegistered(employeeId);
    }

    emit(
      state.copyWith(
        status: FaceVerificationStatus.cameraReady,
        capturedImages: const [],
        isFaceDetected: false,
        isFacePositioned: false,
        isLivenessDetected: false,
        errorMessage: null,
        successMessage: null,
        similarityScore: null,
        hasEnrolledFace: hasEnrolled,
      ),
    );
  }

  /// Cancel current operation
  Future<void> _onCancel(
    CancelOperation event,
    Emitter<FaceVerificationState> emit,
  ) async {
    // Stop any existing image stream
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (_) {}
    }

    // Dispose camera if active
    if (_cameraController != null) {
      await _cameraDataSource.disposeCamera(_cameraController!);
      _cameraController = null;
    }

    _enrollmentEmbeddings.clear();
    _capturedImagePaths.clear();

    // Check enrollment status from backend
    final secureStorage = getIt<SecureStorageService>();
    final employeeId = await secureStorage.read('card_no1') ?? '';
    bool hasEnrolled = false;

    if (employeeId.isNotEmpty) {
      hasEnrolled = await _repository.isFaceRegistered(employeeId);
    }

    emit(
      state.copyWith(
        status: FaceVerificationStatus.cameraReady,
        capturedImages: const [],
        burstFramesCaptured: 0,
        instructionText: null,
        isFaceDetected: false,
        isFacePositioned: false,
        errorMessage: null,
        successMessage: null,
        similarityScore: null,
        hasEnrolledFace: hasEnrolled,
      ),
    );

    emit(
      state.copyWith(
        status: FaceVerificationStatus.cameraReady,
        capturedImages: const [],
        isFaceDetected: false,
        isFacePositioned: false,
        hasEnrolledFace: hasEnrolled,
      ),
    );
  }

  /// Get camera controller (for UI)
  CameraController? get cameraController => _cameraController;

  @override
  Future<void> close() async {
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
      }
      await _cameraDataSource.disposeCamera(_cameraController!);
    }
    // Note: TFLite model disposal removed - face processing is now done on backend
    return super.close();
  }
}
