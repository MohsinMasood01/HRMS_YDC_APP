import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../entities/face_embedding.dart';
import '../repositories/face_verification_repository.dart';

/// Use case for enrolling a face
///
/// Captures multiple face images, extracts embeddings,
/// and registers the averaged embedding on the backend linked to employee_id.
class EnrollFaceUseCase {
  EnrollFaceUseCase(this._repository);

  final FaceVerificationRepository _repository;

  /// Execute face enrollment
  ///
  /// [employeeId] - Employee ID or card number to link face to
  /// [embeddings] - List of face embeddings captured during enrollment
  ///
  /// Takes a list of face embeddings captured during enrollment,
  /// averages them, and registers the master embedding on the backend.
  /// CRITICAL: All embeddings must be L2-normalized. The averaged embedding
  /// is re-normalized to ensure it remains a unit vector.
  Future<bool> call({
    required String employeeId,
    required List<FaceEmbedding> embeddings,
  }) async {
    if (embeddings.isEmpty) {
      throw ArgumentError('At least one embedding required for enrollment');
    }

    // Validate all embeddings have correct dimensions and are valid
    final expectedDimension = embeddings.first.embedding.length;
    for (final embedding in embeddings) {
      if (!embedding.isValid ||
          embedding.embedding.length != expectedDimension) {
        throw ArgumentError(
          'Invalid embedding: all embeddings must have the same dimension. '
          'Expected: $expectedDimension, got: ${embedding.embedding.length}',
        );
      }

      // Validate embedding is not all zeros and has valid values
      final hasNonZero = embedding.embedding.any((val) => val.abs() > 1e-6);
      if (!hasNonZero) {
        throw ArgumentError(
          'Invalid embedding: embedding appears to be all zeros',
        );
      }

      // Check for NaN or Infinity
      if (embedding.embedding.any((val) => val.isNaN || val.isInfinite)) {
        throw ArgumentError(
          'Invalid embedding: contains NaN or Infinity values',
        );
      }
    }

    // Compute average embedding (mean of normalized embeddings)
    final dimension = embeddings.first.embedding.length;
    final averaged = List<double>.filled(dimension, 0.0);

    for (final embedding in embeddings) {
      for (int i = 0; i < dimension; i++) {
        averaged[i] += embedding.embedding[i];
      }
    }

    final count = embeddings.length.toDouble();
    for (int i = 0; i < dimension; i++) {
      averaged[i] /= count;
    }

    // CRITICAL: Re-normalize the averaged embedding to unit length
    // Averaging normalized vectors does NOT preserve normalization
    // This ensures the master embedding is a proper unit vector
    final normalizedAveraged = _normalizeEmbedding(averaged);

    // Verify normalization result
    double finalMagnitudeSquared = 0.0;
    for (final value in normalizedAveraged) {
      finalMagnitudeSquared += value * value;
    }
    final finalMagnitude = math.sqrt(finalMagnitudeSquared);

    debugPrint(
      'EnrollFaceUseCase: Averaged ${embeddings.length} embeddings. '
      'Final normalized embedding L2 norm: ${finalMagnitude.toStringAsFixed(6)}',
    );

    // Create master embedding with normalized vector
    final masterEmbedding = FaceEmbedding(
      embedding: normalizedAveraged,
      createdAt: DateTime.now(),
    );

    // Register face on backend linked to employee_id
    final success = await _repository.registerFace(
      employeeId: employeeId,
      embedding: masterEmbedding,
    );

    if (!success) {
      debugPrint(
        'EnrollFaceUseCase: Face already registered for employee: $employeeId',
      );
    }

    return success;
  }

  /// L2-normalize embedding vector to unit length
  ///
  /// Formula: embedding = embedding / sqrt(sum(embedding[i] * embedding[i]))
  List<double> _normalizeEmbedding(List<double> embedding) {
    // Compute L2 norm (magnitude)
    double magnitudeSquared = 0.0;
    for (final value in embedding) {
      magnitudeSquared += value * value;
    }

    final magnitude = math.sqrt(magnitudeSquared);

    // Validate magnitude is not zero
    if (magnitude < 1e-6) {
      throw ArgumentError(
        'Cannot normalize averaged embedding: L2 norm is too low ($magnitude)',
      );
    }

    // Normalize to unit length
    return embedding.map((value) => value / magnitude).toList();
  }
}
