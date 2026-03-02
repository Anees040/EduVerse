import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_database/firebase_database.dart';

/// Singleton service to fetch and cache platform settings from Firebase.
/// All admin-controlled settings are accessed through this service
/// so they take effect everywhere in the app.
class PlatformSettingsService {
  PlatformSettingsService._();
  static final PlatformSettingsService _instance = PlatformSettingsService._();
  static PlatformSettingsService get instance => _instance;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Map<String, dynamic> _settings = {};
  DateTime? _lastFetched;

  /// Cache duration — 30 seconds to avoid spamming Firebase.
  static const _cacheDuration = Duration(seconds: 30);

  // ────────────── Getters ──────────────

  bool get maintenanceMode => _settings['maintenanceMode'] == true;
  bool get registrationEnabled => _settings['registrationEnabled'] as bool? ?? true;
  bool get requireEmailVerification =>
      _settings['requireEmailVerification'] as bool? ?? true;
  bool get allowNewCourses => _settings['allowNewCourses'] as bool? ?? true;
  bool get autoApproveTeachers =>
      _settings['autoApproveTeachers'] as bool? ?? false;
  bool get enableNotifications =>
      _settings['enableNotifications'] as bool? ?? true;
  bool get enableChatSupport =>
      _settings['enableChatSupport'] as bool? ?? true;
  bool get enableStudentReviews =>
      _settings['enableStudentReviews'] as bool? ?? true;

  int get maxUploadSizeMB =>
      (_settings['maxUploadSizeMB'] as num?)?.toInt() ?? 100;
  int get maxCoursesPerTeacher =>
      (_settings['maxCoursesPerTeacher'] as num?)?.toInt() ?? 20;
  int get maxStudentsPerCourse =>
      (_settings['maxStudentsPerCourse'] as num?)?.toInt() ?? 500;
  int get sessionTimeoutMinutes =>
      (_settings['sessionTimeoutMinutes'] as num?)?.toInt() ?? 60;

  String get platformName =>
      _settings['platformName'] as String? ?? 'EduVerse';
  String get supportEmail =>
      _settings['supportEmail'] as String? ?? '';
  String get welcomeMessage =>
      _settings['welcomeMessage'] as String? ?? 'Welcome to EduVerse!';

  /// Raw map access for keys not covered by getters.
  dynamic operator [](String key) => _settings[key];

  // ────────────── Fetch ──────────────

  /// Fetch settings, using cache if recent enough.
  Future<Map<String, dynamic>> fetch() async {
    if (_lastFetched != null &&
        DateTime.now().difference(_lastFetched!) < _cacheDuration) {
      return _settings;
    }
    return forceRefresh();
  }

  /// Bypass cache and always read from Firebase.
  Future<Map<String, dynamic>> forceRefresh() async {
    try {
      final snap = await _db.child('platform_settings').get();
      if (snap.exists && snap.value != null) {
        _settings = Map<String, dynamic>.from(snap.value as Map);
      }
      _lastFetched = DateTime.now();
    } catch (e) {
      debugPrint('PlatformSettingsService.forceRefresh error: $e');
    }
    return _settings;
  }

  /// Convenience: ensure settings are loaded at least once.
  Future<void> ensureLoaded() async {
    if (_lastFetched == null) {
      await forceRefresh();
    }
  }

  /// Clear local cache (e.g. on logout).
  void clearCache() {
    _settings = {};
    _lastFetched = null;
  }
}
