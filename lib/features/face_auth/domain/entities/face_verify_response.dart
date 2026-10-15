import 'package:equatable/equatable.dart';

/// Response entity for face verification
class FaceVerifyResponse extends Equatable {
  const FaceVerifyResponse({
    required this.isMatch,
    required this.confidence,
    this.message,
    this.empName,
  });

  final bool isMatch;
  final double confidence;
  final String? message;

  /// Employee name resolved from card_no on the server (best-effort).
  /// May be null if the lookup failed.
  final String? empName;

  @override
  List<Object?> get props => [isMatch, confidence, message, empName];
}


