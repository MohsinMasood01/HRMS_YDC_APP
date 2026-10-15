import '../entities/face_status_response.dart';
import '../repositories/face_repository.dart';

/// Use case for checking face registration status
class FaceStatusUseCase {
  FaceStatusUseCase(this._repository);

  final FaceRepository _repository;

  Future<FaceStatusResponse> call(String cardNo1) async {
    return await _repository.getFaceStatus(cardNo1);
  }
}


