import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

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

  /// Get all notifications for a user
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String uid) {
    return _db
        .child('notifications')
        .child(uid)
        .orderByChild('createdAt')
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
      notifications.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));

      return notifications;
    });
  }

  /// Get unread notification count - without index query to avoid Firebase warning
  Stream<int> getUnreadCountStream(String uid) {
    return _db
        .child('notifications')
        .child(uid)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return 0;
      }
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      // Count unread notifications locally
      int unreadCount = 0;
      data.forEach((key, value) {
        if (value is Map && value['isRead'] != true) {
          unreadCount++;
        }
      });
      return unreadCount;
    });
  }

  /// Mark a notification as read
  Future<void> markAsRead(String uid, String notificationId) async {
    await _db
        .child('notifications')
        .child(uid)
        .child(notificationId)
        .child('isRead')
        .set(true);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String uid) async {
    final snapshot = await _db.child('notifications').child(uid).get();
    
    if (!snapshot.exists || snapshot.value == null) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    
    final updates = <String, dynamic>{};
    data.forEach((key, value) {
      updates['$key/isRead'] = true;
    });

    if (updates.isNotEmpty) {
      await _db.child('notifications').child(uid).update(updates);
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String uid, String notificationId) async {
    await _db
        .child('notifications')
        .child(uid)
        .child(notificationId)
        .remove();
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
      print('No students found to notify');
      return;
    }
    
    final students = Map<String, dynamic>.from(studentsSnapshot.value as Map);
    print('Notifying ${students.length} students about new course: $courseName');
    
    // Send notification to each student
    for (final studentUid in students.keys) {
      try {
        await sendNotification(
          toUid: studentUid,
          title: 'New Course Available! 🎓',
          message: '$teacherName just published "$courseName". Check it out!',
          type: 'new_course',
          relatedCourseId: courseId,
          fromUid: teacherUid,
        );
        print('Notification sent to student: $studentUid');
      } catch (e) {
        print('Failed to notify student $studentUid: $e');
      }
    }
  }
}
