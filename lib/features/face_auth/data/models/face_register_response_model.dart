import '../../domain/entities/face_register_response.dart';

class FaceRegisterResponseModel extends FaceRegisterResponse {
  const FaceRegisterResponseModel({
    required super.status,
    required super.cardNo1,
    super.alreadyRegistered,
    super.message,
  });

  factory FaceRegisterResponseModel.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>? ?? json;
    return FaceRegisterResponseModel(
      status: body['status'] as String? ?? 'ERROR',
      cardNo1: body['card_no1'] as String? ?? body['card_no'] as String? ?? '',
      alreadyRegistered: body['already_registered'] as bool? ?? false,
      message: body['msg'] as String? ?? body['message'] as String?,
    );
  }
}
