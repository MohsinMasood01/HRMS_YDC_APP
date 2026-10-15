part of 'face_bloc.dart';

enum FaceStatus { initial, loading, success, failure }

class FaceState extends Equatable {
  const FaceState({
    this.status = FaceStatus.initial,
    this.isRegistered = false,
    this.isMatch = false,
    this.confidence = 0.0,
    this.errorMessage,
    this.message,
  });

  final FaceStatus status;
  final bool isRegistered;
  final bool isMatch;
  final double confidence;
  final String? errorMessage;
  final String? message;

  FaceState copyWith({
    FaceStatus? status,
    bool? isRegistered,
    bool? isMatch,
    double? confidence,
    String? errorMessage,
    String? message,
  }) {
    return FaceState(
      status: status ?? this.status,
      isRegistered: isRegistered ?? this.isRegistered,
      isMatch: isMatch ?? this.isMatch,
      confidence: confidence ?? this.confidence,
      errorMessage: errorMessage,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isRegistered,
    isMatch,
    confidence,
    errorMessage,
    message,
  ];
}


