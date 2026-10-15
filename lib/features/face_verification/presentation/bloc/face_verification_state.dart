part of 'face_verification_bloc.dart';

/// Status of face verification process
enum FaceVerificationStatus {
  /// Initial state
  initial,

  /// Camera is ready
  cameraReady,

  /// Processing face (detection, embedding extraction)
  processing,

  /// Enrollment in progress
  enrollmentInProgress,

  /// Enrollment completed successfully
  enrollmentSuccess,

  /// Verification in progress
  verificationInProgress,

  /// Verification successful
  verificationSuccess,

  /// Verification failed
  verificationFailure,

  /// Error occurred
  error,
}

/// Captured image with validation status
class CapturedImageInfo extends Equatable {
  const CapturedImageInfo({
    required this.imagePath,
    this.isValid = false,
    this.validationError,
  });

  final String imagePath;
  final bool isValid;
  final String? validationError;

  CapturedImageInfo copyWith({
    String? imagePath,
    bool? isValid,
    String? validationError,
  }) {
    return CapturedImageInfo(
      imagePath: imagePath ?? this.imagePath,
      isValid: isValid ?? this.isValid,
      validationError: validationError,
    );
  }

  @override
  List<Object?> get props => [imagePath, isValid, validationError];
}

/// State for face verification
class FaceVerificationState extends Equatable {
  const FaceVerificationState({
    this.status = FaceVerificationStatus.initial,
    this.capturedImages = const [],
    this.requiredImagesCount = 64,
    this.burstFramesCaptured = 0,
    this.instructionText,
    this.isFaceDetected = false,
    this.isLivenessDetected = false,
    this.isFacePositioned = false,
    this.errorMessage,
    this.successMessage,
    this.similarityScore,
    this.hasEnrolledFace = false,
  });

  /// Current status
  final FaceVerificationStatus status;

  /// List of captured images with validation status
  final List<CapturedImageInfo> capturedImages;

  /// Required number of images for enrollment (for burst mode, this is frame count)
  final int requiredImagesCount;

  /// Current burst capture progress (frames captured)
  final int burstFramesCaptured;

  /// Current instruction text for user guidance
  final String? instructionText;

  /// Whether a face is currently detected in camera
  final bool isFaceDetected;

  /// Whether liveness is detected (head turn/blink)
  final bool isLivenessDetected;

  /// Whether face is properly positioned (centered and good size)
  final bool isFacePositioned;

  /// Error message if any
  final String? errorMessage;

  /// Success message
  final String? successMessage;

  /// Similarity score from verification (0.0 - 1.0)
  final double? similarityScore;

  /// Whether a face has been enrolled
  final bool hasEnrolledFace;

  /// Number of images captured
  int get capturedImagesCount => capturedImages.length;

  /// Whether enrollment is complete (all images captured and validated)
  bool get isEnrollmentComplete =>
      capturedImages.length >= requiredImagesCount &&
      capturedImages.every((img) => img.isValid);

  /// Progress percentage for enrollment (0.0 - 1.0)
  double get enrollmentProgress => burstFramesCaptured / requiredImagesCount;

  FaceVerificationState copyWith({
    FaceVerificationStatus? status,
    List<CapturedImageInfo>? capturedImages,
    int? requiredImagesCount,
    int? burstFramesCaptured,
    String? instructionText,
    bool? isFaceDetected,
    bool? isLivenessDetected,
    bool? isFacePositioned,
    String? errorMessage,
    String? successMessage,
    double? similarityScore,
    bool? hasEnrolledFace,
  }) {
    return FaceVerificationState(
      status: status ?? this.status,
      capturedImages: capturedImages ?? this.capturedImages,
      requiredImagesCount: requiredImagesCount ?? this.requiredImagesCount,
      burstFramesCaptured: burstFramesCaptured ?? this.burstFramesCaptured,
      instructionText: instructionText ?? this.instructionText,
      isFaceDetected: isFaceDetected ?? this.isFaceDetected,
      isLivenessDetected: isLivenessDetected ?? this.isLivenessDetected,
      isFacePositioned: isFacePositioned ?? this.isFacePositioned,
      errorMessage: errorMessage,
      successMessage: successMessage,
      similarityScore: similarityScore,
      hasEnrolledFace: hasEnrolledFace ?? this.hasEnrolledFace,
    );
  }

  @override
  List<Object?> get props => [
    status,
    capturedImages,
    requiredImagesCount,
    burstFramesCaptured,
    instructionText,
    isFaceDetected,
    isLivenessDetected,
    isFacePositioned,
    errorMessage,
    successMessage,
    similarityScore,
    hasEnrolledFace,
  ];
}






