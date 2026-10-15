import '../../domain/entities/face_verify_response.dart';

class FaceVerifyResponseModel extends FaceVerifyResponse {
  const FaceVerifyResponseModel({
    required super.isMatch,
    required super.confidence,
    super.message,
    super.empName,
  });

  factory FaceVerifyResponseModel.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>? ?? json;
    return FaceVerifyResponseModel(
      isMatch: body['is_match'] as bool? ?? false,
      confidence: (body['confidence'] as num?)?.toDouble() ?? 0.0,
      message: body['message'] as String? ?? body['msg'] as String?,
      empName: body['emp_name'] as String?,
    );
  }
}


