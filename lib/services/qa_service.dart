import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/services/notification_service.dart';

/// Q&A Service - Handles course questions and answers
class QAService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  /// Common greeting patterns for auto-response
  static const List<String> _greetingPatterns = [
    'hi',
    'hello',
    'hey',
    'good morning',
    'good afternoon',
    'good evening',
    'howdy',
    'greetings',
    'sup',
    'whats up',
    "what's up",
    'yo',
    'hii',
    'hiii',
    'hiiii',
    'helloo',
    'hellooo',
    'heyyy',
    'heyy',
    'hai',
    'hola',
  ];

  /// Check if a message is a greeting
  bool _isGreeting(String message) {
    final normalizedMessage = message.toLowerCase().trim();
    // Check if the entire message is a greeting or starts with one
    for (final greeting in _greetingPatterns) {
      if (normalizedMessage == greeting ||
          normalizedMessage == '$greeting!' ||
          normalizedMessage == '$greeting.' ||
          normalizedMessage == '$greeting?' ||
          normalizedMessage.startsWith('$greeting ') ||
          normalizedMessage.startsWith('$greeting!') ||
          normalizedMessage.startsWith('$greeting,')) {
        return true;
      }
    }
    return false;
  }

  /// Generate an automated greeting response
  String _generateGreetingResponse(String teacherName) {
    final responses = [
      "Hello! 👋 Thanks for reaching out. I'm here to help you with any questions about the course content. Feel free to ask specific questions about the topics covered, and I'll get back to you as soon as possible!",
      "Hi there! 😊 Welcome to the Q&A section. If you have any questions about the course material, concepts, or need clarification on any topic, please don't hesitate to ask!",
      "Hey! 👋 Good to hear from you. This is the course Q&A section where you can ask questions about the lessons. What would you like to know?",
      "Hello! Thanks for your message. Please feel free to ask any questions related to the course content, and I'll help you out. 📚",
    ];
    return responses[DateTime.now().millisecond % responses.length];
  }

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

    // Check if it's a greeting message for auto-response
    final isGreeting = _isGreeting(question);
    String? teacherName;

    // Get course and teacher info
    final courseSnap = await _db.child('courses').child(courseUid).get();
    String? teacherUid;
    String courseName = '';

    if (courseSnap.exists && courseSnap.value != null) {
      final courseData = Map<String, dynamic>.from(courseSnap.value as Map);
      teacherUid = courseData['teacherUid'] as String?;
      courseName = courseData['title'] ?? '';

      // Get teacher name for auto-response
      if (isGreeting && teacherUid != null) {
        final teacherSnap = await _db.child('teacher').child(teacherUid).get();
        if (teacherSnap.exists && teacherSnap.value != null) {
          final teacherData = Map<String, dynamic>.from(
            teacherSnap.value as Map,
          );
          teacherName = teacherData['name'] ?? 'Instructor';
        }
      }
    }

    // Create the question with auto-answer if it's a greeting
    await questionRef.set({
      'questionId': questionRef.key,
      'videoId': videoId,
      'studentUid': studentUid,
      'studentName': studentName,
      'question': question,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'isAnswered': isGreeting,
      'answer': isGreeting
          ? _generateGreetingResponse(teacherName ?? 'Instructor')
          : null,
      'answeredAt': isGreeting ? DateTime.now().millisecondsSinceEpoch : null,
      'teacherName': isGreeting
          ? (teacherName ?? 'Instructor (Auto-reply)')
          : null,
      'videoTimestamp': videoTimestampSeconds,
      'videoTitle': videoTitle,
      'isAutoResponse': isGreeting, // Flag to indicate automated response
    });

    // Only notify teacher if it's not a greeting (they don't need to respond to greetings)
    if (!isGreeting && teacherUid != null && courseName.isNotEmpty) {
      try {
        await _notificationService.sendNotification(
          toUid: teacherUid,
          title: 'New Question Asked 💬',
          message: '$studentName asked a question in "$courseName"',
          type: 'qa_question',
          relatedCourseId: courseUid,
          relatedVideoId: videoId,
          relatedVideoTimestamp: videoTimestampSeconds,
          fromUid: studentUid,
        );
      } catch (e) {
        // ignore notification failures
      }
    }
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
        debugPrint('Failed to send notification: $e');
      }
    }
  }

  /// Get questions for a specific course (real-time stream, limited to 100)
  Stream<List<Map<String, dynamic>>> getQuestionsStream(String courseUid) {
    return _db
        .child('courses')
        .child(courseUid)
        .child('questions')
        .orderByChild('createdAt')
        .limitToLast(100)
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
    // Return questions for the given video AND general (course-level) questions
    return getQuestionsStream(courseUid).map((questions) {
      return questions.where((q) {
        final qVid = q['videoId']?.toString() ?? '';
        return qVid == videoId || qVid.isEmpty || qVid == 'general';
      }).toList();
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
