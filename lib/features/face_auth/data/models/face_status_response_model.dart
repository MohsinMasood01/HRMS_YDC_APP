import '../../domain/entities/face_status_response.dart';

class FaceStatusResponseModel extends FaceStatusResponse {
  const FaceStatusResponseModel({
    required super.isRegistered,
    super.cardNo1,
    super.registeredAt,
  });

  factory FaceStatusResponseModel.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>? ?? json;
    // Check both has_registered and has_face fields
    final hasRegistered = body['has_registered'] as bool? ?? false;
    final hasFace = body['has_face'] as bool? ?? false;
    final isRegistered = body['is_registered'] as bool? ?? false;
    // If any of these is true, consider face as registered
    final isFaceRegistered = hasRegistered || hasFace || isRegistered;
    return FaceStatusResponseModel(
      isRegistered: isFaceRegistered,
      cardNo1: body['card_no1'] as String? ?? body['card_no'] as String?,
      registeredAt: body['registered_at'] as String?,
    );
  }

  factory FaceStatusResponseModel.notRegistered() {
    return const FaceStatusResponseModel(isRegistered: false);
  }
}
