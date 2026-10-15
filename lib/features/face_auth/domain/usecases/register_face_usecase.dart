import '../entities/face_register_response.dart';
import '../repositories/face_repository.dart';

/// Use case for registering face with base64 frames
class RegisterFaceUseCase {
  RegisterFaceUseCase(this._repository);

  final FaceRepository _repository;

  Future<FaceRegisterResponse> call({
    required String cardNo1,
    required List<String> frames,
    required DateTime createdAt,
  }) async {
    if (frames.length < 8) {
      throw Exception('Minimum 8 frames required for registration');
    }

    return await _repository.registerFace(
      cardNo1: cardNo1,
      frames: frames,
      createdAt: createdAt,
    );
  }
}


