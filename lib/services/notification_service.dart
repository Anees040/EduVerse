import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_database/firebase_database.dart';
import 'platform_settings_service.dart';

class NotificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ──────────── Notification Preferences ────────────

  /// Get user's notification preferences (muted types, snooze info)
  Future<Map<String, dynamic>> getNotificationPreferences(String uid) async {
    final snapshot =
        await _db.child('notification_preferences').child(uid).get();
    if (!snapshot.exists || snapshot.value == null) {
      return {'mutedTypes': <String>[], 'snoozeUntil': 0};
    }
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    // Parse mutedTypes — stored as a map { "type": true }
    final mutedRaw = data['mutedTypes'];
    List<String> mutedTypes = [];
    if (mutedRaw is Map) {
      mutedTypes = mutedRaw.keys
          .where((k) => mutedRaw[k] == true)
          .map((k) => k.toString())
          .toList();
    }
    final snoozeUntil = data['snoozeUntil'] is int ? data['snoozeUntil'] as int : 0;
    return {'mutedTypes': mutedTypes, 'snoozeUntil': snoozeUntil};
  }

  /// Set muted notification types for a user
  Future<void> setMutedTypes(String uid, List<String> mutedTypes) async {
    final Map<String, dynamic> mutedMap = {};
    for (final type in mutedTypes) {
      mutedMap[type] = true;
    }
    await _db
        .child('notification_preferences')
        .child(uid)
        .child('mutedTypes')
        .set(mutedMap);
  }

  /// Toggle a single notification type mute state
  Future<void> toggleMuteType(String uid, String type, bool muted) async {
    await _db
        .child('notification_preferences')
        .child(uid)
        .child('mutedTypes')
        .child(type)
        .set(muted ? true : null);
  }

  /// Snooze all notifications for a duration
  Future<void> snoozeNotifications(String uid, Duration duration) async {
    final snoozeUntil =
        DateTime.now().add(duration).millisecondsSinceEpoch;
    await _db
        .child('notification_preferences')
        .child(uid)
        .child('snoozeUntil')
        .set(snoozeUntil);
  }

  /// Cancel snooze
  Future<void> cancelSnooze(String uid) async {
    await _db
        .child('notification_preferences')
        .child(uid)
        .child('snoozeUntil')
        .remove();
  }

  /// Check if user has snoozed notifications
  Future<bool> isSnoozed(String uid) async {
    final snapshot = await _db
        .child('notification_preferences')
        .child(uid)
        .child('snoozeUntil')
        .get();
    if (!snapshot.exists || snapshot.value == null) return false;
    final snoozeUntil = snapshot.value as int;
    return DateTime.now().millisecondsSinceEpoch < snoozeUntil;
  }

  /// Check if a specific notification type is muted for a user
  Future<bool> isTypeMuted(String uid, String type) async {
    final snapshot = await _db
        .child('notification_preferences')
        .child(uid)
        .child('mutedTypes')
        .child(type)
        .get();
    return snapshot.exists && snapshot.value == true;
  }

  // ──────────── Core Notification Methods ────────────

  /// Send a notification to a specific user
  Future<void> sendNotification({
    required String toUid,
    required String title,
    required String message,
    required String type, // 'enrollment', 'course_update', 'general'
    String? relatedCourseId,
    String? fromUid,
    String? relatedVideoId,
    int? relatedVideoTimestamp,
  }) async {
    // Check if notifications are enabled in platform settings
    try {
      await PlatformSettingsService.instance.ensureLoaded();
      if (!PlatformSettingsService.instance.enableNotifications) {
        debugPrint('Notifications are disabled in platform settings. Skipping.');
        return;
      }
    } catch (e) {
      debugPrint('Failed to check notification settings: $e');
      // Continue sending if we can't check — fail-open
    }

    // Check user-level notification preferences (muted types & snooze)
    try {
      if (await isSnoozed(toUid)) {
        debugPrint('User $toUid has snoozed notifications. Skipping.');
        return;
      }
      if (await isTypeMuted(toUid, type)) {
        debugPrint('Notification type "$type" is muted for user $toUid. Skipping.');
        return;
      }
    } catch (e) {
      debugPrint('Failed to check user notification preferences: $e');
      // Continue sending if we can't check — fail-open
    }

    final notificationId = _db.push().key;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final notificationData = {
      'id': notificationId,
      'title': title,
      'message': message,
      'type': type,
      'relatedCourseId': relatedCourseId,
      'relatedVideoId': relatedVideoId,
      'relatedVideoTimestamp': relatedVideoTimestamp,
      'fromUid': fromUid,
      'createdAt': timestamp,
      'isRead': false,
    };

    await _db
        .child('notifications')
        .child(toUid)
        .child(notificationId!)
        .set(notificationData);
  }

  /// Get all notifications for a user (limited to last 100 for scalability)
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String uid) {
    return _db
        .child('notifications')
        .child(uid)
        .orderByChild('createdAt')
        .limitToLast(100)
        .onValue
        .map((event) {
          if (!event.snapshot.exists || event.snapshot.value == null) {
            return [];
          }

          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final notifications = <Map<String, dynamic>>[];

          data.forEach((key, value) {
            notifications.add(Map<String, dynamic>.from(value));
          });

          // Sort by createdAt descending (newest first)
          notifications.sort(
            (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
          );

          return notifications;
        });
  }

  /// Get unread notification count — reuses the same query as getNotificationsStream
  /// to avoid a duplicate listener on the same node
  Stream<int> getUnreadCountStream(String uid) {
    return getNotificationsStream(uid).map((notifications) {
      return notifications.where((n) => n['isRead'] != true).length;
    });
  }

  /// Mark a notification as read
  Future<void> markAsRead(String uid, String notificationId) async {
    await _db
        .child('notifications')
        .child(uid)
        .child(notificationId)
        .update({'isRead': true, 'read': true});
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String uid) async {
    final snapshot = await _db.child('notifications').child(uid).get();

    if (!snapshot.exists || snapshot.value == null) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    final updates = <String, dynamic>{};
    data.forEach((key, value) {
      updates['$key/isRead'] = true;
      updates['$key/read'] = true;
    });

    if (updates.isNotEmpty) {
      await _db.child('notifications').child(uid).update(updates);
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String uid, String notificationId) async {
    await _db.child('notifications').child(uid).child(notificationId).remove();
  }

  /// Clear all notifications
  Future<void> clearAllNotifications(String uid) async {
    await _db.child('notifications').child(uid).remove();
  }

  /// Notify teacher when student enrolls in their course
  Future<void> notifyTeacherOfEnrollment({
    required String teacherUid,
    required String studentName,
    required String courseName,
    required String courseId,
    required String studentUid,
  }) async {
    await sendNotification(
      toUid: teacherUid,
      title: 'New Student Enrolled! 🎉',
      message: '$studentName enrolled in "$courseName"',
      type: 'enrollment',
      relatedCourseId: courseId,
      fromUid: studentUid,
    );
  }

  /// Notify student when teacher adds new video to enrolled course
  Future<void> notifyStudentOfNewVideo({
    required String studentUid,
    required String courseName,
    required String videoTitle,
    required String courseId,
    required String teacherUid,
  }) async {
    await sendNotification(
      toUid: studentUid,
      title: 'New Video Available! 📹',
      message: 'New video "$videoTitle" added to "$courseName"',
      type: 'course_update',
      relatedCourseId: courseId,
      fromUid: teacherUid,
    );
  }

  /// Notify all students when a teacher creates a new course
  Future<void> notifyAllStudentsOfNewCourse({
    required String teacherName,
    required String courseName,
    required String courseId,
    required String teacherUid,
  }) async {
    final DatabaseReference db = FirebaseDatabase.instance.ref();

    // Get all students
    final studentsSnapshot = await db.child('student').get();

    if (!studentsSnapshot.exists || studentsSnapshot.value == null) {
      debugPrint('No students found to notify');
      return;
    }

    // Get all teacher UIDs to exclude them from student notifications
    final teachersSnapshot = await db.child('teacher').get();
    final Set<String> teacherUids = {};
    if (teachersSnapshot.exists && teachersSnapshot.value != null) {
      final teachers = Map<String, dynamic>.from(teachersSnapshot.value as Map);
      teacherUids.addAll(teachers.keys);
    }

    final students = Map<String, dynamic>.from(studentsSnapshot.value as Map);
    debugPrint(
      'Notifying ${students.length} students about new course: $courseName',
    );

    // Send notification to each student (excluding all teachers)
    for (final studentUid in students.keys) {
      // Skip if this user is a teacher (might have accounts in both nodes)
      if (teacherUids.contains(studentUid)) continue;
      try {
        await sendNotification(
          toUid: studentUid,
          title: 'New Course Available! 🎓',
          message: '$teacherName just published "$courseName". Check it out!',
          type: 'new_course',
          relatedCourseId: courseId,
          fromUid: teacherUid,
        );
        debugPrint('Notification sent to student: $studentUid');
      } catch (e) {
        debugPrint('Failed to notify student $studentUid: $e');
      }
    }
  }
}
