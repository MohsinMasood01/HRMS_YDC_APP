abstract class GeoFenceRepository {
  Future<void> markAutomaticCheckIn();
  Future<void> manualOverride({String? note});
}

