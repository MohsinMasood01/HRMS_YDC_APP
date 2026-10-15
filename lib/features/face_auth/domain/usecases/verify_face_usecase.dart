import '../entities/face_verify_response.dart';
import '../repositories/face_repository.dart';

/// Use case for verifying face with base64 frames
class VerifyFaceUseCase {
  VerifyFaceUseCase(this._repository);

  final FaceRepository _repository;

  Future<FaceVerifyResponse> call({
    required String cardNo1,
    required List<String> frames,
  }) async {
    if (frames.length < 10) {
      throw Exception('Minimum 10 frames required for verification');
    }

    return await _repository.verifyFace(
      cardNo1: cardNo1,
      frames: frames,
    );
  }
}


