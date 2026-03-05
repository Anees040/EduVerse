import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Offline Mode service — connectivity monitoring + "save for offline" (pin).
///
/// How it works:
///   1. Watches Firebase's `.info/connected` node for real‑time connectivity.
///   2. Lets students "pin" courses so Firebase RTDB caches them locally
///      via `keepSynced(true)`.
///   3. The rest of the app already reads from Firebase RTDB with
///      persistence enabled (main.dart) — so pinned data stays available.
///
/// Data stored locally in SharedPreferences (pinned course IDs) and
/// Firebase RTDB keeps its own local disk cache.
class OfflineService extends ChangeNotifier {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ──────────── Connectivity ────────────

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<DatabaseEvent>? _connSub;

  /// Start monitoring connectivity. Call once at app startup.
  void startMonitoring() {
    if (kIsWeb) {
      _isOnline = true;
      return;
    }

    _connSub?.cancel();
    _connSub = _db.child('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value as bool? ?? false;
      if (_isOnline != connected) {
        _isOnline = connected;
        notifyListeners();
      }
    });
  }

  /// Stop monitoring (call from dispose if needed).
  void stopMonitoring() {
    _connSub?.cancel();
    _connSub = null;
  }

  /// Stream of connectivity state changes.
  Stream<bool> get connectivityStream {
    if (kIsWeb) return Stream.value(true);

    return _db.child('.info/connected').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  // ──────────── Pinned (Saved Offline) Courses ────────────

  /// The set of course IDs the current user has pinned for offline.
  Set<String> _pinnedCourseIds = {};
  Set<String> get pinnedCourseIds => _pinnedCourseIds;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String _prefsKey() => 'offline_pinned_${_uid ?? 'default'}';

  /// Load pinned courses from SharedPreferences.
  Future<void> loadPinnedCourses() async {
    final prefs = await SharedPreferences.getInstance();
    _pinnedCourseIds =
        (prefs.getStringList(_prefsKey()) ?? []).toSet();
    notifyListeners();
  }

  /// Check if a specific course is pinned.
  bool isCoursePinned(String courseId) => _pinnedCourseIds.contains(courseId);

  /// Toggle pin/unpin a course for offline.
  Future<void> togglePinCourse(String courseId) async {
    if (_pinnedCourseIds.contains(courseId)) {
      await unpinCourse(courseId);
    } else {
      await pinCourse(courseId);
    }
  }

  /// Pin a course — calls `keepSynced(true)` on relevant Firebase nodes.
  Future<void> pinCourse(String courseId) async {
    _pinnedCourseIds.add(courseId);

    // Tell Firebase RTDB to keep these nodes synced locally
    if (!kIsWeb) {
      _db.child('courses').child(courseId).keepSynced(true);
      _db.child('course_videos').child(courseId).keepSynced(true);
      _db.child('course_quizzes').child(courseId).keepSynced(true);
    }

    await _savePinnedList();
    notifyListeners();
  }

  /// Unpin a course — stop keeping it synced.
  Future<void> unpinCourse(String courseId) async {
    _pinnedCourseIds.remove(courseId);

    if (!kIsWeb) {
      _db.child('courses').child(courseId).keepSynced(false);
      _db.child('course_videos').child(courseId).keepSynced(false);
      _db.child('course_quizzes').child(courseId).keepSynced(false);
    }

    await _savePinnedList();
    notifyListeners();
  }

  Future<void> _savePinnedList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey(), _pinnedCourseIds.toList());
  }

  /// Re‑sync all pinned courses (call after login / on app resume).
  Future<void> resyncPinnedCourses() async {
    if (kIsWeb) return;
    for (final id in _pinnedCourseIds) {
      _db.child('courses').child(id).keepSynced(true);
      _db.child('course_videos').child(id).keepSynced(true);
      _db.child('course_quizzes').child(id).keepSynced(true);
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
