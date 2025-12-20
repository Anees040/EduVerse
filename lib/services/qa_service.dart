import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/services/notification_service.dart';

/// Q&A Service - Handles course questions and answers
class QAService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  /// Ask a question on a course video
  Future<void> askQuestion({
    required String courseUid,
    required String videoId,
    required String studentUid,
    required String studentName,
    required String question,
    int? videoTimestampSeconds,
    String? videoTitle,
  }) async {
    final questionRef = _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .push();

    await questionRef.set({
      'questionId': questionRef.key,
      'videoId': videoId,
      'studentUid': studentUid,
      'studentName': studentName,
      'question': question,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'isAnswered': false,
      'answer': null,
      'answeredAt': null,
      'teacherName': null,
      'videoTimestamp': videoTimestampSeconds,
      'videoTitle': videoTitle,
    });
  }

  /// Teacher answers a question
  Future<void> answerQuestion({
    required String courseUid,
    required String questionId,
    required String answer,
    required String teacherName,
    String? studentUid,
    String? courseName,
    String? teacherUid,
  }) async {
    await _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .child(questionId)
        .update({
          'answer': answer,
          'isAnswered': true,
          'answeredAt': DateTime.now().millisecondsSinceEpoch,
          'teacherName': teacherName,
        });

    // Notify the student who asked the question
    if (studentUid != null) {
      try {
        await _notificationService.sendNotification(
          toUid: studentUid,
          title: 'Question Answered! 💬',
          message:
              '$teacherName replied to your question${courseName != null ? ' in "$courseName"' : ''}',
          type: 'qa_answer',
          relatedCourseId: courseUid,
          fromUid: teacherUid,
        );
      } catch (e) {
        // Don't fail if notification fails
        print('Failed to send notification: $e');
      }
    }
  }

  /// Get questions for a specific course (real-time stream)
  Stream<List<Map<String, dynamic>>> getQuestionsStream(String courseUid) {
    return _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .orderByChild('createdAt')
        .onValue
        .map((event) {
          if (!event.snapshot.exists || event.snapshot.value == null) {
            return [];
          }

          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final questions = <Map<String, dynamic>>[];

          data.forEach((key, value) {
            questions.add(Map<String, dynamic>.from(value));
          });

          // Sort by createdAt descending (newest first)
          questions.sort(
            (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
          );

          return questions;
        });
  }

  /// Get questions for a specific video
  Stream<List<Map<String, dynamic>>> getVideoQuestionsStream(
    String courseUid,
    String videoId,
  ) {
    return getQuestionsStream(courseUid).map((questions) {
      return questions.where((q) => q['videoId'] == videoId).toList();
    });
  }

  /// Get unanswered questions count for a course
  Stream<int> getUnansweredCountStream(String courseUid) {
    return getQuestionsStream(courseUid).map((questions) {
      return questions.where((q) => q['isAnswered'] != true).length;
    });
  }

  /// Get questions asked by a specific student
  Stream<List<Map<String, dynamic>>> getStudentQuestionsStream(
    String courseUid,
    String studentUid,
  ) {
    return getQuestionsStream(courseUid).map((questions) {
      return questions.where((q) => q['studentUid'] == studentUid).toList();
    });
  }

  /// Delete a question
  Future<void> deleteQuestion({
    required String courseUid,
    required String questionId,
  }) async {
    await _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .child(questionId)
        .remove();
  }

  /// Edit a question
  Future<void> editQuestion({
    required String courseUid,
    required String questionId,
    required String newQuestion,
  }) async {
    await _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .child(questionId)
        .update({
          'question': newQuestion,
          'editedAt': DateTime.now().millisecondsSinceEpoch,
        });
  }

  /// Edit an answer
  Future<void> editAnswer({
    required String courseUid,
    required String questionId,
    required String newAnswer,
  }) async {
    await _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .child(questionId)
        .update({
          'answer': newAnswer,
          'answerEditedAt': DateTime.now().millisecondsSinceEpoch,
        });
  }

  /// Delete an answer (reverts question to unanswered state)
  Future<void> deleteAnswer({
    required String courseUid,
    required String questionId,
  }) async {
    await _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .child(questionId)
        .update({
          'answer': null,
          'isAnswered': false,
          'answeredAt': null,
          'teacherName': null,
          'answerEditedAt': null,
        });
  }
}
