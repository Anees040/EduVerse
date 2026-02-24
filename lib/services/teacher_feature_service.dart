import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service for teacher-specific features:
/// - Announcements to enrolled students
/// - Revenue tracking
/// - Course duplication
/// - Student progress reports
/// - Bulk course actions
class TeacherFeatureService {
  static final TeacherFeatureService _instance =
      TeacherFeatureService._internal();
  factory TeacherFeatureService() => _instance;
  TeacherFeatureService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ───────────────────────────────────────────────────────────
  // 1. ANNOUNCEMENTS
  // ───────────────────────────────────────────────────────────

  /// Send an announcement to all students enrolled in a specific course.
  Future<bool> sendCourseAnnouncement({
    required String courseId,
    required String courseTitle,
    required String message,
    String? announcementType, // 'general', 'assignment', 'update'
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      // Save announcement to course announcements node
      final announcementRef = _db
          .child('course_announcements')
          .child(courseId)
          .push();

      await announcementRef.set({
        'teacherId': uid,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'message': message,
        'type': announcementType ?? 'general',
        'createdAt': ServerValue.timestamp,
      });

      // Get enrolled students
      final enrolledSnap = await _db
          .child('courses')
          .child(courseId)
          .child('enrolledStudents')
          .get();

      if (enrolledSnap.exists && enrolledSnap.value != null) {
        final students = Map<String, dynamic>.from(enrolledSnap.value as Map);
        // Send notification to each student
        final futures = <Future>[];
        for (final studentId in students.keys) {
          futures.add(
            _db.child('notifications').child(studentId).push().set({
              'title': '📢 $courseTitle',
              'message': message,
              'type': 'announcement',
              'courseId': courseId,
              'createdAt': ServerValue.timestamp,
              'isRead': false,
            }),
          );
        }
        await Future.wait(futures);
      }

      return true;
    } catch (e) {
      debugPrint('Error sending announcement: $e');
      return false;
    }
  }

  /// Get all announcements for a course.
  Future<List<Map<String, dynamic>>> getCourseAnnouncements(
    String courseId,
  ) async {
    try {
      final snap = await _db
          .child('course_announcements')
          .child(courseId)
          .orderByChild('createdAt')
          .get();

      if (!snap.exists || snap.value == null) return [];

      final data = Map<String, dynamic>.from(snap.value as Map);
      final list = <Map<String, dynamic>>[];

      for (final entry in data.entries) {
        if (entry.value is Map) {
          list.add({
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          });
        }
      }

      // Sort newest first
      list.sort((a, b) {
        final aTime = (a['createdAt'] as num?)?.toInt() ?? 0;
        final bTime = (b['createdAt'] as num?)?.toInt() ?? 0;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────
  // 2. REVENUE TRACKING
  // ───────────────────────────────────────────────────────────

  /// Get revenue data for the teacher.
  Future<Map<String, dynamic>> getRevenueData() async {
    final uid = _uid;
    if (uid == null) return _emptyRevenue();

    try {
      // Get payments for this teacher
      final paymentsSnap = await _db
          .child('payments')
          .orderByChild('teacherId')
          .equalTo(uid)
          .get();

      double totalRevenue = 0;
      double thisMonthRevenue = 0;
      double lastMonthRevenue = 0;
      int totalTransactions = 0;
      final Map<String, double> courseRevenue = {};
      final Map<String, double> monthlyRevenue = {};

      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1)
          .millisecondsSinceEpoch;
      final lastMonthStart = DateTime(now.year, now.month - 1, 1)
          .millisecondsSinceEpoch;

      if (paymentsSnap.exists && paymentsSnap.value != null) {
        final payments = Map<String, dynamic>.from(paymentsSnap.value as Map);

        for (final entry in payments.entries) {
          if (entry.value is! Map) continue;
          final payment = Map<String, dynamic>.from(entry.value as Map);
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
          final timestamp = (payment['createdAt'] as num?)?.toInt() ?? 0;
          final courseId = payment['courseId'] as String? ?? 'unknown';

          totalRevenue += amount;
          totalTransactions++;

          // This month
          if (timestamp >= thisMonthStart) {
            thisMonthRevenue += amount;
          } else if (timestamp >= lastMonthStart &&
              timestamp < thisMonthStart) {
            lastMonthRevenue += amount;
          }

          // Per-course revenue
          courseRevenue[courseId] =
              (courseRevenue[courseId] ?? 0) + amount;

          // Monthly breakdown
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final monthKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlyRevenue[monthKey] =
              (monthlyRevenue[monthKey] ?? 0) + amount;
        }
      }

      // Also count free enrollments
      final coursesSnap = await _db
          .child('courses')
          .orderByChild('teacherUid')
          .equalTo(uid)
          .get();

      int totalEnrollments = 0;
      if (coursesSnap.exists && coursesSnap.value != null) {
        final courses = Map<String, dynamic>.from(coursesSnap.value as Map);
        for (final c in courses.values) {
          if (c is Map) {
            final enrolled = c['enrolledStudents'];
            if (enrolled is Map) {
              totalEnrollments += enrolled.length;
            }
          }
        }
      }

      return {
        'totalRevenue': totalRevenue,
        'thisMonthRevenue': thisMonthRevenue,
        'lastMonthRevenue': lastMonthRevenue,
        'totalTransactions': totalTransactions,
        'totalEnrollments': totalEnrollments,
        'courseRevenue': courseRevenue,
        'monthlyRevenue': monthlyRevenue,
        'growthPercent': lastMonthRevenue > 0
            ? ((thisMonthRevenue - lastMonthRevenue) /
                    lastMonthRevenue *
                    100)
                .toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      debugPrint('Error loading revenue: $e');
      return _emptyRevenue();
    }
  }

  Map<String, dynamic> _emptyRevenue() {
    return {
      'totalRevenue': 0.0,
      'thisMonthRevenue': 0.0,
      'lastMonthRevenue': 0.0,
      'totalTransactions': 0,
      'totalEnrollments': 0,
      'courseRevenue': <String, double>{},
      'monthlyRevenue': <String, double>{},
      'growthPercent': '0.0',
    };
  }

  // ───────────────────────────────────────────────────────────
  // 3. COURSE DUPLICATION
  // ───────────────────────────────────────────────────────────

  /// Duplicate an existing course (copies structure, videos, quizzes)
  Future<String?> duplicateCourse(String courseId) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final courseSnap = await _db.child('courses').child(courseId).get();
      if (!courseSnap.exists || courseSnap.value == null) return null;

      final original = Map<String, dynamic>.from(courseSnap.value as Map);

      // Remove enrollment and review data
      original.remove('enrolledStudents');
      original.remove('reviews');
      original.remove('enrolledCount');
      original.remove('courseRating');
      original.remove('courseReviewCount');

      // Update metadata
      original['title'] = '${original['title'] ?? 'Course'} (Copy)';
      original['createdAt'] = ServerValue.timestamp;
      original['isPublished'] = false;
      original['teacherUid'] = uid;

      // Create new course
      final newRef = _db.child('courses').push();
      await newRef.set(original);

      return newRef.key;
    } catch (e) {
      debugPrint('Error duplicating course: $e');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────
  // 4. STUDENT PROGRESS REPORTS
  // ───────────────────────────────────────────────────────────

  /// Get detailed progress for a student across all of teacher's courses.
  Future<Map<String, dynamic>> getStudentProgress({
    required String studentId,
    required String courseId,
  }) async {
    try {
      // Get student info
      final studentSnap = await _db.child('student').child(studentId).get();
      String studentName = 'Unknown Student';
      String? studentEmail;
      if (studentSnap.exists && studentSnap.value != null) {
        final data = Map<String, dynamic>.from(studentSnap.value as Map);
        studentName = data['name'] ?? 'Unknown';
        studentEmail = data['email'];
      }

      // Get course info
      final courseSnap = await _db.child('courses').child(courseId).get();
      if (!courseSnap.exists || courseSnap.value == null) {
        return {'studentName': studentName, 'courseTitle': 'Unknown'};
      }

      final courseData = Map<String, dynamic>.from(courseSnap.value as Map);
      final courseTitle = courseData['title'] ?? 'Untitled';

      // Get video progress
      int totalVideos = 0;
      int watchedVideos = 0;
      if (courseData['videos'] is Map) {
        final videos = Map<String, dynamic>.from(courseData['videos'] as Map);
        totalVideos = videos.length;

        // Check watched status
        final progressSnap = await _db
            .child('student')
            .child(studentId)
            .child('courseProgress')
            .child(courseId)
            .get();

        if (progressSnap.exists && progressSnap.value != null) {
          final progress = Map<String, dynamic>.from(
            progressSnap.value as Map,
          );
          watchedVideos = progress.length;
        }
      }

      // Get quiz scores
      final quizResults = <Map<String, dynamic>>[];
      final quizzesSnap = await _db
          .child('quiz_results')
          .child(courseId)
          .child(studentId)
          .get();

      if (quizzesSnap.exists && quizzesSnap.value != null) {
        final data = Map<String, dynamic>.from(quizzesSnap.value as Map);
        for (final entry in data.entries) {
          if (entry.value is Map) {
            quizResults.add({
              'quizId': entry.key,
              ...Map<String, dynamic>.from(entry.value as Map),
            });
          }
        }
      }

      // Get assignment submissions
      final assignmentSnap = await _db
          .child('assignment_submissions')
          .child(courseId)
          .child(studentId)
          .get();

      int assignmentsSubmitted = 0;
      if (assignmentSnap.exists && assignmentSnap.value != null) {
        final data = Map<String, dynamic>.from(assignmentSnap.value as Map);
        assignmentsSubmitted = data.length;
      }

      // Calculate completion percentage
      final completionPct = totalVideos > 0
          ? (watchedVideos / totalVideos * 100).round()
          : 0;

      // Average quiz score
      double avgQuizScore = 0;
      if (quizResults.isNotEmpty) {
        double totalScore = 0;
        for (final q in quizResults) {
          totalScore += (q['scorePercent'] as num?)?.toDouble() ?? 0;
        }
        avgQuizScore = totalScore / quizResults.length;
      }

      return {
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'totalVideos': totalVideos,
        'watchedVideos': watchedVideos,
        'completionPercent': completionPct,
        'quizResults': quizResults,
        'avgQuizScore': avgQuizScore.toStringAsFixed(1),
        'assignmentsSubmitted': assignmentsSubmitted,
      };
    } catch (e) {
      debugPrint('Error loading student progress: $e');
      return {};
    }
  }

  // ───────────────────────────────────────────────────────────
  // 5. COURSE ANALYTICS SUMMARY
  // ───────────────────────────────────────────────────────────

  /// Get engagement analytics for a specific course.
  Future<Map<String, dynamic>> getCourseEngagement(String courseId) async {
    try {
      final courseSnap = await _db.child('courses').child(courseId).get();
      if (!courseSnap.exists || courseSnap.value == null) return {};

      final courseData = Map<String, dynamic>.from(courseSnap.value as Map);

      // Enrolled count
      int enrolledCount = 0;
      if (courseData['enrolledStudents'] is Map) {
        enrolledCount =
            (courseData['enrolledStudents'] as Map).length;
      }

      // Reviews
      int reviewCount = 0;
      double avgRating = 0;
      if (courseData['reviews'] is Map) {
        final reviews = Map<String, dynamic>.from(courseData['reviews'] as Map);
        reviewCount = reviews.length;
        double totalRating = 0;
        for (final r in reviews.values) {
          if (r is Map) {
            totalRating += (r['rating'] as num?)?.toDouble() ?? 0;
          }
        }
        if (reviewCount > 0) avgRating = totalRating / reviewCount;
      }

      // Video count
      int videoCount = 0;
      if (courseData['videos'] is Map) {
        videoCount = (courseData['videos'] as Map).length;
      }

      // Q&A count
      int qaCount = 0;
      final qaSnap = await _db.child('qa').child(courseId).get();
      if (qaSnap.exists && qaSnap.value != null) {
        qaCount = (qaSnap.value as Map).length;
      }

      return {
        'courseId': courseId,
        'title': courseData['title'] ?? 'Untitled',
        'enrolledCount': enrolledCount,
        'reviewCount': reviewCount,
        'avgRating': avgRating.toStringAsFixed(1),
        'videoCount': videoCount,
        'qaCount': qaCount,
        'category': courseData['category'] ?? '',
        'isPublished': courseData['isPublished'] ?? false,
      };
    } catch (e) {
      debugPrint('Error loading course engagement: $e');
      return {};
    }
  }
}
