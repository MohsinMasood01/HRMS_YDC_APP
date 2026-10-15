import '../entities/face_embedding.dart';
import '../repositories/face_verification_repository.dart';

/// Use case for verifying a face against enrolled face on backend
///
/// Verifies a captured face embedding against the stored face on the backend
/// linked to the employee_id.
class VerifyFaceUseCase {
  VerifyFaceUseCase(this._repository);

  final FaceVerificationRepository _repository;

  /// Execute face verification
  ///
  /// [employeeId] - Employee ID or card number
  /// [capturedEmbedding] - Live face embedding vector
  ///
  /// Returns verification result with match status and confidence from backend.
  Future<FaceVerificationResult> call({
    required String employeeId,
    required FaceEmbedding capturedEmbedding,
  }) async {
    // Validate captured embedding
    if (!capturedEmbedding.isValid) {
      return const FaceVerificationResult(
        isMatch: false,
        confidence: 0.0,
        message: 'Invalid face embedding.',
      );
    }

    // Verify face with backend
    final result = await _repository.verifyFaceWithBackend(
      employeeId: employeeId,
      embedding: capturedEmbedding,
    );

    return result;
  }
}
