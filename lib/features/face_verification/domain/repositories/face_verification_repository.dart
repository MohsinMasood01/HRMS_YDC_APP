import '../entities/face_embedding.dart';

/// Repository interface for face verification operations
///
/// Handles:
/// - Storing face embeddings on backend (linked to employee_id)
/// - Retrieving stored embeddings from backend
/// - Comparing embeddings for verification via backend
/// - Cross-device face verification support
abstract class FaceVerificationRepository {
  /// Register face for an employee on the backend
  ///
  /// [employeeId] - Employee ID or card number
  /// [embedding] - Face embedding vector
  /// Returns true if registration successful, false if already registered
  Future<bool> registerFace({
    required String employeeId,
    required FaceEmbedding embedding,
  });

  /// Verify face for an employee using backend
  ///
  /// [employeeId] - Employee ID or card number
  /// [embedding] - Live face embedding vector
  /// Returns verification result with match status and confidence
  Future<FaceVerificationResult> verifyFaceWithBackend({
    required String employeeId,
    required FaceEmbedding embedding,
  });

  /// Check if face is registered for an employee on backend
  ///
  /// [employeeId] - Employee ID or card number
  /// Returns true if face is registered, false otherwise
  Future<bool> isFaceRegistered(String employeeId);

  /// Get the enrolled face embedding from backend if it exists
  ///
  /// [employeeId] - Employee ID or card number
  /// Returns face embedding if registered, null otherwise
  Future<FaceEmbedding?> getEnrolledFaceFromBackend(String employeeId);

  /// Delete enrolled face for an employee from backend
  ///
  /// [employeeId] - Employee ID or card number
  /// Deletes the face registration from the backend
  Future<void> deleteEnrolledFace(String employeeId);

  /// Compare two face embeddings using cosine similarity
  ///
  /// Returns a similarity score between 0.0 and 1.0.
  /// Higher values indicate more similar faces.
  /// Typical threshold for verification: 0.75
  double compareEmbeddings(FaceEmbedding embedding1, FaceEmbedding embedding2);
}

/// Result of face verification from backend
class FaceVerificationResult {
  const FaceVerificationResult({
    required this.isMatch,
    required this.confidence,
    this.message,
  });

  final bool isMatch;
  final double confidence;
  final String? message;
}
