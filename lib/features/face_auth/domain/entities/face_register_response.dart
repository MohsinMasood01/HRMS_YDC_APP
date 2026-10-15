import 'package:equatable/equatable.dart';

/// Response entity for face registration
class FaceRegisterResponse extends Equatable {
  const FaceRegisterResponse({
    required this.status,
    required this.cardNo1,
    this.alreadyRegistered = false,
    this.message,
  });

  final String status;
  final String cardNo1;
  final bool alreadyRegistered;
  final String? message;

  bool get isSuccess => status.toUpperCase() == 'SUCCESS';

  @override
  List<Object?> get props => [status, cardNo1, alreadyRegistered, message];
}


