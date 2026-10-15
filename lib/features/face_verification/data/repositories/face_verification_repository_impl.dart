import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/entities/face_embedding.dart';
import '../../domain/repositories/face_verification_repository.dart';
import '../datasources/face_storage_datasource.dart';
import '../datasources/face_image_storage_datasource.dart';
import '../datasources/face_verification_remote_data_source.dart';

/// Repository implementation for face verification
///
/// Handles backend storage and verification of face embeddings.
/// Face data is stored server-side and linked to employee_id for cross-device support.
class FaceVerificationRepositoryImpl implements FaceVerificationRepository {
  FaceVerificationRepositoryImpl(
    this._remoteDataSource,
    this._storageDataSource,
    this._imageStorageDataSource,
  );

  final FaceVerificationRemoteDataSource _remoteDataSource;
  final FaceStorageDataSource _storageDataSource;
  final FaceImageStorageDataSource _imageStorageDataSource;

  /// Verification threshold using cosine similarity
  ///
  /// Values above this threshold indicate a match.
  /// Typical range: 0.7 - 0.8 for face recognition models
  static const double _verificationThreshold = 0.75;

  @override
  double compareEmbeddings(FaceEmbedding embedding1, FaceEmbedding embedding2) {
    // CRITICAL: Validate embeddings before similarity calculation
    // This prevents NaN, negative similarity, or invalid results

    // 1. Check for empty embeddings
    if (embedding1.embedding.isEmpty || embedding2.embedding.isEmpty) {
      throw ArgumentError(
        'Cannot compare embeddings: One or both embeddings are empty. '
        'embedding1.length=${embedding1.embedding.length}, '
        'embedding2.length=${embedding2.embedding.length}',
      );
    }

    // 2. Check dimension mismatch
    if (embedding1.embedding.length != embedding2.embedding.length) {
      throw ArgumentError(
        'Embeddings must have the same dimension. '
        'embedding1.length=${embedding1.embedding.length}, '
        'embedding2.length=${embedding2.embedding.length}',
      );
    }

    // 3. Check for NaN or infinite values
    for (int i = 0; i < embedding1.embedding.length; i++) {
      final val1 = embedding1.embedding[i];
      final val2 = embedding2.embedding[i];

      if (val1.isNaN || val1.isInfinite || val2.isNaN || val2.isInfinite) {
        throw ArgumentError(
          'Cannot compare embeddings: Contains NaN or infinite values. '
          'embedding1[$i]=$val1, embedding2[$i]=$val2',
        );
      }
    }

    // 4. Check for all-zero embeddings
    final hasNonZero1 = embedding1.embedding.any((val) => val.abs() > 1e-6);
    final hasNonZero2 = embedding2.embedding.any((val) => val.abs() > 1e-6);
    if (!hasNonZero1 || !hasNonZero2) {
      throw ArgumentError(
        'Cannot compare embeddings: One or both embeddings are all zeros',
      );
    }

    // 5. Validate L2 norms (should be ~1.0 for normalized embeddings)
    double magnitude1Squared = 0.0;
    double magnitude2Squared = 0.0;
    for (int i = 0; i < embedding1.embedding.length; i++) {
      final val1 = embedding1.embedding[i];
      final val2 = embedding2.embedding[i];
      magnitude1Squared += val1 * val1;
      magnitude2Squared += val2 * val2;
    }
    final magnitude1 = math.sqrt(magnitude1Squared);
    final magnitude2 = math.sqrt(magnitude2Squared);

    // Log vector norms for debugging
    debugPrint(
      'FaceVerificationRepository: Embedding norms - '
      'embedding1: ${magnitude1.toStringAsFixed(6)}, '
      'embedding2: ${magnitude2.toStringAsFixed(6)}',
    );

    // Validate norms are reasonable (should be ~1.0 for normalized vectors)
    // Allow some tolerance for floating-point precision: [0.9, 1.1]
    if (magnitude1 < 0.9 || magnitude1 > 1.1) {
      throw ArgumentError(
        'Cannot compare embeddings: embedding1 has abnormal L2 norm ($magnitude1). '
        'Expected ~1.0 for normalized embedding.',
      );
    }
    if (magnitude2 < 0.9 || magnitude2 > 1.1) {
      throw ArgumentError(
        'Cannot compare embeddings: embedding2 has abnormal L2 norm ($magnitude2). '
        'Expected ~1.0 for normalized embedding.',
      );
    }

    // CRITICAL: Compute cosine similarity for L2-normalized vectors
    // Since embeddings are normalized (unit vectors), cosine similarity
    // simplifies to dot product: cos(θ) = (a · b) / (||a|| * ||b||)
    // For unit vectors: ||a|| = ||b|| = 1, so cos(θ) = a · b
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.embedding.length; i++) {
      dotProduct += embedding1.embedding[i] * embedding2.embedding[i];
    }

    // Validate dot product
    if (dotProduct.isNaN || dotProduct.isInfinite) {
      debugPrint(
        'FaceVerificationRepository: ERROR - Invalid dot product: $dotProduct',
      );
      return 0.0; // Invalid result
    }

    // Clamp cosine similarity to valid range [-1.0, 1.0]
    // For normalized vectors, this should already be in range, but we clamp defensively
    final similarity = dotProduct.clamp(-1.0, 1.0);

    // Log final similarity for debugging
    debugPrint(
      'FaceVerificationRepository: Cosine similarity = ${similarity.toStringAsFixed(6)} '
      '(dot product of normalized vectors)',
    );

    return similarity;
  }

  /// Check if similarity score indicates a match
  bool isMatch(double similarity) {
    return similarity >= _verificationThreshold;
  }

  @override
  Future<bool> registerFace({
    required String employeeId,
    required FaceEmbedding embedding,
  }) async {
    debugPrint(
      'FaceVerificationRepository: Registering face for employee: $employeeId',
    );

    // Check if face is already registered
    final alreadyRegistered = await _remoteDataSource.isFaceRegistered(
      employeeId,
    );
    if (alreadyRegistered) {
      debugPrint(
        'FaceVerificationRepository: Face already registered for employee: $employeeId',
      );
      return false; // Already registered, skip registration
    }

    // Register face on backend
    final success = await _remoteDataSource.registerFace(
      employeeId: employeeId,
      embedding: embedding,
    );

    if (success) {
      debugPrint(
        'FaceVerificationRepository: Face registered successfully for employee: $employeeId',
      );
    } else {
      debugPrint(
        'FaceVerificationRepository: Face registration failed or already exists for employee: $employeeId',
      );
    }

    return success;
  }

  @override
  Future<FaceVerificationResult> verifyFaceWithBackend({
    required String employeeId,
    required FaceEmbedding embedding,
  }) async {
    debugPrint(
      'FaceVerificationRepository: Verifying face for employee: $employeeId',
    );

    final response = await _remoteDataSource.verifyFace(
      employeeId: employeeId,
      embedding: embedding,
    );

    return FaceVerificationResult(
      isMatch: response.isMatch,
      confidence: response.confidence,
      message: response.message,
    );
  }

  @override
  Future<bool> isFaceRegistered(String employeeId) async {
    return await _remoteDataSource.isFaceRegistered(employeeId);
  }

  @override
  Future<FaceEmbedding?> getEnrolledFaceFromBackend(String employeeId) async {
    // Backend doesn't return the embedding for security reasons
    // We only check if it's registered
    final isRegistered = await isFaceRegistered(employeeId);
    if (!isRegistered) {
      return null;
    }

    // Return a placeholder embedding - actual verification happens on backend
    // This is only used for UI state management
    return null;
  }

  @override
  Future<void> deleteEnrolledFace(String employeeId) async {
    debugPrint(
      'FaceVerificationRepository: Deleting face for employee: $employeeId',
    );

    // Delete from backend
    await _remoteDataSource.deleteFace(employeeId);

    // Also delete local storage if any exists (for backward compatibility)
    await _storageDataSource.deleteEmbedding();
    await _imageStorageDataSource.deleteAllEnrollmentImages();

    debugPrint(
      'FaceVerificationRepository: Face deleted successfully for employee: $employeeId',
    );
  }
}
