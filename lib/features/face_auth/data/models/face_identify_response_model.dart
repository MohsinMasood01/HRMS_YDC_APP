import '../../domain/entities/face_identify_response.dart';

class FaceIdentifyResponseModel extends FaceIdentifyResponse {
  const FaceIdentifyResponseModel({
    required super.identified,
    super.cardNo,
    super.empName,
    required super.confidence,
    super.message,
  });

  factory FaceIdentifyResponseModel.fromJson(Map<String, dynamic> json) {
    final body = json['body'] as Map<String, dynamic>? ?? json;
    return FaceIdentifyResponseModel(
      identified: body['identified'] as bool? ?? false,
      cardNo: body['card_no'] as String?,
      empName: body['emp_name'] as String?,
      confidence: (body['confidence'] as num?)?.toDouble() ?? 0.0,
      message: body['message'] as String? ?? body['msg'] as String?,
    );
  }
}
