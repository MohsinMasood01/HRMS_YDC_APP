import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  LocalStorageService(this._preferences);

  final SharedPreferences _preferences;

  /// Get the underlying SharedPreferences instance
  SharedPreferences get prefs => _preferences;

  Future<void> writeString(String key, String value) async {
    await _preferences.setString(key, value);
  }

  String? readString(String key) {
    return _preferences.getString(key);
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await _preferences.setString(key, jsonEncode(value));
  }

  Map<String, dynamic>? readJson(String key) {
    final data = _preferences.getString(key);
    if (data == null) {
      return null;
    }
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }
}

