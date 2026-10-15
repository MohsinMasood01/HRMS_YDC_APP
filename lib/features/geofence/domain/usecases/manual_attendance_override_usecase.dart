import '../repositories/geofence_repository.dart';

class ManualAttendanceOverrideUseCase {
  ManualAttendanceOverrideUseCase(this._repository);

  final GeoFenceRepository _repository;

  Future<void> call({String? note}) => _repository.manualOverride(note: note);
}

