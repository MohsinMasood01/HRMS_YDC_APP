import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Stub data source for face embedding extraction
///
/// NOTE: Face embedding extraction is now handled by the backend (FastAPI).
/// This class exists only for backward compatibility with dependency injection.
/// All methods are no-ops and should not be called.
abstract class FaceEmbeddingDataSource {
  /// Initialize model (no-op - not used)
  @Deprecated('Face embedding is now handled by backend')
  Future<void> initializeModel();

  /// Extract face embedding (no-op - not used)
  @Deprecated('Face embedding is now handled by backend')
  Future<List<double>> extractEmbedding(img.Image faceImage);

  /// Dispose model (no-op - not used)
  @Deprecated('Face embedding is now handled by backend')
  void disposeModel();
}

class FaceEmbeddingDataSourceImpl implements FaceEmbeddingDataSource {
  @override
  @Deprecated('Face embedding is now handled by backend')
  Future<void> initializeModel() async {
    // No-op: Face embedding is now handled by backend
    debugPrint(
      'FaceEmbeddingDataSource: initializeModel() called but ignored - '
      'face embedding is now handled by backend',
    );
  }

  @override
  @Deprecated('Face embedding is now handled by backend')
  Future<List<double>> extractEmbedding(img.Image faceImage) async {
    // No-op: Face embedding is now handled by backend
    debugPrint(
      'FaceEmbeddingDataSource: extractEmbedding() called but ignored - '
      'face embedding is now handled by backend',
    );
    throw UnimplementedError(
      'Face embedding extraction is now handled by the backend. '
      'This method should not be called.',
    );
  }

  @override
  @Deprecated('Face embedding is now handled by backend')
  void disposeModel() {
    // No-op: Face embedding is now handled by backend
    debugPrint(
      'FaceEmbeddingDataSource: disposeModel() called but ignored - '
      'face embedding is now handled by backend',
    );
  }
}
