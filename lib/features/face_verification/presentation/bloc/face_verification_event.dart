part of 'face_verification_bloc.dart';

/// Base event for face verification
abstract class FaceVerificationEvent extends Equatable {
  const FaceVerificationEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize face verification feature
class FaceVerificationInitialized extends FaceVerificationEvent {
  const FaceVerificationInitialized();
}

/// Start face enrollment process
class StartFaceEnrollment extends FaceVerificationEvent {
  const StartFaceEnrollment();
}

/// Capture burst frames during enrollment (64 frames in ~2 seconds)
class CaptureEnrollmentBurst extends FaceVerificationEvent {
  const CaptureEnrollmentBurst();
}

/// Validate captured images
class ValidateCapturedImages extends FaceVerificationEvent {
  const ValidateCapturedImages();
}

/// Retake a specific image
class RetakeImage extends FaceVerificationEvent {
  const RetakeImage(this.imageIndex);

  final int imageIndex;

  @override
  List<Object?> get props => [imageIndex];
}

/// Complete enrollment with captured images
class CompleteEnrollment extends FaceVerificationEvent {
  const CompleteEnrollment();
}

/// Start face verification process
class StartFaceVerification extends FaceVerificationEvent {
  const StartFaceVerification();
}

/// Verify captured face
class VerifyFace extends FaceVerificationEvent {
  const VerifyFace();
}

/// Reset face verification flow
class ResetFaceFlow extends FaceVerificationEvent {
  const ResetFaceFlow();
}

/// Cancel current operation
class CancelOperation extends FaceVerificationEvent {
  const CancelOperation();
}
