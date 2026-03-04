import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Centralized service for all user customization preferences.
/// Local prefs (SharedPreferences) for instant UI, synced to Firebase for backup.
/// Automatically reloads preferences when the authenticated user changes.
class UserCustomizationService extends ChangeNotifier {
  static UserCustomizationService? _instance;
  static UserCustomizationService get instance {
    _instance ??= UserCustomizationService._();
    return _instance!;
  }

  UserCustomizationService._() {
    // Listen to auth state changes to auto-reload per-user preferences
    try {
      _authSub =
          FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    } catch (_) {
      // Firebase not initialized (e.g., in tests) — skip auth listener
    }
  }

  StreamSubscription<User?>? _authSub;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  DatabaseReference get _db => FirebaseDatabase.instance.ref();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String _userKey(String key) => '${key}_${_uid ?? 'default'}';

  /// Tracks which user's preferences are currently loaded in memory.
  String? _loadedForUid;

  /// Called automatically whenever the Firebase auth user changes.
  void _onAuthChanged(User? user) {
    if (user == null) {
      // User signed out — reset to defaults
      _loadedForUid = null;
      _isLoaded = false;
      _resetToDefaults();
      notifyListeners();
    } else if (_loadedForUid != user.uid) {
      // Different user logged in — load their preferences
      _resetToDefaults();
      loadPreferences();
    }
  }

  /// Reset all in-memory values to defaults (no SharedPreferences clearing).
  void _resetToDefaults() {
    _accentColorIndex = 0;
    _fontScaleLabel = 'Medium';
    _visibleDashboardWidgets = List.from(allDashboardWidgets);
    _bannerGradientIndex = 0;
    _focusModeEnabled = false;
    _certificateStyle = 'classic';
    _defaultPlaybackSpeed = 1.0;
    _studyReminderEnabled = false;
    _studyReminderTime = const TimeOfDay(hour: 18, minute: 0);
    _studyReminderDays = [1, 2, 3, 4, 5];
  }

  // ──────────── Accent Color ────────────

  static const List<Color> accentColorOptions = [
    Color(0xFF1A237E), // Deep Indigo (default)
    Color(0xFF00BFA5), // Teal
    Color(0xFFE53935), // Red
    Color(0xFF8E24AA), // Purple
    Color(0xFF43A047), // Green
    Color(0xFFFF6F00), // Amber
    Color(0xFF1565C0), // Blue
    Color(0xFFD81B60), // Pink
  ];

  int _accentColorIndex = 0;
  int get accentColorIndex => _accentColorIndex;
  Color get accentColor => accentColorOptions[_accentColorIndex];

  Future<void> setAccentColor(int index) async {
    if (index < 0 || index >= accentColorOptions.length) return;
    _accentColorIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userKey('accent_color'), index);
    _syncToFirebase('accentColorIndex', index);
    notifyListeners();
  }

  // ──────────── Font Scale ────────────

  static const Map<String, double> fontScaleOptions = {
    'Small': 0.85,
    'Medium': 1.0,
    'Large': 1.15,
  };

  String _fontScaleLabel = 'Medium';
  String get fontScaleLabel => _fontScaleLabel;
  double get fontScale => fontScaleOptions[_fontScaleLabel] ?? 1.0;

  Future<void> setFontScale(String label) async {
    if (!fontScaleOptions.containsKey(label)) return;
    _fontScaleLabel = label;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey('font_scale'), label);
    _syncToFirebase('fontScale', label);
    notifyListeners();
  }

  // ──────────── Dashboard Layout ────────────

  static const List<String> allDashboardWidgets = [
    'streak',
    'stats',
    'recommendations',
    'featured_courses',
    'ai_tools',
    'announcements',
  ];

  static const Map<String, String> dashboardWidgetLabels = {
    'streak': 'Study Streak',
    'stats': 'Quick Stats',
    'recommendations': 'Recommended For You',
    'featured_courses': 'Featured Courses',
    'ai_tools': 'AI Learning Tools',
    'announcements': 'Announcements',
  };

  static const Map<String, IconData> dashboardWidgetIcons = {
    'streak': Icons.local_fire_department,
    'stats': Icons.bar_chart,
    'recommendations': Icons.auto_awesome,
    'featured_courses': Icons.star,
    'ai_tools': Icons.psychology,
    'announcements': Icons.campaign,
  };

  List<String> _visibleDashboardWidgets = List.from(allDashboardWidgets);
  List<String> get visibleDashboardWidgets => _visibleDashboardWidgets;

  Future<void> setDashboardWidgets(List<String> widgets) async {
    _visibleDashboardWidgets = widgets;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_userKey('dashboard_widgets'), widgets);
    _syncToFirebase('dashboardWidgets', widgets);
    notifyListeners();
  }

  Future<void> toggleDashboardWidget(String widget) async {
    if (_visibleDashboardWidgets.contains(widget)) {
      _visibleDashboardWidgets.remove(widget);
    } else {
      // Insert at original position
      final origIndex = allDashboardWidgets.indexOf(widget);
      int insertAt = _visibleDashboardWidgets.length;
      for (int i = 0; i < _visibleDashboardWidgets.length; i++) {
        if (allDashboardWidgets.indexOf(_visibleDashboardWidgets[i]) >
            origIndex) {
          insertAt = i;
          break;
        }
      }
      _visibleDashboardWidgets.insert(insertAt, widget);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _userKey('dashboard_widgets'), _visibleDashboardWidgets);
    _syncToFirebase('dashboardWidgets', _visibleDashboardWidgets);
    notifyListeners();
  }

  Future<void> reorderDashboardWidgets(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _visibleDashboardWidgets.removeAt(oldIndex);
    _visibleDashboardWidgets.insert(newIndex, item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _userKey('dashboard_widgets'), _visibleDashboardWidgets);
    _syncToFirebase('dashboardWidgets', _visibleDashboardWidgets);
    notifyListeners();
  }

  // ──────────── Profile Banner Color ────────────

  static const List<List<Color>> bannerGradients = [
    [Color(0xFF1A237E), Color(0xFF534bae)], // Default Indigo
    [Color(0xFF00897B), Color(0xFF00BFA5)], // Teal
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)], // Purple
    [Color(0xFFC62828), Color(0xFFEF5350)], // Red
    [Color(0xFF0277BD), Color(0xFF29B6F6)], // Blue
    [Color(0xFFE65100), Color(0xFFFF9800)], // Orange
    [Color(0xFF2E7D32), Color(0xFF66BB6A)], // Green
    [Color(0xFF37474F), Color(0xFF78909C)], // Blue Grey
  ];

  int _bannerGradientIndex = 0;
  int get bannerGradientIndex => _bannerGradientIndex;
  List<Color> get bannerGradient =>
      bannerGradients[_bannerGradientIndex];

  Future<void> setBannerGradient(int index) async {
    if (index < 0 || index >= bannerGradients.length) return;
    _bannerGradientIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userKey('banner_gradient'), index);
    _syncToFirebase('bannerGradientIndex', index);
    notifyListeners();
  }

  // ──────────── Focus Mode ────────────

  bool _focusModeEnabled = false;
  bool get focusModeEnabled => _focusModeEnabled;

  Future<void> setFocusMode(bool enabled) async {
    _focusModeEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey('focus_mode'), enabled);
    notifyListeners();
  }

  // ──────────── Certificate Style ────────────

  static const List<String> certificateStyles = [
    'classic',
    'modern',
    'elegant',
    'minimal',
  ];

  static const Map<String, String> certificateStyleLabels = {
    'classic': 'Classic',
    'modern': 'Modern',
    'elegant': 'Elegant',
    'minimal': 'Minimal',
  };

  String _certificateStyle = 'classic';
  String get certificateStyle => _certificateStyle;

  Future<void> setCertificateStyle(String style) async {
    if (!certificateStyles.contains(style)) return;
    _certificateStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey('certificate_style'), style);
    _syncToFirebase('certificateStyle', style);
    notifyListeners();
  }

  // ──────────── Study Reminders ────────────

  bool _studyReminderEnabled = false;
  bool get studyReminderEnabled => _studyReminderEnabled;

  TimeOfDay _studyReminderTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay get studyReminderTime => _studyReminderTime;

  List<int> _studyReminderDays = [1, 2, 3, 4, 5]; // Mon-Fri default
  List<int> get studyReminderDays => _studyReminderDays;

  static const Map<int, String> dayLabels = {
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
    7: 'Sun',
  };

  Future<void> setStudyReminder({
    required bool enabled,
    TimeOfDay? time,
    List<int>? days,
  }) async {
    _studyReminderEnabled = enabled;
    if (time != null) _studyReminderTime = time;
    if (days != null) _studyReminderDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userKey('study_reminder_enabled'), enabled);
    await prefs.setInt(_userKey('study_reminder_hour'), _studyReminderTime.hour);
    await prefs.setInt(
        _userKey('study_reminder_minute'), _studyReminderTime.minute);
    await prefs.setStringList(_userKey('study_reminder_days'),
        _studyReminderDays.map((d) => d.toString()).toList());
    _syncToFirebase('studyReminder', {
      'enabled': enabled,
      'hour': _studyReminderTime.hour,
      'minute': _studyReminderTime.minute,
      'days': _studyReminderDays,
    });
    notifyListeners();
  }

  // ──────────── Video Playback Speed ────────────

  double _defaultPlaybackSpeed = 1.0;
  double get defaultPlaybackSpeed => _defaultPlaybackSpeed;

  Future<void> setDefaultPlaybackSpeed(double speed) async {
    _defaultPlaybackSpeed = speed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userKey('playback_speed'), speed);
    _syncToFirebase('defaultPlaybackSpeed', speed);
    notifyListeners();
  }

  // ──────────── Load / Init ────────────

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> loadPreferences() async {
    if (_uid == null) return;
    final prefs = await SharedPreferences.getInstance();

    _accentColorIndex = prefs.getInt(_userKey('accent_color')) ?? 0;
    _fontScaleLabel = prefs.getString(_userKey('font_scale')) ?? 'Medium';
    _bannerGradientIndex = prefs.getInt(_userKey('banner_gradient')) ?? 0;
    _focusModeEnabled = prefs.getBool(_userKey('focus_mode')) ?? false;
    _certificateStyle =
        prefs.getString(_userKey('certificate_style')) ?? 'classic';
    _defaultPlaybackSpeed =
        prefs.getDouble(_userKey('playback_speed')) ?? 1.0;
    _studyReminderEnabled =
        prefs.getBool(_userKey('study_reminder_enabled')) ?? false;
    final hour = prefs.getInt(_userKey('study_reminder_hour')) ?? 18;
    final minute = prefs.getInt(_userKey('study_reminder_minute')) ?? 0;
    _studyReminderTime = TimeOfDay(hour: hour, minute: minute);
    final dayStrings =
        prefs.getStringList(_userKey('study_reminder_days'));
    if (dayStrings != null) {
      _studyReminderDays = dayStrings.map((d) => int.parse(d)).toList();
    }
    final widgets =
        prefs.getStringList(_userKey('dashboard_widgets'));
    if (widgets != null) {
      _visibleDashboardWidgets = widgets;
    }

    // Clamp accent color index
    if (_accentColorIndex >= accentColorOptions.length) {
      _accentColorIndex = 0;
    }
    if (_bannerGradientIndex >= bannerGradients.length) {
      _bannerGradientIndex = 0;
    }

    _isLoaded = true;
    _loadedForUid = _uid;
    notifyListeners();
  }

  /// Sync a single preference to Firebase for cross-device backup
  Future<void> _syncToFirebase(String key, dynamic value) async {
    try {
      if (_uid == null) return;
      await _db
          .child('user_customization')
          .child(_uid!)
          .child(key)
          .set(value);
    } catch (_) {
      // Silently fail — local prefs take priority
    }
  }

  /// Restore preferences from Firebase (e.g., on new device)
  Future<void> restoreFromFirebase() async {
    try {
      if (_uid == null) return;
      final snapshot =
          await _db.child('user_customization').child(_uid!).get();
      if (!snapshot.exists || snapshot.value == null) return;
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      if (data['accentColorIndex'] is int) {
        await setAccentColor(data['accentColorIndex'] as int);
      }
      if (data['fontScale'] is String) {
        await setFontScale(data['fontScale'] as String);
      }
      if (data['bannerGradientIndex'] is int) {
        await setBannerGradient(data['bannerGradientIndex'] as int);
      }
      if (data['certificateStyle'] is String) {
        await setCertificateStyle(data['certificateStyle'] as String);
      }
      if (data['defaultPlaybackSpeed'] is num) {
        await setDefaultPlaybackSpeed(
            (data['defaultPlaybackSpeed'] as num).toDouble());
      }
      if (data['dashboardWidgets'] is List) {
        await setDashboardWidgets(
            List<String>.from(data['dashboardWidgets']));
      }
      if (data['studyReminder'] is Map) {
        final sr = Map<String, dynamic>.from(data['studyReminder'] as Map);
        await setStudyReminder(
          enabled: sr['enabled'] == true,
          time: TimeOfDay(
            hour: sr['hour'] is int ? sr['hour'] as int : 18,
            minute: sr['minute'] is int ? sr['minute'] as int : 0,
          ),
          days: sr['days'] is List
              ? List<int>.from(sr['days'])
              : [1, 2, 3, 4, 5],
        );
      }
    } catch (_) {}
  }

  /// Reset all customizations to defaults
  Future<void> resetAll() async {
    _resetToDefaults();

    final prefs = await SharedPreferences.getInstance();
    final keys = [
      'accent_color', 'font_scale', 'dashboard_widgets',
      'banner_gradient', 'focus_mode', 'certificate_style',
      'playback_speed', 'study_reminder_enabled',
      'study_reminder_hour', 'study_reminder_minute',
      'study_reminder_days',
    ];
    for (final key in keys) {
      await prefs.remove(_userKey(key));
    }
    notifyListeners();
  }
}
