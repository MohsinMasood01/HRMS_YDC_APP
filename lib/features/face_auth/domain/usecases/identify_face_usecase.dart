import '../entities/face_identify_response.dart';
import '../repositories/face_repository.dart';

/// Use case for identifying a person from face frames (1:N search)
class IdentifyFaceUseCase {
  IdentifyFaceUseCase(this._repository);

  final FaceRepository _repository;

  Future<FaceIdentifyResponse> call({
    required List<String> frames,
  }) async {
    if (frames.length < 5) {
      throw Exception('Minimum 5 frames required for identification');
    }

    return await _repository.identifyFace(frames: frames);
  }
}
