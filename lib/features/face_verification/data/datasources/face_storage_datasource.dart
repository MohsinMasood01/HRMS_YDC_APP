import 'dart:convert';
import '../../../../core/services/secure_storage_service.dart';
import '../models/face_embedding_model.dart';

/// Data source for secure storage of face embeddings
///
/// Stores face embeddings in encrypted secure storage.
/// Does NOT store raw images - only numeric embedding vectors.
abstract class FaceStorageDataSource {
  /// Store face embedding securely
  Future<void> storeEmbedding(FaceEmbeddingModel embedding);

  /// Retrieve stored face embedding
  Future<FaceEmbeddingModel?> getStoredEmbedding();

  /// Check if embedding exists
  Future<bool> hasStoredEmbedding();

  /// Delete stored embedding
  Future<void> deleteEmbedding();
}

class FaceStorageDataSourceImpl implements FaceStorageDataSource {
  FaceStorageDataSourceImpl(this._secureStorage);

  static const String _embeddingKey = 'face_embedding';

  final SecureStorageService _secureStorage;

  @override
  Future<void> storeEmbedding(FaceEmbeddingModel embedding) async {
    final json = jsonEncode(embedding.toJson());
    await _secureStorage.write(_embeddingKey, json);
  }

  @override
  Future<FaceEmbeddingModel?> getStoredEmbedding() async {
    final jsonString = await _secureStorage.read(_embeddingKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return FaceEmbeddingModel.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> hasStoredEmbedding() async {
    final embedding = await getStoredEmbedding();
    return embedding != null;
  }

  @override
  Future<void> deleteEmbedding() async {
    await _secureStorage.delete(_embeddingKey);
  }
}






