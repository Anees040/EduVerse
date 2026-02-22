import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Allows students to take personal notes per course (and optionally per video).
/// Data stored under /course_notes/{uid}/{courseId} in Firebase RTDB.
class CourseNotesService {
  static final CourseNotesService _instance = CourseNotesService._internal();
  factory CourseNotesService() => _instance;
  CourseNotesService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Add or update a note for a course.
  /// If [videoId] is provided, the note is tied to a specific video.
  Future<String?> saveNote({
    required String courseId,
    required String content,
    String? videoId,
    String? title,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final noteRef = _db
          .child('course_notes')
          .child(uid)
          .child(courseId)
          .push();

      await noteRef.set({
        'noteId': noteRef.key,
        'content': content,
        'title': title ?? '',
        'videoId': videoId ?? '',
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      return noteRef.key;
    } catch (e) {
      debugPrint('Error saving note: $e');
      return null;
    }
  }

  /// Update an existing note.
  Future<bool> updateNote({
    required String courseId,
    required String noteId,
    required String content,
    String? title,
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      await _db
          .child('course_notes')
          .child(uid)
          .child(courseId)
          .child(noteId)
          .update({
            'content': content,
            if (title != null) 'title': title,
            'updatedAt': ServerValue.timestamp,
          });
      return true;
    } catch (e) {
      debugPrint('Error updating note: $e');
      return false;
    }
  }

  /// Delete a note.
  Future<bool> deleteNote({
    required String courseId,
    required String noteId,
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      await _db
          .child('course_notes')
          .child(uid)
          .child(courseId)
          .child(noteId)
          .remove();
      return true;
    } catch (e) {
      debugPrint('Error deleting note: $e');
      return false;
    }
  }

  /// Get all notes for a course (sorted by creation time desc).
  Future<List<Map<String, dynamic>>> getCourseNotes(String courseId) async {
    final uid = _uid;
    if (uid == null) return [];

    try {
      final snapshot = await _db
          .child('course_notes')
          .child(uid)
          .child(courseId)
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final notes = data.entries.map((e) {
        final note = Map<String, dynamic>.from(e.value as Map);
        note['noteId'] = e.key;
        return note;
      }).toList();

      // Sort newest first
      notes.sort((a, b) {
        final aTime = a['updatedAt'] ?? a['createdAt'] ?? 0;
        final bTime = b['updatedAt'] ?? b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return notes;
    } catch (e) {
      debugPrint('Error getting course notes: $e');
      return [];
    }
  }

  /// Get notes for a specific video within a course.
  Future<List<Map<String, dynamic>>> getVideoNotes(
    String courseId,
    String videoId,
  ) async {
    final notes = await getCourseNotes(courseId);
    return notes.where((n) => n['videoId'] == videoId).toList();
  }

  /// Get total note count across all courses.
  Future<int> getTotalNoteCount() async {
    final uid = _uid;
    if (uid == null) return 0;

    try {
      final snapshot = await _db.child('course_notes').child(uid).get();
      if (!snapshot.exists || snapshot.value == null) return 0;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int total = 0;
      for (final courseEntry in data.values) {
        if (courseEntry is Map) {
          total += courseEntry.length;
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Stream of notes for a course (real-time updates).
  Stream<List<Map<String, dynamic>>> courseNotesStream(String courseId) {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _db.child('course_notes').child(uid).child(courseId).onValue.map((
      event,
    ) {
      if (event.snapshot.value == null) return <Map<String, dynamic>>[];

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final notes = data.entries.map((e) {
        final note = Map<String, dynamic>.from(e.value as Map);
        note['noteId'] = e.key;
        return note;
      }).toList();

      notes.sort((a, b) {
        final aTime = a['updatedAt'] ?? a['createdAt'] ?? 0;
        final bTime = b['updatedAt'] ?? b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return notes;
    });
  }
}
