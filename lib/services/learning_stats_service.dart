import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Tracks and reports learning statistics — time spent studying,
/// videos watched, quizzes completed, weekly/monthly activity.
/// Data stored under /learning_stats/{uid} in Firebase RTDB.
class LearningStatsService {
  static final LearningStatsService _instance =
      LearningStatsService._internal();
  factory LearningStatsService() => _instance;
  LearningStatsService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Log a study session. Call when a video finishes or a quiz is submitted.
  Future<void> logStudySession({
    required int durationSeconds,
    required String activityType, // 'video', 'quiz', 'assignment', 'reading'
    String? courseId,
    String? videoId,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final now = DateTime.now();
      final weekKey = _weekKey(now);
      final dayKey = _dayKey(now);

      final ref = _db.child('learning_stats').child(uid);

      // Increment total time
      await ref
          .child('totalSeconds')
          .set(ServerValue.increment(durationSeconds));

      // Increment activity-type counter
      await ref
          .child('activityCounts')
          .child(activityType)
          .set(ServerValue.increment(1));

      // Weekly data
      await ref
          .child('weekly')
          .child(weekKey)
          .child(dayKey)
          .set(ServerValue.increment(durationSeconds));

      // Update last active
      await ref.child('lastActiveAt').set(ServerValue.timestamp);

      // Increment session count
      await ref.child('totalSessions').set(ServerValue.increment(1));
    } catch (e) {
      debugPrint('Error logging study session: $e');
    }
  }

  /// Get comprehensive learning stats for the user.
  Future<Map<String, dynamic>> getStats() async {
    final uid = _uid;
    if (uid == null) return _emptyStats();

    try {
      final snapshot = await _db.child('learning_stats').child(uid).get();
      if (!snapshot.exists || snapshot.value == null) return _emptyStats();

      final data = Map<String, dynamic>.from(snapshot.value as Map);

      final totalSeconds = (data['totalSeconds'] as num?)?.toInt() ?? 0;
      final totalSessions = (data['totalSessions'] as num?)?.toInt() ?? 0;

      // Activity counts
      final activityCounts = Map<String, dynamic>.from(
        (data['activityCounts'] as Map?) ?? {},
      );
      final videosWatched = (activityCounts['video'] as num?)?.toInt() ?? 0;
      final quizzesTaken = (activityCounts['quiz'] as num?)?.toInt() ?? 0;
      final assignmentsDone =
          (activityCounts['assignment'] as num?)?.toInt() ?? 0;

      // This week's data
      final now = DateTime.now();
      final currentWeek = _weekKey(now);
      final weeklyData = Map<String, dynamic>.from(
        (data['weekly'] as Map?) ?? {},
      );
      final thisWeekData = Map<String, dynamic>.from(
        (weeklyData[currentWeek] as Map?) ?? {},
      );

      int thisWeekSeconds = 0;
      final List<int> weekDaySeconds = List.filled(7, 0);

      // Calculate week start (Monday)
      final mondayOfWeek = now.subtract(Duration(days: now.weekday - 1));

      for (int i = 0; i < 7; i++) {
        final day = mondayOfWeek.add(Duration(days: i));
        final key = _dayKey(day);
        final seconds = (thisWeekData[key] as num?)?.toInt() ?? 0;
        weekDaySeconds[i] = seconds;
        thisWeekSeconds += seconds;
      }

      return {
        'totalSeconds': totalSeconds,
        'totalHours': (totalSeconds / 3600).toStringAsFixed(1),
        'totalSessions': totalSessions,
        'videosWatched': videosWatched,
        'quizzesTaken': quizzesTaken,
        'assignmentsDone': assignmentsDone,
        'thisWeekSeconds': thisWeekSeconds,
        'thisWeekHours': (thisWeekSeconds / 3600).toStringAsFixed(1),
        'weekDaySeconds': weekDaySeconds,
        'lastActiveAt': data['lastActiveAt'],
      };
    } catch (e) {
      debugPrint('Error getting learning stats: $e');
      return _emptyStats();
    }
  }

  /// Stream of learning stats for real-time UI updates.
  Stream<Map<String, dynamic>> statsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(_emptyStats());

    return _db.child('learning_stats').child(uid).onValue.map((event) {
      if (event.snapshot.value == null) return _emptyStats();

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final totalSeconds = (data['totalSeconds'] as num?)?.toInt() ?? 0;
      final totalSessions = (data['totalSessions'] as num?)?.toInt() ?? 0;

      final activityCounts = Map<String, dynamic>.from(
        (data['activityCounts'] as Map?) ?? {},
      );

      return {
        'totalSeconds': totalSeconds,
        'totalHours': (totalSeconds / 3600).toStringAsFixed(1),
        'totalSessions': totalSessions,
        'videosWatched': (activityCounts['video'] as num?)?.toInt() ?? 0,
        'quizzesTaken': (activityCounts['quiz'] as num?)?.toInt() ?? 0,
        'assignmentsDone': (activityCounts['assignment'] as num?)?.toInt() ?? 0,
        'lastActiveAt': data['lastActiveAt'],
      };
    });
  }

  String _weekKey(DateTime d) {
    // ISO week: Monday-based
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return '${monday.year}-W${_weekNumber(monday).toString().padLeft(2, '0')}';
  }

  int _weekNumber(DateTime d) {
    final firstDayOfYear = DateTime(d.year, 1, 1);
    final diff = d.difference(firstDayOfYear).inDays;
    return ((diff + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  String _dayKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _emptyStats() {
    return {
      'totalSeconds': 0,
      'totalHours': '0.0',
      'totalSessions': 0,
      'videosWatched': 0,
      'quizzesTaken': 0,
      'assignmentsDone': 0,
      'thisWeekSeconds': 0,
      'thisWeekHours': '0.0',
      'weekDaySeconds': List.filled(7, 0),
      'lastActiveAt': null,
    };
  }
}
