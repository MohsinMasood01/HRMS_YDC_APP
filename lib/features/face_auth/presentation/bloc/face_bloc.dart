import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/face_status_usecase.dart';
import '../../domain/usecases/register_face_usecase.dart';
import '../../domain/usecases/verify_face_usecase.dart';
import '../../../../core/errors/error_messages.dart';

part 'face_event.dart';
part 'face_state.dart';

/// BLoC for managing face authentication operations
///
/// Handles:
/// - Face registration (enrollment)
/// - Face verification (login/attendance)
/// - Face registration status check
class FaceBloc extends Bloc<FaceEvent, FaceState> {
  FaceBloc({
    required FaceStatusUseCase faceStatusUseCase,
    required RegisterFaceUseCase registerFaceUseCase,
    required VerifyFaceUseCase verifyFaceUseCase,
  }) : _faceStatusUseCase = faceStatusUseCase,
       _registerFaceUseCase = registerFaceUseCase,
       _verifyFaceUseCase = verifyFaceUseCase,
       super(const FaceState()) {
    on<FaceStatusRequested>(_onFaceStatusRequested);
    on<FaceRegisterRequested>(_onFaceRegisterRequested);
    on<FaceVerifyRequested>(_onFaceVerifyRequested);
    on<FaceReset>(_onFaceReset);
  }

  final FaceStatusUseCase _faceStatusUseCase;
  final RegisterFaceUseCase _registerFaceUseCase;
  final VerifyFaceUseCase _verifyFaceUseCase;

  Future<void> _onFaceStatusRequested(
    FaceStatusRequested event,
    Emitter<FaceState> emit,
  ) async {
    emit(state.copyWith(status: FaceStatus.loading, errorMessage: null));

    try {
      final response = await _faceStatusUseCase(event.cardNo1);
      emit(
        state.copyWith(
          status: FaceStatus.success,
          isRegistered: response.isRegistered,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FaceStatus.failure,
          errorMessage: ErrorMessages.from(e),
          isRegistered: false,
        ),
      );
    }
  }

  Future<void> _onFaceRegisterRequested(
    FaceRegisterRequested event,
    Emitter<FaceState> emit,
  ) async {
    emit(state.copyWith(status: FaceStatus.loading, errorMessage: null));

    try {
      if (event.frames.length < 18) {
        emit(
          state.copyWith(
            status: FaceStatus.failure,
            errorMessage: 'Minimum 18 frames required for registration',
          ),
        );
        return;
      }

      final response = await _registerFaceUseCase(
        cardNo1: event.cardNo1,
        frames: event.frames,
        createdAt: DateTime.now(),
      );

      if (response.isSuccess) {
        emit(
          state.copyWith(
            status: FaceStatus.success,
            isRegistered: true,
            message: response.message ?? 'Face registered successfully',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: FaceStatus.failure,
            errorMessage: response.message ?? 'Failed to register face',
            isRegistered: response.alreadyRegistered,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: FaceStatus.failure,
          errorMessage: ErrorMessages.from(e),
        ),
      );
    }
  }

  Future<void> _onFaceVerifyRequested(
    FaceVerifyRequested event,
    Emitter<FaceState> emit,
  ) async {
    emit(state.copyWith(status: FaceStatus.loading, errorMessage: null));

    try {
      if (event.frames.length < 10) {
        emit(
          state.copyWith(
            status: FaceStatus.failure,
            errorMessage: 'Minimum 10 frames required for verification',
            isMatch: false,
          ),
        );
        return;
      }

      final response = await _verifyFaceUseCase(
        cardNo1: event.cardNo1,
        frames: event.frames,
      );

      emit(
        state.copyWith(
          status: FaceStatus.success,
          isMatch: response.isMatch,
          confidence: response.confidence,
          message: response.message,
          errorMessage: response.isMatch
              ? null
              : (response.message ?? 'Face verification failed'),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FaceStatus.failure,
          errorMessage: ErrorMessages.from(e),
          isMatch: false,
        ),
      );
    }
  }

  Future<void> _onFaceReset(FaceReset event, Emitter<FaceState> emit) async {
    emit(const FaceState());
  }
}
