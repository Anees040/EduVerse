import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/services/notification_service.dart';
import '../models/user_model.dart';

class UserService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  /// Get user once
  Future<Map<String, dynamic>?> getUser({
    required String uid,
    required String role,
  }) async {
    final snapshot = await _db.child(role).child(uid).get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final Map<dynamic, dynamic> rawData =
        snapshot.value as Map<dynamic, dynamic>;

    // Convert to Map<String, dynamic>
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(rawData);


    return data;
  }


  /// Listen to user changes (real-time)
  Stream<AppUser?> streamUser(String uid) {
    return _db.child(uid).onValue.map((event) {
      if (!event.snapshot.exists) return null;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return AppUser.fromMap(uid, data);
    });
  }
  
  /// Get user name
  Future<String?> getUserName({required String uid, required String role}) async {
    final snapshot = await _db.child(role).child(uid).child("name").get();

    if (!snapshot.exists) return null;

    return snapshot.value as String;
  }

  /// Update name
  Future<void> updateName(String uid, String name) async {
    await _db.child(uid).update({
      "name": name,
    });
  }

  /// Update user name by role
  Future<void> updateUserName({
    required String uid,
    required String role,
    required String name,
  }) async {
    await _db.child(role).child(uid).update({
      "name": name,
    });
  }

  /// Save image/video url to firebase database
  Future<void> saveCourseTofirebase(
    {
      required String teacherUid,
      required String title, 
      required String description, 
      required String imageUrl, 
      required String videoUrl, 
    }
  ) async {
    final DatabaseReference teachercourseRef =
      _db.child("teacher").child(teacherUid).child("courses").push();

    final DatabaseReference courseRef =
      _db.child("courses").child(teachercourseRef.key!);

      final String teachercourseUid = teachercourseRef.key!;  

      await teachercourseRef.set({
        "courseUid": teachercourseUid,
        "title": title,
        "description": description,
        "imageUrl": imageUrl,
        "videoUrl": videoUrl,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      });
      
      await courseRef.set({
        "teacherUid": teacherUid,
        "courseUid": teachercourseUid,
        "title": title,
        "description": description,
        "imageUrl": imageUrl,
        "videoUrl": videoUrl,
        "createdAt": DateTime.now().millisecondsSinceEpoch,
      });
      
      // Get teacher name and notify all students about new course
      // Wrapped in try-catch so notification failure doesn't break course creation
      try {
        final teacherSnapshot = await _db.child("teacher").child(teacherUid).get();
        String teacherName = "Instructor";
        if (teacherSnapshot.exists && teacherSnapshot.value != null) {
          final teacherData = Map<String, dynamic>.from(teacherSnapshot.value as Map);
          teacherName = teacherData['name'] ?? "Instructor";
        }
        
        await _notificationService.notifyAllStudentsOfNewCourse(
          teacherName: teacherName,
          courseName: title,
          courseId: teachercourseUid,
          teacherUid: teacherUid,
        );
      } catch (e) {
        // Log but don't fail course creation
        print('Failed to send notifications: $e');
      }
  } 
}
