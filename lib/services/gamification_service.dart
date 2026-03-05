import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Gamification service — XP, Levels, and Achievement Badges.
/// Data stored under /gamification/{uid} in Firebase RTDB.
///
/// XP Awards:
///   - Watch video:      10 XP
///   - Complete quiz:    25 XP
///   - Submit assignment:20 XP
///   - Complete course: 100 XP
///   - Daily streak:      5 XP (recorded once per day)
///   - First activity of the day: 5 XP bonus
///
/// Levels use a gentle exponential curve so every player feels progress.
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ──────────── XP Constants ────────────

  static const int xpVideo = 10;
  static const int xpQuiz = 25;
  static const int xpAssignment = 20;
  static const int xpCourseComplete = 100;
  static const int xpDailyStreak = 5;
  static const int xpFirstActivityBonus = 5;

  // ──────────── Level Thresholds ────────────

  /// Returns the total XP required to reach the given level.
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    if (level == 2) return 100;
    if (level == 3) return 250;
    if (level == 4) return 500;
    if (level == 5) return 1000;
    if (level == 6) return 1750;
    if (level == 7) return 2750;
    if (level == 8) return 4000;
    if (level == 9) return 5500;
    if (level == 10) return 7500;
    // Level 11+: 7500 + 2500 per additional level
    return 7500 + (level - 10) * 2500;
  }

  /// Compute the user's level from total XP.
  static int levelFromXP(int totalXP) {
    int level = 1;
    while (xpForLevel(level + 1) <= totalXP) {
      level++;
    }
    return level;
  }

  /// Human‐readable level title.
  static String levelTitle(int level) {
    if (level <= 1) return 'Beginner';
    if (level == 2) return 'Learner';
    if (level == 3) return 'Explorer';
    if (level == 4) return 'Achiever';
    if (level == 5) return 'Scholar';
    if (level == 6) return 'Expert';
    if (level == 7) return 'Master';
    if (level == 8) return 'Guru';
    if (level == 9) return 'Legend';
    if (level >= 10) return 'Grandmaster';
    return 'Learner';
  }

  /// Progress fraction inside the current level (0.0 – 1.0).
  static double levelProgress(int totalXP) {
    final level = levelFromXP(totalXP);
    final currentThreshold = xpForLevel(level);
    final nextThreshold = xpForLevel(level + 1);
    if (nextThreshold == currentThreshold) return 1.0;
    return (totalXP - currentThreshold) / (nextThreshold - currentThreshold);
  }

  // ──────────── Badge Definitions ────────────

  static const List<Map<String, dynamic>> badgeDefinitions = [
    {
      'id': 'first_steps',
      'name': 'First Steps',
      'description': 'Complete your first learning activity',
      'icon': '🎯',
      'category': 'milestone',
    },
    {
      'id': 'curious_mind',
      'name': 'Curious Mind',
      'description': 'Watch 5 videos',
      'icon': '🧠',
      'category': 'video',
    },
    {
      'id': 'video_binge',
      'name': 'Video Binge',
      'description': 'Watch 25 videos',
      'icon': '🎬',
      'category': 'video',
    },
    {
      'id': 'quiz_whiz',
      'name': 'Quiz Whiz',
      'description': 'Complete 5 quizzes',
      'icon': '⚡',
      'category': 'quiz',
    },
    {
      'id': 'quiz_master',
      'name': 'Quiz Master',
      'description': 'Complete 25 quizzes',
      'icon': '🏆',
      'category': 'quiz',
    },
    {
      'id': 'homework_hero',
      'name': 'Homework Hero',
      'description': 'Submit 5 assignments',
      'icon': '📝',
      'category': 'assignment',
    },
    {
      'id': 'dedicated_learner',
      'name': 'Dedicated Learner',
      'description': 'Study for 10 hours total',
      'icon': '📚',
      'category': 'time',
    },
    {
      'id': 'knowledge_seeker',
      'name': 'Knowledge Seeker',
      'description': 'Study for 50 hours total',
      'icon': '🔬',
      'category': 'time',
    },
    {
      'id': 'on_fire',
      'name': 'On Fire',
      'description': 'Achieve a 7‑day study streak',
      'icon': '🔥',
      'category': 'streak',
    },
    {
      'id': 'unstoppable',
      'name': 'Unstoppable',
      'description': 'Achieve a 30‑day study streak',
      'icon': '💎',
      'category': 'streak',
    },
    {
      'id': 'course_completer',
      'name': 'Course Completer',
      'description': 'Complete your first course',
      'icon': '🎓',
      'category': 'course',
    },
    {
      'id': 'overachiever',
      'name': 'Overachiever',
      'description': 'Complete 5 courses',
      'icon': '🌟',
      'category': 'course',
    },
    {
      'id': 'scholar',
      'name': 'Scholar',
      'description': 'Reach Level 5',
      'icon': '🎖️',
      'category': 'level',
    },
    {
      'id': 'expert',
      'name': 'Expert',
      'description': 'Reach Level 10',
      'icon': '👑',
      'category': 'level',
    },
  ];

  // ──────────── Award XP ────────────

  /// Central method that awards XP then checks for new badges.
  /// Returns a list of newly unlocked badge IDs (may be empty).
  Future<List<String>> awardXP({
    required int amount,
    required String reason, // 'video', 'quiz', 'assignment', 'course', 'streak'
  }) async {
    final uid = _uid;
    if (uid == null || amount <= 0) return [];

    try {
      final ref = _db.child('gamification').child(uid);
      final snapshot = await ref.get();
      Map<String, dynamic> data = {};
      if (snapshot.exists && snapshot.value != null) {
        data = Map<String, dynamic>.from(snapshot.value as Map);
      }

      int totalXP = (data['totalXP'] as num?)?.toInt() ?? 0;
      final today = _todayKey();
      final lastActivityDate = data['lastActivityDate'] as String?;

      // First‐activity‐of‐the‐day bonus
      int bonus = 0;
      if (lastActivityDate != today) {
        bonus = xpFirstActivityBonus;
      }

      totalXP += amount + bonus;

      // Increment per‐reason counter
      final counters =
          Map<String, dynamic>.from((data['counters'] as Map?) ?? {});
      counters[reason] = ((counters[reason] as num?)?.toInt() ?? 0) + 1;

      final level = levelFromXP(totalXP);

      await ref.update({
        'totalXP': totalXP,
        'level': level,
        'counters': counters,
        'lastActivityDate': today,
        'updatedAt': ServerValue.timestamp,
      });

      // Check for new badges
      final newBadges = await _checkBadges(ref, data, totalXP, counters);

      return newBadges;
    } catch (e) {
      debugPrint('GamificationService.awardXP error: $e');
      return [];
    }
  }

  // ──────────── Badge Checking ────────────

  Future<List<String>> _checkBadges(
    DatabaseReference ref,
    Map<String, dynamic> data,
    int totalXP,
    Map<String, dynamic> counters,
  ) async {
    final existing = Map<String, dynamic>.from(
      (data['badges'] as Map?) ?? {},
    );

    final List<String> newlyUnlocked = [];

    bool has(String id) => existing.containsKey(id);
    int count(String key) => (counters[key] as num?)?.toInt() ?? 0;

    // Total activities = sum of all counters
    final totalActivities =
        counters.values.fold<int>(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 0));

    // Milestone
    if (!has('first_steps') && totalActivities >= 1) {
      newlyUnlocked.add('first_steps');
    }

    // Video
    if (!has('curious_mind') && count('video') >= 5) {
      newlyUnlocked.add('curious_mind');
    }
    if (!has('video_binge') && count('video') >= 25) {
      newlyUnlocked.add('video_binge');
    }

    // Quiz
    if (!has('quiz_whiz') && count('quiz') >= 5) {
      newlyUnlocked.add('quiz_whiz');
    }
    if (!has('quiz_master') && count('quiz') >= 25) {
      newlyUnlocked.add('quiz_master');
    }

    // Assignment
    if (!has('homework_hero') && count('assignment') >= 5) {
      newlyUnlocked.add('homework_hero');
    }

    // Course
    if (!has('course_completer') && count('course') >= 1) {
      newlyUnlocked.add('course_completer');
    }
    if (!has('overachiever') && count('course') >= 5) {
      newlyUnlocked.add('overachiever');
    }

    // Level
    final level = levelFromXP(totalXP);
    if (!has('scholar') && level >= 5) {
      newlyUnlocked.add('scholar');
    }
    if (!has('expert') && level >= 10) {
      newlyUnlocked.add('expert');
    }

    // Streak — check from Firebase /study_streaks/{uid}
    try {
      final uid = _uid;
      if (uid != null) {
        final streakSnap =
            await _db.child('study_streaks').child(uid).child('currentStreak').get();
        final currentStreak = (streakSnap.value as num?)?.toInt() ?? 0;
        if (!has('on_fire') && currentStreak >= 7) {
          newlyUnlocked.add('on_fire');
        }
        if (!has('unstoppable') && currentStreak >= 30) {
          newlyUnlocked.add('unstoppable');
        }
      }
    } catch (_) {}

    // Time‐based — check from /learning_stats/{uid}
    try {
      final uid = _uid;
      if (uid != null) {
        final statsSnap =
            await _db.child('learning_stats').child(uid).child('totalSeconds').get();
        final totalSeconds = (statsSnap.value as num?)?.toInt() ?? 0;
        final totalHours = totalSeconds / 3600;
        if (!has('dedicated_learner') && totalHours >= 10) {
          newlyUnlocked.add('dedicated_learner');
        }
        if (!has('knowledge_seeker') && totalHours >= 50) {
          newlyUnlocked.add('knowledge_seeker');
        }
      }
    } catch (_) {}

    // Save newly unlocked badges
    if (newlyUnlocked.isNotEmpty) {
      final Map<String, dynamic> updates = {};
      for (final id in newlyUnlocked) {
        updates['badges/$id'] = DateTime.now().millisecondsSinceEpoch;
      }
      await ref.update(updates);
    }

    return newlyUnlocked;
  }

  // ──────────── Read Data ────────────

  /// Get the full gamification profile for the current user.
  Future<Map<String, dynamic>> getProfile() async {
    final uid = _uid;
    if (uid == null) return _emptyProfile();

    try {
      final snapshot = await _db.child('gamification').child(uid).get();
      if (!snapshot.exists || snapshot.value == null) return _emptyProfile();
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return _normalize(data);
    } catch (e) {
      debugPrint('GamificationService.getProfile error: $e');
      return _emptyProfile();
    }
  }

  /// Real‐time stream of the gamification profile.
  Stream<Map<String, dynamic>> profileStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(_emptyProfile());

    return _db.child('gamification').child(uid).onValue.map((event) {
      if (event.snapshot.value == null) return _emptyProfile();
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return _normalize(data);
    });
  }

  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final totalXP = (data['totalXP'] as num?)?.toInt() ?? 0;
    final level = levelFromXP(totalXP);
    final badges =
        Map<String, dynamic>.from((data['badges'] as Map?) ?? {});
    final counters =
        Map<String, dynamic>.from((data['counters'] as Map?) ?? {});

    return {
      'totalXP': totalXP,
      'level': level,
      'levelTitle': levelTitle(level),
      'levelProgress': levelProgress(totalXP),
      'xpForNextLevel': xpForLevel(level + 1),
      'xpInCurrentLevel': totalXP - xpForLevel(level),
      'xpNeededForNext': xpForLevel(level + 1) - xpForLevel(level),
      'badges': badges,
      'badgeCount': badges.length,
      'counters': counters,
    };
  }

  Map<String, dynamic> _emptyProfile() => {
        'totalXP': 0,
        'level': 1,
        'levelTitle': 'Beginner',
        'levelProgress': 0.0,
        'xpForNextLevel': 100,
        'xpInCurrentLevel': 0,
        'xpNeededForNext': 100,
        'badges': <String, dynamic>{},
        'badgeCount': 0,
        'counters': <String, dynamic>{},
      };

  // ──────────── Helpers ────────────

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Convenience: find badge definition by id.
  static Map<String, dynamic>? getBadgeDefinition(String id) {
    try {
      return badgeDefinitions.firstWhere((b) => b['id'] == id);
    } catch (_) {
      return null;
    }
  }
}
