import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/enhanced_profile_entity.dart';
// import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_contacts_usecase.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../../../core/errors/error_messages.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(
    this._getProfileUseCase,
    this._updateProfileContactsUseCase,
    this._changePasswordUseCase,
  ) : super(const ProfileState()) {
    on<ProfileRequested>(_onRequested);
    on<ProfileContactUpdated>(_onContactUpdated);
    on<PasswordChangeRequested>(_onPasswordChangeRequested);
  }

  final GetProfileUseCase _getProfileUseCase;
  final UpdateProfileContactsUseCase _updateProfileContactsUseCase;
  final ChangePasswordUseCase _changePasswordUseCase;

  Future<void> _onRequested(
    ProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading, errorMessage: null));
    try {
      final profile = await _getProfileUseCase();
      emit(state.copyWith(status: ProfileStatus.success, profile: profile));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: ErrorMessages.from(
            e,
            fallback: 'Could not load your profile. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _onContactUpdated(
    ProfileContactUpdated event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading, errorMessage: null));
    try {
      final updated = await _updateProfileContactsUseCase(
        emergencyName: event.emergencyName,
        emergencyPhone: event.emergencyPhone,
        emergencyRelation: event.emergencyRelation,
      );
      emit(state.copyWith(status: ProfileStatus.success, profile: updated));
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: ErrorMessages.from(
            e,
            fallback:
                'Could not save your emergency contact. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _onPasswordChangeRequested(
    PasswordChangeRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ProfileStatus.loading,
        errorMessage: null,
        passwordChangeSuccess: false,
      ),
    );
    try {
      final success = await _changePasswordUseCase(
        oldPassword: event.oldPassword,
        newPassword: event.newPassword,
      );
      if (success) {
        emit(
          state.copyWith(
            status: ProfileStatus.success,
            passwordChangeSuccess: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: ProfileStatus.failure,
            errorMessage: 'Failed to change password. Please try again.',
            passwordChangeSuccess: false,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: ErrorMessages.from(
            e,
            fallback: 'Could not change your password. Please try again.',
          ),
          passwordChangeSuccess: false,
        ),
      );
    }
  }
}
