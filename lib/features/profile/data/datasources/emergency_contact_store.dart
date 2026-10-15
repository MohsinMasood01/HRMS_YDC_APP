import '../../../../core/services/local_storage_service.dart';
import '../../domain/entities/enhanced_profile_entity.dart';

/// Device-side store for the employee's emergency contact.
///
/// The backend does not persist this yet, so an edit used to live only in the
/// bloc's state and was lost on the next logout. Saving it here — keyed by the
/// employee's card number so one user's contact never shows up for another —
/// makes it survive logout, login and app restarts. Once the backend endpoint
/// exists this becomes a local mirror of the server value: whatever the
/// profile API returns wins, and this only fills the gap.
class EmergencyContactStore {
  EmergencyContactStore(this._storage);

  final LocalStorageService _storage;

  static String _key(String cardNo) => 'emergency_contact_$cardNo';

  /// Contact saved for [cardNo], or null when nothing was ever saved.
  EmergencyContact? read(String? cardNo) {
    final key = _keyOrNull(cardNo);
    if (key == null) return null;
    try {
      final data = _storage.readJson(key);
      if (data == null) return null;
      final contact = EmergencyContact.fromJson(data);
      // A blank record is the same as no record.
      return contact.name.trim().isEmpty && contact.phoneNumber.trim().isEmpty
          ? null
          : contact;
    } catch (_) {
      // Corrupt entry: treat it as absent rather than breaking the profile.
      return null;
    }
  }

  Future<void> write(String? cardNo, EmergencyContact contact) async {
    final key = _keyOrNull(cardNo);
    if (key == null) return;
    await _storage.writeJson(key, contact.toJson());
  }

  Future<void> clear(String? cardNo) async {
    final key = _keyOrNull(cardNo);
    if (key == null) return;
    await _storage.remove(key);
  }

  static String? _keyOrNull(String? cardNo) {
    final card = cardNo?.trim();
    if (card == null || card.isEmpty || card == '-') return null;
    return _key(card);
  }
}
