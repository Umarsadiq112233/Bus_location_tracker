import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageHelper {
  static const String _prefix = 'profile_image_';

  /// Saves the profile image bytes as a Base64 string locally.
  static Future<void> saveProfileImage(String uid, Uint8List imageBytes) async {
    try {
      final base64String = base64Encode(imageBytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$uid', base64String);
    } catch (e) {
      // Fail silently
    }
  }

  /// Loads the Base64 string from SharedPreferences and returns decoded bytes.
  static Future<Uint8List?> getProfileImage(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString('$_prefix$uid');
      if (base64String != null && base64String.isNotEmpty) {
        return base64Decode(base64String);
      }
    } catch (e) {
      // Fail silently
    }
    return null;
  }
}
