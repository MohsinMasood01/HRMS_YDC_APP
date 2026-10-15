part of 'face_bloc.dart';

abstract class FaceEvent extends Equatable {
  const FaceEvent();

  @override
  List<Object?> get props => [];
}

/// Check face registration status
class FaceStatusRequested extends FaceEvent {
  const FaceStatusRequested({required this.cardNo1});

  final String cardNo1;

  @override
  List<Object?> get props => [cardNo1];
}

/// Register face with base64 frames
class FaceRegisterRequested extends FaceEvent {
  const FaceRegisterRequested({
    required this.cardNo1,
    required this.frames,
  });

  final String cardNo1;
  final List<String> frames;

  @override
  List<Object?> get props => [cardNo1, frames];
}

/// Verify face with base64 frames
class FaceVerifyRequested extends FaceEvent {
  const FaceVerifyRequested({
    required this.cardNo1,
    required this.frames,
  });

  final String cardNo1;
  final List<String> frames;

  @override
  List<Object?> get props => [cardNo1, frames];
}

/// Reset face state
class FaceReset extends FaceEvent {
  const FaceReset();
}


