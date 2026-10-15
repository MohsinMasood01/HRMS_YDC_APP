import '../repositories/geofence_repository.dart';

class MarkAutomaticCheckInUseCase {
  MarkAutomaticCheckInUseCase(this._repository);

  final GeoFenceRepository _repository;

  Future<void> call() => _repository.markAutomaticCheckIn();
}

