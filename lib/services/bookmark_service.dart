import 'package:firebase_database/firebase_database.dart';

/// Bookmark Service - Handles saving courses/videos for later
class BookmarkService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Add a course to bookmarks
  Future<void> bookmarkCourse({
    required String studentUid,
    required String courseUid,
    required String courseTitle,
    required String imageUrl,
  }) async {
    await _db
        .child('student')
        .child(studentUid)
        .child('bookmarks')
        .child(courseUid)
        .set({
          'courseUid': courseUid,
          'courseTitle': courseTitle,
          'imageUrl': imageUrl,
          'bookmarkedAt': DateTime.now().millisecondsSinceEpoch,
        });
  }

  /// Remove a course from bookmarks
  Future<void> removeBookmark({
    required String studentUid,
    required String courseUid,
  }) async {
    await _db
        .child('student')
        .child(studentUid)
        .child('bookmarks')
        .child(courseUid)
        .remove();
  }

  /// Check if a course is bookmarked
  Future<bool> isBookmarked({
    required String studentUid,
    required String courseUid,
  }) async {
    final snapshot = await _db
        .child('student')
        .child(studentUid)
        .child('bookmarks')
        .child(courseUid)
        .get();
    return snapshot.exists;
  }

  /// Get all bookmarked courses (real-time stream, limited to 200)
  Stream<List<Map<String, dynamic>>> getBookmarksStream(String studentUid) {
    return _db
        .child('student')
        .child(studentUid)
        .child('bookmarks')
        .orderByKey()
        .limitToLast(200)
        .onValue
        .map((event) {
          if (!event.snapshot.exists || event.snapshot.value == null) {
            return [];
          }

          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final bookmarks = <Map<String, dynamic>>[];

          data.forEach((key, value) {
            bookmarks.add(Map<String, dynamic>.from(value));
          });

          // Sort by bookmarkedAt descending (newest first)
          bookmarks.sort(
            (a, b) =>
                (b['bookmarkedAt'] ?? 0).compareTo(a['bookmarkedAt'] ?? 0),
          );

          return bookmarks;
        });
  }

  /// Get bookmarks count
  Future<int> getBookmarksCount(String studentUid) async {
    final snapshot = await _db
        .child('student')
        .child(studentUid)
        .child('bookmarks')
        .get();

    if (!snapshot.exists || snapshot.value == null) return 0;
    return (snapshot.value as Map).length;
  }

  /// Toggle bookmark status
  Future<bool> toggleBookmark({
    required String studentUid,
    required String courseUid,
    required String courseTitle,
    required String imageUrl,
  }) async {
    final isCurrentlyBookmarked = await isBookmarked(
      studentUid: studentUid,
      courseUid: courseUid,
    );

    if (isCurrentlyBookmarked) {
      await removeBookmark(studentUid: studentUid, courseUid: courseUid);
      return false;
    } else {
      await bookmarkCourse(
        studentUid: studentUid,
        courseUid: courseUid,
        courseTitle: courseTitle,
        imageUrl: imageUrl,
      );
      return true;
    }
  }
}
