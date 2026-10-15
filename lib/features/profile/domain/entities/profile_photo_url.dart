import '../../../../core/network/dio_client.dart';

/// Resolves the employee's profile picture to an absolute URL served by the
/// same backend the rest of the app talks to.
///
/// The HRMS profile payload names the photo differently depending on the
/// endpoint version, and it may be absolute, root-relative, or missing. When
/// the payload carries nothing, we fall back to the dedicated photo endpoint
/// keyed by card number; if that 404s, the UI shows the employee's initials.
class ProfilePhotoUrl {
  const ProfilePhotoUrl._();

  /// Photo endpoint served by the backend, relative to the API base URL.
  static const String photoPath = '/auth/profile-picture';

  static const List<String> _keys = [
    'profile_picture_url',
    'profile_picture',
    'profile_photo',
    'photo_url',
    'image_url',
    'emp_image',
    'employee_photo',
    'emp_photo',
    'picture',
    'avatar',
    'photo',
    'image',
  ];

  /// Absolute photo URL for [json], or the card-number fallback endpoint.
  /// Returns null only when there is neither a photo field nor a card number.
  static String? resolve(Map<String, dynamic> json, {String? cardNo}) {
    for (final key in _keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text == '-' || text.toLowerCase() == 'null') continue;
      return absolute(text);
    }

    final card = cardNo?.trim();
    if (card == null || card.isEmpty || card == '-') return null;
    return '${DioClient.baseUrl}$photoPath/$card';
  }

  /// Turns a possibly relative path into an absolute URL against the API base.
  /// Data URIs and raw base64 payloads are passed through untouched.
  static String absolute(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:')) {
      return value;
    }
    // A bare base64 blob (no scheme, no slashes) is served as a data URI.
    if (!value.contains('/') && value.length > 100) {
      return 'data:image/jpeg;base64,$value';
    }
    final base = DioClient.baseUrl.endsWith('/')
        ? DioClient.baseUrl.substring(0, DioClient.baseUrl.length - 1)
        : DioClient.baseUrl;
    return value.startsWith('/') ? '$base$value' : '$base/$value';
  }
}
