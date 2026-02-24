import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service backing 5 admin features:
/// 1. Platform Announcements — broadcast to all users
/// 2. Activity Audit Log — track admin actions
/// 3. Platform Settings — maintenance, registration, branding
/// 4. Bulk User Actions — batch suspend / unsuspend / delete
/// 5. Content Insights — course quality metrics, trending topics
class AdminFeatureService {
  final _db = FirebaseDatabase.instance.ref();

  // ──────────────────────── 1. Platform Announcements ────────────────────────

  /// Send a platform-wide announcement visible to everyone.
  Future<bool> sendPlatformAnnouncement({
    required String title,
    required String message,
    required String priority, // 'normal', 'important', 'urgent'
    required String targetAudience, // 'all', 'students', 'teachers'
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final ref = _db.child('platform_announcements').push();
      await ref.set({
        'id': ref.key,
        'title': title,
        'message': message,
        'priority': priority,
        'targetAudience': targetAudience,
        'sentBy': uid,
        'sentAt': ServerValue.timestamp,
        'isActive': true,
      });

      // Log the action
      await logAdminAction(
        action: 'send_announcement',
        details: 'Sent "$title" to $targetAudience',
      );

      return true;
    } catch (e) {
      debugPrint('Error sending announcement: $e');
      return false;
    }
  }

  /// Get all platform announcements, newest first.
  Future<List<Map<String, dynamic>>> getPlatformAnnouncements() async {
    try {
      final snap = await _db
          .child('platform_announcements')
          .orderByChild('sentAt')
          .limitToLast(50)
          .get();

      if (!snap.exists) return [];

      final list = <Map<String, dynamic>>[];
      final raw = snap.value;
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            list.add({...Map<String, dynamic>.from(value), 'id': key});
          }
        });
      }

      list.sort((a, b) =>
          ((b['sentAt'] as num?) ?? 0).compareTo((a['sentAt'] as num?) ?? 0));
      return list;
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      return [];
    }
  }

  /// Toggle announcement active status.
  Future<bool> toggleAnnouncementActive(String id, bool isActive) async {
    try {
      await _db.child('platform_announcements/$id/isActive').set(isActive);
      await logAdminAction(
        action: isActive ? 'activate_announcement' : 'deactivate_announcement',
        details: 'Announcement $id ${isActive ? "activated" : "deactivated"}',
      );
      return true;
    } catch (e) {
      debugPrint('Error toggling announcement: $e');
      return false;
    }
  }

  /// Delete an announcement.
  Future<bool> deleteAnnouncement(String id) async {
    try {
      await _db.child('platform_announcements/$id').remove();
      await logAdminAction(
        action: 'delete_announcement',
        details: 'Deleted announcement $id',
      );
      return true;
    } catch (e) {
      debugPrint('Error deleting announcement: $e');
      return false;
    }
  }

  // ──────────────────────── 2. Activity Audit Log ────────────────────────

  /// Log an admin action for the audit trail.
  Future<void> logAdminAction({
    required String action,
    required String details,
    String? targetUserId,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final ref = _db.child('admin_audit_log').push();
      await ref.set({
        'id': ref.key,
        'adminUid': uid,
        'action': action,
        'details': details,
        'targetUserId': targetUserId,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  /// Retrieve audit log entries (paginated, newest first).
  Future<List<Map<String, dynamic>>> getAuditLog({
    int limit = 50,
    String? filterAction,
  }) async {
    try {
      Query query = _db.child('admin_audit_log').orderByChild('timestamp');
      final snap = await query.limitToLast(limit).get();

      if (!snap.exists) return [];

      final list = <Map<String, dynamic>>[];
      final raw = snap.value;
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            final entry = {...Map<String, dynamic>.from(value), 'id': key};
            if (filterAction == null || entry['action'] == filterAction) {
              list.add(entry);
            }
          }
        });
      }

      list.sort((a, b) => ((b['timestamp'] as num?) ?? 0)
          .compareTo((a['timestamp'] as num?) ?? 0));
      return list;
    } catch (e) {
      debugPrint('Error loading audit log: $e');
      return [];
    }
  }

  // ──────────────────────── 3. Platform Settings ────────────────────────

  /// Get all platform settings.
  Future<Map<String, dynamic>> getPlatformSettings() async {
    try {
      final snap = await _db.child('platform_settings').get();
      if (!snap.exists) {
        // Return defaults
        return {
          'maintenanceMode': false,
          'registrationEnabled': true,
          'platformName': 'EduVerse',
          'maxUploadSizeMB': 100,
          'allowNewCourses': true,
          'requireEmailVerification': true,
          'maxCoursesPerTeacher': 20,
          'supportEmail': '',
        };
      }
      final raw = snap.value;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return {};
    } catch (e) {
      debugPrint('Error loading settings: $e');
      return {};
    }
  }

  /// Update a single platform setting.
  Future<bool> updatePlatformSetting(String key, dynamic value) async {
    try {
      await _db.child('platform_settings/$key').set(value);
      await logAdminAction(
        action: 'update_setting',
        details: 'Changed $key to $value',
      );
      return true;
    } catch (e) {
      debugPrint('Error updating setting: $e');
      return false;
    }
  }

  /// Update multiple settings at once.
  Future<bool> updatePlatformSettings(Map<String, dynamic> settings) async {
    try {
      await _db.child('platform_settings').update(settings);
      await logAdminAction(
        action: 'update_settings',
        details: 'Updated ${settings.length} settings',
      );
      return true;
    } catch (e) {
      debugPrint('Error updating settings: $e');
      return false;
    }
  }

  // ──────────────────────── 4. Bulk User Actions ────────────────────────

  /// Suspend multiple users at once.
  Future<Map<String, bool>> bulkSuspendUsers(
    List<Map<String, String>> users, // [{uid, role}]
    String reason,
  ) async {
    final results = <String, bool>{};
    for (final user in users) {
      try {
        final uid = user['uid']!;
        final role = user['role'] ?? 'student';
        final node = role == 'teacher' ? 'teacher' : 'student';
        await _db.child('$node/$uid/isSuspended').set(true);
        await _db.child('$node/$uid/suspendReason').set(reason);
        results[uid] = true;
      } catch (e) {
        results[user['uid'] ?? ''] = false;
      }
    }

    final successCount = results.values.where((v) => v).length;
    await logAdminAction(
      action: 'bulk_suspend',
      details: 'Suspended $successCount/${users.length} users. Reason: $reason',
    );
    return results;
  }

  /// Unsuspend multiple users at once.
  Future<Map<String, bool>> bulkUnsuspendUsers(
    List<Map<String, String>> users,
  ) async {
    final results = <String, bool>{};
    for (final user in users) {
      try {
        final uid = user['uid']!;
        final role = user['role'] ?? 'student';
        final node = role == 'teacher' ? 'teacher' : 'student';
        await _db.child('$node/$uid/isSuspended').set(false);
        await _db.child('$node/$uid/suspendReason').remove();
        results[uid] = true;
      } catch (e) {
        results[user['uid'] ?? ''] = false;
      }
    }

    final successCount = results.values.where((v) => v).length;
    await logAdminAction(
      action: 'bulk_unsuspend',
      details: 'Unsuspended $successCount/${users.length} users',
    );
    return results;
  }

  /// Export user list as CSV-compatible data.
  Future<List<Map<String, dynamic>>> exportUserData() async {
    try {
      final studentSnap = await _db.child('student').get();
      final teacherSnap = await _db.child('teacher').get();

      final users = <Map<String, dynamic>>[];

      void processSnap(DataSnapshot snap, String role) {
        if (!snap.exists) return;
        final raw = snap.value;
        if (raw is Map) {
          raw.forEach((key, value) {
            if (value is Map) {
              users.add({
                'uid': key,
                'role': role,
                'name': value['name'] ?? value['displayName'] ?? '',
                'email': value['email'] ?? '',
                'isSuspended': value['isSuspended'] ?? false,
                'joinedAt': value['createdAt'] ?? '',
              });
            }
          });
        }
      }

      processSnap(studentSnap, 'student');
      processSnap(teacherSnap, 'teacher');

      return users;
    } catch (e) {
      debugPrint('Error exporting users: $e');
      return [];
    }
  }

  // ──────────────────────── 5. Content Insights ────────────────────────

  /// Get platform-wide content insights.
  Future<Map<String, dynamic>> getContentInsights() async {
    try {
      final coursesSnap = await _db.child('courses').get();

      int totalCourses = 0;
      int publishedCourses = 0;
      int draftCourses = 0;
      int totalVideos = 0;
      int totalQuizzes = 0;
      double totalRating = 0;
      int ratedCourses = 0;
      final categoryCount = <String, int>{};
      final topCourses = <Map<String, dynamic>>[];

      if (coursesSnap.exists && coursesSnap.value is Map) {
        final courses = coursesSnap.value as Map;
        courses.forEach((key, value) {
          if (value is Map) {
            totalCourses++;

            final isPublished = value['isPublished'] == true;
            if (isPublished) {
              publishedCourses++;
            } else {
              draftCourses++;
            }

            // Count videos
            if (value['videos'] is Map) {
              totalVideos += (value['videos'] as Map).length;
            }

            // Count quizzes
            if (value['quizzes'] is Map) {
              totalQuizzes += (value['quizzes'] as Map).length;
            }

            // Rating
            final rating = (value['averageRating'] as num?)?.toDouble() ?? 0;
            if (rating > 0) {
              totalRating += rating;
              ratedCourses++;
            }

            // Category
            final category =
                value['category'] as String? ?? 'Uncategorized';
            categoryCount[category] =
                (categoryCount[category] ?? 0) + 1;

            // Collect for top courses
            final enrolled =
                (value['enrolledStudents'] as num?)?.toInt() ?? 0;
            topCourses.add({
              'courseId': key,
              'title': value['title'] ?? 'Untitled',
              'enrolled': enrolled,
              'rating': rating,
              'category': category,
              'isPublished': isPublished,
            });
          }
        });
      }

      // Sort top courses by enrollment
      topCourses.sort(
          (a, b) => (b['enrolled'] as int).compareTo(a['enrolled'] as int));

      return {
        'totalCourses': totalCourses,
        'publishedCourses': publishedCourses,
        'draftCourses': draftCourses,
        'totalVideos': totalVideos,
        'totalQuizzes': totalQuizzes,
        'averageRating':
            ratedCourses > 0 ? (totalRating / ratedCourses).toStringAsFixed(1) : '0.0',
        'categoryBreakdown': categoryCount,
        'topCourses': topCourses.take(10).toList(),
      };
    } catch (e) {
      debugPrint('Error loading content insights: $e');
      return {};
    }
  }
}
