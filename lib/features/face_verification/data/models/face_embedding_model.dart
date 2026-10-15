import '../../domain/entities/face_embedding.dart';

/// Data model for face embedding storage
///
/// Handles serialization/deserialization of face embeddings
/// for secure local storage.
class FaceEmbeddingModel extends FaceEmbedding {
  const FaceEmbeddingModel({
    required super.embedding,
    required super.createdAt,
    super.id,
  });

  /// Create from JSON stored in secure storage
  factory FaceEmbeddingModel.fromJson(Map<String, dynamic> json) {
    return FaceEmbeddingModel(
      id: json['id'] as String?,
      embedding: (json['embedding'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON for secure storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'embedding': embedding,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from domain entity
  factory FaceEmbeddingModel.fromEntity(FaceEmbedding entity) {
    return FaceEmbeddingModel(
      id: entity.id,
      embedding: entity.embedding,
      createdAt: entity.createdAt,
    );
  }

  /// Convert to domain entity
  FaceEmbedding toEntity() {
    return FaceEmbedding(id: id, embedding: embedding, createdAt: createdAt);
  }
}
