import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Quiz Service - Handles quiz creation, management, and student attempts
///
/// Database Structure:
/// quizzes/
///   {quizId}/
///     quizId: string
///     courseId: string
///     teacherId: string
///     title: string
///     description: string
///     questions: []
///     timeLimit: int (minutes, 0 = unlimited)
///     passingScore: int (percentage)
///     maxAttempts: int (0 = unlimited)
///     isPublished: bool
///     shuffleQuestions: bool
///     shuffleOptions: bool
///     showResults: bool (show correct answers after)
///     createdAt: timestamp
///     updatedAt: timestamp
///
/// quiz_attempts/
///   {attemptId}/
///     attemptId: string
///     quizId: string
///     studentId: string
///     courseId: string
///     answers: Map<questionIndex, selectedOptionIndex>
///     score: int
///     totalQuestions: int
///     percentage: double
///     passed: bool
///     startedAt: timestamp
///     completedAt: timestamp
///     timeTaken: int (seconds)

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ============ QUIZ MANAGEMENT (Teacher) ============

  /// Create a new quiz
  Future<String?> createQuiz({
    required String courseId,
    required String teacherId,
    required String title,
    String? description,
    required List<Map<String, dynamic>> questions,
    int timeLimit = 0,
    int passingScore = 60,
    int maxAttempts = 0,
    bool shuffleQuestions = false,
    bool shuffleOptions = false,
    bool showResults = true,
  }) async {
    try {
      final quizRef = _db.child('quizzes').push();
      final quizId = quizRef.key!;
      final timestamp = ServerValue.timestamp;

      await quizRef.set({
        'quizId': quizId,
        'courseId': courseId,
        'teacherId': teacherId,
        'title': title,
        'description': description ?? '',
        'questions': questions,
        'timeLimit': timeLimit,
        'passingScore': passingScore,
        'maxAttempts': maxAttempts,
        'isPublished': false,
        'shuffleQuestions': shuffleQuestions,
        'shuffleOptions': shuffleOptions,
        'showResults': showResults,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });

      // Also link to course
      await _db
          .child('courses')
          .child(courseId)
          .child('quizzes')
          .child(quizId)
          .set({'quizId': quizId, 'title': title, 'createdAt': timestamp});

      debugPrint('Quiz created: $quizId');
      return quizId;
    } catch (e) {
      debugPrint('Error creating quiz: $e');
      return null;
    }
  }

  /// Update an existing quiz
  Future<bool> updateQuiz({
    required String quizId,
    String? title,
    String? description,
    List<Map<String, dynamic>>? questions,
    int? timeLimit,
    int? passingScore,
    int? maxAttempts,
    bool? shuffleQuestions,
    bool? shuffleOptions,
    bool? showResults,
  }) async {
    try {
      final updates = <String, dynamic>{'updatedAt': ServerValue.timestamp};

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (questions != null) updates['questions'] = questions;
      if (timeLimit != null) updates['timeLimit'] = timeLimit;
      if (passingScore != null) updates['passingScore'] = passingScore;
      if (maxAttempts != null) updates['maxAttempts'] = maxAttempts;
      if (shuffleQuestions != null)
        updates['shuffleQuestions'] = shuffleQuestions;
      if (shuffleOptions != null) updates['shuffleOptions'] = shuffleOptions;
      if (showResults != null) updates['showResults'] = showResults;

      await _db.child('quizzes').child(quizId).update(updates);

      // Update course link title if changed
      if (title != null) {
        final quizSnap = await _db
            .child('quizzes')
            .child(quizId)
            .child('courseId')
            .get();
        if (quizSnap.exists) {
          final courseId = quizSnap.value.toString();
          await _db
              .child('courses')
              .child(courseId)
              .child('quizzes')
              .child(quizId)
              .update({'title': title});
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating quiz: $e');
      return false;
    }
  }

  /// Publish/Unpublish a quiz
  Future<bool> toggleQuizPublished(String quizId, bool isPublished) async {
    try {
      await _db.child('quizzes').child(quizId).update({
        'isPublished': isPublished,
        'updatedAt': ServerValue.timestamp,
      });
      return true;
    } catch (e) {
      debugPrint('Error toggling quiz publish: $e');
      return false;
    }
  }

  /// Delete a quiz
  Future<bool> deleteQuiz(String quizId) async {
    try {
      // Get course ID first
      final quizSnap = await _db.child('quizzes').child(quizId).get();
      if (quizSnap.exists) {
        final quizData = Map<String, dynamic>.from(quizSnap.value as Map);
        final courseId = quizData['courseId'];

        // Remove from course
        await _db
            .child('courses')
            .child(courseId)
            .child('quizzes')
            .child(quizId)
            .remove();
      }

      // Delete quiz
      await _db.child('quizzes').child(quizId).remove();

      // Delete all attempts for this quiz
      final attemptsSnap = await _db
          .child('quiz_attempts')
          .orderByChild('quizId')
          .equalTo(quizId)
          .get();

      if (attemptsSnap.exists) {
        final attempts = Map<String, dynamic>.from(attemptsSnap.value as Map);
        for (final attemptId in attempts.keys) {
          await _db.child('quiz_attempts').child(attemptId).remove();
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting quiz: $e');
      return false;
    }
  }

  /// Get quizzes for a course
  Future<List<Map<String, dynamic>>> getCourseQuizzes(String courseId) async {
    try {
      final snapshot = await _db
          .child('quizzes')
          .orderByChild('courseId')
          .equalTo(courseId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final quizzes = data.entries.map((e) {
        final quiz = Map<String, dynamic>.from(e.value as Map);
        quiz['id'] = e.key;
        return quiz;
      }).toList();

      // Sort by creation date (newest first)
      quizzes.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return quizzes;
    } catch (e) {
      debugPrint('Error getting course quizzes: $e');
      return [];
    }
  }

  /// Get a single quiz
  Future<Map<String, dynamic>?> getQuiz(String quizId) async {
    try {
      final snapshot = await _db.child('quizzes').child(quizId).get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final quiz = Map<String, dynamic>.from(snapshot.value as Map);
      quiz['id'] = quizId;
      return quiz;
    } catch (e) {
      debugPrint('Error getting quiz: $e');
      return null;
    }
  }

  // ============ QUIZ ATTEMPTS (Student) ============

  /// Start a quiz attempt
  Future<String?> startQuizAttempt({
    required String quizId,
    required String studentId,
    required String courseId,
  }) async {
    try {
      // Check if student can attempt
      final canAttempt = await canStudentAttemptQuiz(quizId, studentId);
      if (!canAttempt) {
        debugPrint('Student cannot attempt quiz - max attempts reached');
        return null;
      }

      final attemptRef = _db.child('quiz_attempts').push();
      final attemptId = attemptRef.key!;

      await attemptRef.set({
        'attemptId': attemptId,
        'quizId': quizId,
        'studentId': studentId,
        'courseId': courseId,
        'answers': {},
        'score': 0,
        'totalQuestions': 0,
        'percentage': 0.0,
        'passed': false,
        'startedAt': ServerValue.timestamp,
        'completedAt': null,
        'timeTaken': 0,
        'status': 'in_progress',
      });

      return attemptId;
    } catch (e) {
      debugPrint('Error starting quiz attempt: $e');
      return null;
    }
  }

  /// Submit quiz answers
  Future<Map<String, dynamic>?> submitQuizAttempt({
    required String attemptId,
    required String quizId,
    required Map<int, int> answers, // questionIndex -> selectedOptionIndex
    required int timeTaken, // in seconds
  }) async {
    try {
      // Get quiz to calculate score
      final quiz = await getQuiz(quizId);
      if (quiz == null) return null;

      final questions = quiz['questions'] as List? ?? [];
      int correctAnswers = 0;

      // Calculate score
      for (int i = 0; i < questions.length; i++) {
        final question = Map<String, dynamic>.from(questions[i] as Map);
        final correctIndex = question['correctAnswer'] as int? ?? 0;
        if (answers[i] == correctIndex) {
          correctAnswers++;
        }
      }

      final totalQuestions = questions.length;
      final percentage = totalQuestions > 0
          ? (correctAnswers / totalQuestions * 100).roundToDouble()
          : 0.0;
      final passingScore = quiz['passingScore'] as int? ?? 60;
      final passed = percentage >= passingScore;

      // Convert answers to storable format
      final answersMap = <String, dynamic>{};
      answers.forEach((key, value) {
        answersMap[key.toString()] = value;
      });

      await _db.child('quiz_attempts').child(attemptId).update({
        'answers': answersMap,
        'score': correctAnswers,
        'totalQuestions': totalQuestions,
        'percentage': percentage,
        'passed': passed,
        'completedAt': ServerValue.timestamp,
        'timeTaken': timeTaken,
        'status': 'completed',
      });

      return {
        'score': correctAnswers,
        'totalQuestions': totalQuestions,
        'percentage': percentage,
        'passed': passed,
        'passingScore': passingScore,
      };
    } catch (e) {
      debugPrint('Error submitting quiz attempt: $e');
      return null;
    }
  }

  /// Check if student can attempt quiz
  Future<bool> canStudentAttemptQuiz(String quizId, String studentId) async {
    try {
      final quiz = await getQuiz(quizId);
      if (quiz == null) return false;

      final maxAttempts = quiz['maxAttempts'] as int? ?? 0;
      if (maxAttempts == 0) return true; // Unlimited attempts

      final attempts = await getStudentQuizAttempts(quizId, studentId);
      return attempts.length < maxAttempts;
    } catch (e) {
      debugPrint('Error checking quiz attempts: $e');
      return false;
    }
  }

  /// Get student's attempts for a quiz
  Future<List<Map<String, dynamic>>> getStudentQuizAttempts(
    String quizId,
    String studentId,
  ) async {
    try {
      final snapshot = await _db
          .child('quiz_attempts')
          .orderByChild('quizId')
          .equalTo(quizId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final attempts = data.entries
          .where((e) {
            final attempt = Map<String, dynamic>.from(e.value as Map);
            return attempt['studentId'] == studentId;
          })
          .map((e) {
            final attempt = Map<String, dynamic>.from(e.value as Map);
            attempt['id'] = e.key;
            return attempt;
          })
          .toList();

      // Sort by start time (newest first)
      attempts.sort((a, b) {
        final aTime = a['startedAt'] ?? 0;
        final bTime = b['startedAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return attempts;
    } catch (e) {
      debugPrint('Error getting student quiz attempts: $e');
      return [];
    }
  }

  /// Get student's best attempt for a quiz
  Future<Map<String, dynamic>?> getStudentBestAttempt(
    String quizId,
    String studentId,
  ) async {
    try {
      final attempts = await getStudentQuizAttempts(quizId, studentId);
      if (attempts.isEmpty) return null;

      // Find best attempt by percentage
      Map<String, dynamic>? best;
      double highestPercentage = -1;

      for (final attempt in attempts) {
        if (attempt['status'] == 'completed') {
          final percentage = (attempt['percentage'] ?? 0.0).toDouble();
          if (percentage > highestPercentage) {
            highestPercentage = percentage;
            best = attempt;
          }
        }
      }

      return best;
    } catch (e) {
      debugPrint('Error getting best attempt: $e');
      return null;
    }
  }

  /// Get all attempts for a quiz (teacher view)
  Future<List<Map<String, dynamic>>> getQuizAttempts(String quizId) async {
    try {
      final snapshot = await _db
          .child('quiz_attempts')
          .orderByChild('quizId')
          .equalTo(quizId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final attempts = data.entries.map((e) {
        final attempt = Map<String, dynamic>.from(e.value as Map);
        attempt['id'] = e.key;
        return attempt;
      }).toList();

      return attempts;
    } catch (e) {
      debugPrint('Error getting quiz attempts: $e');
      return [];
    }
  }

  /// Get quiz statistics (teacher view)
  Future<Map<String, dynamic>> getQuizStatistics(String quizId) async {
    try {
      final attempts = await getQuizAttempts(quizId);

      if (attempts.isEmpty) {
        return {
          'totalAttempts': 0,
          'uniqueStudents': 0,
          'averageScore': 0.0,
          'passRate': 0.0,
          'highestScore': 0.0,
          'lowestScore': 0.0,
        };
      }

      final completedAttempts = attempts
          .where((a) => a['status'] == 'completed')
          .toList();
      final uniqueStudents = completedAttempts
          .map((a) => a['studentId'])
          .toSet()
          .length;

      double totalPercentage = 0;
      int passCount = 0;
      double highestScore = 0;
      double lowestScore = 100;

      for (final attempt in completedAttempts) {
        final percentage = (attempt['percentage'] ?? 0.0).toDouble();
        totalPercentage += percentage;
        if (attempt['passed'] == true) passCount++;
        if (percentage > highestScore) highestScore = percentage;
        if (percentage < lowestScore) lowestScore = percentage;
      }

      return {
        'totalAttempts': completedAttempts.length,
        'uniqueStudents': uniqueStudents,
        'averageScore': completedAttempts.isNotEmpty
            ? (totalPercentage / completedAttempts.length).roundToDouble()
            : 0.0,
        'passRate': completedAttempts.isNotEmpty
            ? (passCount / completedAttempts.length * 100).roundToDouble()
            : 0.0,
        'highestScore': highestScore,
        'lowestScore': completedAttempts.isNotEmpty ? lowestScore : 0.0,
      };
    } catch (e) {
      debugPrint('Error getting quiz statistics: $e');
      return {
        'totalAttempts': 0,
        'uniqueStudents': 0,
        'averageScore': 0.0,
        'passRate': 0.0,
        'highestScore': 0.0,
        'lowestScore': 0.0,
      };
    }
  }

  /// Get all quizzes for a student (across enrolled courses)
  Future<List<Map<String, dynamic>>> getStudentQuizzes(String studentId) async {
    try {
      // Get student's enrolled courses
      final enrolledSnap = await _db
          .child('student')
          .child(studentId)
          .child('enrolledCourses')
          .get();

      if (!enrolledSnap.exists || enrolledSnap.value == null) {
        return [];
      }

      final enrolledCourses = Map<String, dynamic>.from(
        enrolledSnap.value as Map,
      );
      final List<Map<String, dynamic>> allQuizzes = [];

      for (final courseId in enrolledCourses.keys) {
        final quizzes = await getCourseQuizzes(courseId);
        for (final quiz in quizzes) {
          if (quiz['isPublished'] == true) {
            // Get student's best attempt
            final bestAttempt = await getStudentBestAttempt(
              quiz['quizId'],
              studentId,
            );
            quiz['bestAttempt'] = bestAttempt;
            quiz['hasPassed'] = bestAttempt?['passed'] ?? false;
            allQuizzes.add(quiz);
          }
        }
      }

      return allQuizzes;
    } catch (e) {
      debugPrint('Error getting student quizzes: $e');
      return [];
    }
  }
}
