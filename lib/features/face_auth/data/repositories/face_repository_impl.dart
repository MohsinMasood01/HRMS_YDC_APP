import '../../domain/entities/face_identify_response.dart';
import '../../domain/entities/face_register_response.dart';
import '../../domain/entities/face_status_response.dart';
import '../../domain/entities/face_verify_response.dart';
import '../../domain/repositories/face_repository.dart';
import '../datasources/face_remote_datasource.dart';

class FaceRepositoryImpl implements FaceRepository {
  FaceRepositoryImpl(this._remoteDataSource);

  final FaceRemoteDataSource _remoteDataSource;

  @override
  Future<FaceRegisterResponse> registerFace({
    required String cardNo1,
    required List<String> frames,
    required DateTime createdAt,
  }) async {
    return await _remoteDataSource.registerFace(
      cardNo1: cardNo1,
      frames: frames,
      createdAt: createdAt,
    );
  }

  @override
  Future<FaceVerifyResponse> verifyFace({
    required String cardNo1,
    required List<String> frames,
  }) async {
    return await _remoteDataSource.verifyFace(
      cardNo1: cardNo1,
      frames: frames,
    );
  }

  @override
  Future<FaceStatusResponse> getFaceStatus(String cardNo1) async {
    return await _remoteDataSource.getFaceStatus(cardNo1);
  }

  @override
  Future<FaceIdentifyResponse> identifyFace({
    required List<String> frames,
  }) async {
    return await _remoteDataSource.identifyFace(frames: frames);
  }
}


