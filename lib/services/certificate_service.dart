import 'package:firebase_database/firebase_database.dart';

/// Certificate & Badge Service - Handles automatic certificate generation and badge awards
class CertificateService {
  static final CertificateService _instance = CertificateService._internal();
  factory CertificateService() => _instance;
  CertificateService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Check and award certificate when course is completed
  /// Returns the certificate ID if newly awarded, null if already exists
  Future<String?> checkAndAwardCourseCertificate({
    required String studentId,
    required String courseId,
    required String courseName,
    required String studentName,
    required double completionPercentage,
  }) async {
    try {
      // Check if certificate already exists
      final existingCert = await _db
          .child('student')
          .child(studentId)
          .child('certificates')
          .orderByChild('courseId')
          .equalTo(courseId)
          .get();

      if (existingCert.exists && existingCert.value != null) {
        // Certificate already awarded
        return null;
      }

      // Only award if course is 100% complete
      if (completionPercentage < 1.0) return null;

      // Generate certificate
      final certRef = _db
          .child('student')
          .child(studentId)
          .child('certificates')
          .push();

      final certificateId = certRef.key!;
      final grade = _getGrade(completionPercentage);

      await certRef.set({
        'certificateId': certificateId,
        'courseId': courseId,
        'courseName': courseName,
        'studentName': studentName,
        'completionPercentage': completionPercentage,
        'grade': grade,
        'awardedAt': ServerValue.timestamp,
        'type': 'course_completion',
      });

      // Also check for badges
      await _checkAndAwardBadges(
        studentId: studentId,
        courseId: courseId,
        grade: grade,
      );

      return certificateId;
    } catch (e) {
      return null;
    }
  }

  /// Get performance grade based on completion
  String _getGrade(double percentage) {
    final perf = percentage * 100;
    if (perf >= 90) return 'Excellent';
    if (perf >= 80) return 'Very Good';
    if (perf >= 70) return 'Good';
    if (perf >= 60) return 'Satisfactory';
    return 'Pass';
  }

  /// Check and award badges based on achievements
  Future<void> _checkAndAwardBadges({
    required String studentId,
    required String courseId,
    required String grade,
  }) async {
    try {
      // Get current student data
      final studentSnap = await _db.child('student').child(studentId).get();
      if (!studentSnap.exists || studentSnap.value == null) return;

      // Count completed courses
      final certsSnap = await _db
          .child('student')
          .child(studentId)
          .child('certificates')
          .get();

      int completedCourses = 0;
      if (certsSnap.exists && certsSnap.value != null) {
        final certs = Map<String, dynamic>.from(certsSnap.value as Map);
        completedCourses = certs.length;
      }

      // Award badges based on achievements
      final badges = <Map<String, dynamic>>[];

      // First Course Badge
      if (completedCourses == 1) {
        badges.add({
          'badgeId': 'first_course',
          'name': 'First Steps',
          'description': 'Completed your first course!',
          'icon': 'school',
          'color': '#4CAF50',
        });
      }

      // Excellence Badge
      if (grade == 'Excellent') {
        badges.add({
          'badgeId': 'excellence_$courseId',
          'name': 'Excellence Award',
          'description': 'Achieved Excellent grade in a course',
          'icon': 'star',
          'color': '#FFD700',
        });
      }

      // Course Collector Badges
      if (completedCourses == 5) {
        badges.add({
          'badgeId': 'five_courses',
          'name': 'Course Collector',
          'description': 'Completed 5 courses!',
          'icon': 'collections_bookmark',
          'color': '#2196F3',
        });
      }

      if (completedCourses == 10) {
        badges.add({
          'badgeId': 'ten_courses',
          'name': 'Knowledge Seeker',
          'description': 'Completed 10 courses!',
          'icon': 'psychology',
          'color': '#9C27B0',
        });
      }

      // Award badges
      for (final badge in badges) {
        await _awardBadge(studentId, badge);
      }
    } catch (e) {
      // Badge awarding is non-critical
    }
  }

  /// Award a badge to a student
  Future<bool> _awardBadge(String studentId, Map<String, dynamic> badge) async {
    try {
      // Check if badge already exists
      final existingBadge = await _db
          .child('student')
          .child(studentId)
          .child('badges')
          .child(badge['badgeId'])
          .get();

      if (existingBadge.exists) return false;

      // Award badge
      await _db
          .child('student')
          .child(studentId)
          .child('badges')
          .child(badge['badgeId'])
          .set({...badge, 'awardedAt': ServerValue.timestamp});

      // Send notification
      await _db.child('notifications').child(studentId).push().set({
        'title': '🏆 New Badge Earned!',
        'message':
            'You earned the "${badge['name']}" badge: ${badge['description']}',
        'type': 'badge',
        'badgeId': badge['badgeId'],
        'createdAt': ServerValue.timestamp,
        'read': false,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all certificates for a student
  Future<List<Map<String, dynamic>>> getStudentCertificates(
    String studentId,
  ) async {
    try {
      final snapshot = await _db
          .child('student')
          .child(studentId)
          .child('certificates')
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data.entries.map((e) {
        final cert = Map<String, dynamic>.from(e.value as Map);
        cert['id'] = e.key;
        return cert;
      }).toList()..sort((a, b) {
        final aTime = a['awardedAt'] ?? 0;
        final bTime = b['awardedAt'] ?? 0;
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      return [];
    }
  }

  /// Get all badges for a student
  Future<List<Map<String, dynamic>>> getStudentBadges(String studentId) async {
    try {
      final snapshot = await _db
          .child('student')
          .child(studentId)
          .child('badges')
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return data.entries.map((e) {
        final badge = Map<String, dynamic>.from(e.value as Map);
        badge['id'] = e.key;
        return badge;
      }).toList()..sort((a, b) {
        final aTime = a['awardedAt'] ?? 0;
        final bTime = b['awardedAt'] ?? 0;
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      return [];
    }
  }

  /// Check if student has certificate for a course
  Future<bool> hasCertificate(String studentId, String courseId) async {
    try {
      final snapshot = await _db
          .child('student')
          .child(studentId)
          .child('certificates')
          .orderByChild('courseId')
          .equalTo(courseId)
          .get();

      return snapshot.exists && snapshot.value != null;
    } catch (e) {
      return false;
    }
  }

  /// Award certificate for quiz completion
  Future<String?> awardQuizCertificate({
    required String studentId,
    required String quizId,
    required String quizTitle,
    required String studentName,
    required double score,
  }) async {
    try {
      // Only award if score is passing (>=60%)
      if (score < 0.6) return null;

      // Check if already awarded
      final existing = await _db
          .child('student')
          .child(studentId)
          .child('certificates')
          .orderByChild('quizId')
          .equalTo(quizId)
          .get();

      if (existing.exists && existing.value != null) return null;

      final certRef = _db
          .child('student')
          .child(studentId)
          .child('certificates')
          .push();

      final certificateId = certRef.key!;

      await certRef.set({
        'certificateId': certificateId,
        'quizId': quizId,
        'quizTitle': quizTitle,
        'studentName': studentName,
        'score': score,
        'grade': _getGrade(score),
        'awardedAt': ServerValue.timestamp,
        'type': 'quiz_completion',
      });

      // Send notification
      await _db.child('notifications').child(studentId).push().set({
        'title': '📜 Certificate Earned!',
        'message':
            'Congratulations! You earned a certificate for completing "$quizTitle"',
        'type': 'certificate',
        'certificateId': certificateId,
        'createdAt': ServerValue.timestamp,
        'read': false,
      });

      return certificateId;
    } catch (e) {
      return null;
    }
  }
}
