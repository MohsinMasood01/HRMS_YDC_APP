import '../entities/face_identify_response.dart';
import '../entities/face_register_response.dart';
import '../entities/face_status_response.dart';
import '../entities/face_verify_response.dart';

/// Repository interface for face authentication operations
abstract class FaceRepository {
  /// Register face with base64 frames
  ///
  /// [cardNo1] - Employee card number
  /// [frames] - List of base64 encoded image frames (minimum 10)
  /// [createdAt] - Registration timestamp
  Future<FaceRegisterResponse> registerFace({
    required String cardNo1,
    required List<String> frames,
    required DateTime createdAt,
  });

  /// Verify face with base64 frames
  ///
  /// [cardNo1] - Employee card number
  /// [frames] - List of base64 encoded image frames (minimum 5)
  Future<FaceVerifyResponse> verifyFace({
    required String cardNo1,
    required List<String> frames,
  });

  /// Check face registration status
  ///
  /// [cardNo1] - Employee card number
  Future<FaceStatusResponse> getFaceStatus(String cardNo1);

  /// Identify a person from face frames (1:N search)
  ///
  /// [frames] - List of base64 encoded image frames (minimum 5)
  Future<FaceIdentifyResponse> identifyFace({
    required List<String> frames,
  });
}


