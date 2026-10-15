import 'package:equatable/equatable.dart';

/// Response entity for face registration status
class FaceStatusResponse extends Equatable {
  const FaceStatusResponse({
    required this.isRegistered,
    this.cardNo1,
    this.registeredAt,
  });

  final bool isRegistered;
  final String? cardNo1;
  final String? registeredAt;

  @override
  List<Object?> get props => [isRegistered, cardNo1, registeredAt];
}


