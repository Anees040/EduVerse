import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Recommends courses based on the student's enrolled course categories,
/// ratings, and popularity. Uses a simple collaborative-filtering approach:
/// "students who liked X also liked Y".
class CourseRecommendationService {
  static final CourseRecommendationService _instance =
      CourseRecommendationService._internal();
  factory CourseRecommendationService() => _instance;
  CourseRecommendationService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Get recommended courses for the current student.
  /// Returns up to [limit] courses sorted by relevance score.
  Future<List<Map<String, dynamic>>> getRecommendations({
    int limit = 10,
  }) async {
    final uid = _uid;
    if (uid == null) return [];

    try {
      // 1. Get the student's enrolled courses
      final enrolledSnap = await _db
          .child('student')
          .child(uid)
          .child('enrolledCourses')
          .get();

      final Set<String> enrolledIds = {};
      final Map<String, int> categoryScores = {};

      if (enrolledSnap.exists && enrolledSnap.value != null) {
        final enrolled = Map<String, dynamic>.from(enrolledSnap.value as Map);
        enrolledIds.addAll(enrolled.keys);
      }

      // 2. Fetch all courses
      final coursesSnap = await _db.child('courses').get();
      if (!coursesSnap.exists || coursesSnap.value == null) return [];

      final allCourses = Map<String, dynamic>.from(coursesSnap.value as Map);

      // 3. Build category preference from enrolled courses
      for (final courseId in enrolledIds) {
        final courseData = allCourses[courseId];
        if (courseData is Map) {
          final category = (courseData['category'] ?? '').toString();
          if (category.isNotEmpty) {
            categoryScores[category] = (categoryScores[category] ?? 0) + 2;
          }
          // Boost related difficulty levels
          final difficulty = (courseData['difficulty'] ?? '').toString();
          if (difficulty.isNotEmpty) {
            categoryScores['_diff_$difficulty'] =
                (categoryScores['_diff_$difficulty'] ?? 0) + 1;
          }
        }
      }

      // 4. Score non-enrolled courses
      final List<Map<String, dynamic>> scored = [];

      for (final entry in allCourses.entries) {
        if (enrolledIds.contains(entry.key)) continue; // Skip enrolled
        if (entry.value is! Map) continue;

        final course = Map<String, dynamic>.from(entry.value as Map);
        // Skip unpublished or incomplete
        if (course['isPublished'] == false) continue;
        final title = (course['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;

        double score = 0;

        // Category match bonus
        final category = (course['category'] ?? '').toString();
        if (categoryScores.containsKey(category)) {
          score += categoryScores[category]! * 5.0;
        }

        // Difficulty match bonus
        final difficulty = (course['difficulty'] ?? '').toString();
        if (categoryScores.containsKey('_diff_$difficulty')) {
          score += categoryScores['_diff_$difficulty']! * 2.0;
        }

        // Popularity bonus (enrolled count)
        final enrolledCount =
            (course['enrolledCount'] as num?)?.toDouble() ?? 0;
        score += (enrolledCount * 0.5).clamp(0, 10);

        // Rating bonus
        if (course['reviews'] != null && course['reviews'] is Map) {
          final reviews = course['reviews'] as Map;
          double totalRating = 0;
          int reviewCount = 0;
          for (final r in reviews.values) {
            if (r is Map) {
              totalRating += (r['rating'] as num?)?.toDouble() ?? 0;
              reviewCount++;
            }
          }
          if (reviewCount > 0) {
            final avgRating = totalRating / reviewCount;
            score += avgRating * 2.0;
          }
        }

        // Recency bonus (newer courses get slight boost)
        final createdAt = (course['createdAt'] as num?)?.toInt() ?? 0;
        if (createdAt > 0) {
          final ageMs = DateTime.now().millisecondsSinceEpoch - createdAt;
          final ageDays = ageMs / (1000 * 60 * 60 * 24);
          if (ageDays < 30) score += 3.0; // New course bonus
          if (ageDays < 7) score += 2.0; // Very new bonus
        }

        // If no enrolled courses, give a base score to popular ones
        if (enrolledIds.isEmpty) {
          score = enrolledCount * 1.0 + 5.0;
        }

        course['courseUid'] = entry.key;
        course['_score'] = score;
        scored.add(course);
      }

      // 5. Sort by score descending
      scored.sort(
        (a, b) => (b['_score'] as double).compareTo(a['_score'] as double),
      );

      // 6. Return top N
      final results = scored.take(limit).toList();
      // Remove internal score field
      for (final r in results) {
        r.remove('_score');
      }

      return results;
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      return [];
    }
  }

  /// Get trending/popular courses (regardless of user preferences).
  Future<List<Map<String, dynamic>>> getTrendingCourses({int limit = 5}) async {
    try {
      final snapshot = await _db.child('courses').get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final courses = <Map<String, dynamic>>[];

      for (final entry in data.entries) {
        if (entry.value is! Map) continue;
        final course = Map<String, dynamic>.from(entry.value as Map);
        if (course['isPublished'] == false) continue;
        final title = (course['title'] ?? '').toString().trim();
        if (title.isEmpty) continue;

        course['courseUid'] = entry.key;

        // Count enrolled students
        int enrolled = 0;
        if (course['enrolledStudents'] is Map) {
          enrolled = (course['enrolledStudents'] as Map).length;
        }
        course['enrolledCount'] = enrolled;

        courses.add(course);
      }

      // Sort by enrollment count
      courses.sort((a, b) {
        final aCount = (a['enrolledCount'] as int?) ?? 0;
        final bCount = (b['enrolledCount'] as int?) ?? 0;
        return bCount.compareTo(aCount);
      });

      return courses.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting trending courses: $e');
      return [];
    }
  }
}
