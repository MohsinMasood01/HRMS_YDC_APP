import 'package:equatable/equatable.dart';

/// Response entity for face identification (1:N search)
class FaceIdentifyResponse extends Equatable {
  const FaceIdentifyResponse({
    required this.identified,
    this.cardNo,
    this.empName,
    required this.confidence,
    this.message,
  });

  final bool identified;
  final String? cardNo;
  final String? empName;
  final double confidence;
  final String? message;

  @override
  List<Object?> get props => [identified, cardNo, empName, confidence, message];
}
