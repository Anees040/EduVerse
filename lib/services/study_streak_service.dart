import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Tracks daily study activity and calculates consecutive study streaks.
/// Data stored under /study_streaks/{uid} in Firebase RTDB.
class StudyStreakService {
  static final StudyStreakService _instance = StudyStreakService._internal();
  factory StudyStreakService() => _instance;
  StudyStreakService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Record that the user studied today. Call this when a video is watched,
  /// a quiz is taken, or any meaningful learning activity occurs.
  Future<void> recordStudyActivity() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final today = _todayKey();
      final ref = _db.child('study_streaks').child(uid);

      final snapshot = await ref.get();
      Map<String, dynamic> data = {};
      if (snapshot.exists && snapshot.value != null) {
        data = Map<String, dynamic>.from(snapshot.value as Map);
      }

      // Mark today as studied
      final studiedDays = Map<String, dynamic>.from(
        (data['studiedDays'] as Map?) ?? {},
      );
      if (studiedDays.containsKey(today)) return; // Already recorded today

      studiedDays[today] = DateTime.now().millisecondsSinceEpoch;

      // Calculate streak
      int currentStreak = _calculateStreak(studiedDays);
      int longestStreak = (data['longestStreak'] as int?) ?? 0;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }

      await ref.update({
        'studiedDays': studiedDays,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastStudiedAt': ServerValue.timestamp,
        'totalDaysStudied': studiedDays.length,
      });
    } catch (e) {
      debugPrint('Error recording study activity: $e');
    }
  }

  /// Get the user's current streak data.
  Future<Map<String, dynamic>> getStreakData() async {
    final uid = _uid;
    if (uid == null) {
      return _emptyStreak();
    }

    try {
      final snapshot = await _db.child('study_streaks').child(uid).get();

      if (!snapshot.exists || snapshot.value == null) {
        return _emptyStreak();
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      // Recalculate current streak in case a day was missed
      final studiedDays = Map<String, dynamic>.from(
        (data['studiedDays'] as Map?) ?? {},
      );

      final currentStreak = _calculateStreak(studiedDays);

      return {
        'currentStreak': currentStreak,
        'longestStreak': data['longestStreak'] ?? 0,
        'totalDaysStudied': studiedDays.length,
        'studiedToday': studiedDays.containsKey(_todayKey()),
        'lastStudiedAt': data['lastStudiedAt'],
      };
    } catch (e) {
      debugPrint('Error getting streak data: $e');
      return _emptyStreak();
    }
  }

  /// Stream of streak data for real-time UI updates.
  Stream<Map<String, dynamic>> streakStream() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(_emptyStreak());
    }

    return _db.child('study_streaks').child(uid).onValue.map((event) {
      if (event.snapshot.value == null) return _emptyStreak();

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final studiedDays = Map<String, dynamic>.from(
        (data['studiedDays'] as Map?) ?? {},
      );
      final currentStreak = _calculateStreak(studiedDays);

      return {
        'currentStreak': currentStreak,
        'longestStreak': data['longestStreak'] ?? 0,
        'totalDaysStudied': studiedDays.length,
        'studiedToday': studiedDays.containsKey(_todayKey()),
        'lastStudiedAt': data['lastStudiedAt'],
      };
    });
  }

  /// Calculate the consecutive study streak ending today (or yesterday).
  int _calculateStreak(Map<String, dynamic> studiedDays) {
    if (studiedDays.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if user studied today or yesterday
    final todayKey = _dateToKey(today);
    final yesterdayKey = _dateToKey(today.subtract(const Duration(days: 1)));

    if (!studiedDays.containsKey(todayKey) &&
        !studiedDays.containsKey(yesterdayKey)) {
      return 0; // Streak broken
    }

    // Count backwards from the most recent studied day
    DateTime checkDate = studiedDays.containsKey(todayKey)
        ? today
        : today.subtract(const Duration(days: 1));
    int streak = 0;

    while (studiedDays.containsKey(_dateToKey(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _todayKey() {
    final now = DateTime.now();
    return _dateToKey(DateTime(now.year, now.month, now.day));
  }

  String _dateToKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _emptyStreak() {
    return {
      'currentStreak': 0,
      'longestStreak': 0,
      'totalDaysStudied': 0,
      'studiedToday': false,
      'lastStudiedAt': null,
    };
  }
}
