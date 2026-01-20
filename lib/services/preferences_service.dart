import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage user preferences like "don't show again" dialogs
/// Preferences are stored per-user to avoid affecting other users
class PreferencesService {
  static const String _keySkipDeleteVideoConfirm = 'skip_delete_video_confirm';
  static const String _keySkipLogoutConfirm = 'skip_logout_confirm';
  static const String _keySkipUploadCancelConfirm =
      'skip_upload_cancel_confirm';

  /// Get the current user's UID for user-specific preferences
  static String? get _currentUserUid => FirebaseAuth.instance.currentUser?.uid;

  /// Build a user-specific key
  static String _userKey(String baseKey) {
    final uid = _currentUserUid;
    if (uid == null) return baseKey;
    return '${baseKey}_$uid';
  }

  /// Check if delete video confirmation should be skipped
  static Future<bool> shouldSkipDeleteVideoConfirm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userKey(_keySkipDeleteVideoConfirm)) ?? false;
  }

  /// Set whether to skip delete video confirmation
  static Future<void> setSkipDeleteVideoConfirm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey(_keySkipDeleteVideoConfirm), value);
  }

  /// Check if logout confirmation should be skipped (user-specific)
  static Future<bool> shouldSkipLogoutConfirm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userKey(_keySkipLogoutConfirm)) ?? false;
  }

  /// Set whether to skip logout confirmation (user-specific)
  static Future<void> setSkipLogoutConfirm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey(_keySkipLogoutConfirm), value);
  }

  /// Check if upload cancel confirmation should be skipped
  static Future<bool> shouldSkipUploadCancelConfirm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userKey(_keySkipUploadCancelConfirm)) ?? false;
  }

  /// Set whether to skip upload cancel confirmation
  static Future<void> setSkipUploadCancelConfirm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey(_keySkipUploadCancelConfirm), value);
  }

  /// Reset all preferences for current user
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey(_keySkipDeleteVideoConfirm));
    await prefs.remove(_userKey(_keySkipLogoutConfirm));
    await prefs.remove(_userKey(_keySkipUploadCancelConfirm));
  }
}
