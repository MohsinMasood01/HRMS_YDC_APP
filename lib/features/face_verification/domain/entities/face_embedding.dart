import 'package:equatable/equatable.dart';

/// Face embedding entity representing a face embedding vector
///
/// This entity stores only the numeric representation of a face,
/// NOT the raw image. This ensures privacy compliance.
/// Embedding dimension depends on the model (typically 128 or 512).
class FaceEmbedding extends Equatable {
  const FaceEmbedding({
    required this.embedding,
    required this.createdAt,
    this.id,
  });

  /// Unique identifier for this embedding
  final String? id;

  /// Face embedding vector (dimension depends on model, typically 128 or 512)
  /// Each value represents a feature extracted from the face
  final List<double> embedding;

  /// Timestamp when this embedding was created
  final DateTime createdAt;

  /// Validate that embedding has correct dimensions (must be non-empty)
  bool get isValid => embedding.isNotEmpty;

  /// Create a copy with updated fields
  FaceEmbedding copyWith({
    String? id,
    List<double>? embedding,
    DateTime? createdAt,
  }) {
    return FaceEmbedding(
      id: id ?? this.id,
      embedding: embedding ?? this.embedding,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, embedding, createdAt];
}

/// Enrollment data containing multiple face embeddings
///
/// Used during face enrollment to store multiple captures
/// before averaging them into a single master embedding
class FaceEnrollmentData extends Equatable {
  const FaceEnrollmentData({required this.embeddings, required this.createdAt});

  /// List of face embeddings captured during enrollment
  final List<FaceEmbedding> embeddings;

  /// Timestamp when enrollment started
  final DateTime createdAt;

  /// Average embedding computed from all captured embeddings
  /// This is the master template used for verification
  FaceEmbedding get averageEmbedding {
    if (embeddings.isEmpty) {
      throw StateError('Cannot compute average from empty embeddings');
    }

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

    return FaceEmbedding(embedding: averaged, createdAt: createdAt);
  }

  @override
  List<Object?> get props => [embeddings, createdAt];
}






