import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:eduverse/services/notification_service.dart';

/// Assignment Service - Handles assignment creation, submission, and grading
///
/// Database Structure:
/// assignments/
///   {assignmentId}/
///     assignmentId: string
///     courseId: string
///     teacherId: string
///     title: string
///     description: string
///     instructions: string
///     dueDate: timestamp
///     totalPoints: int
///     attachments: List of {name, url, type}
///     allowedFileTypes: List of strings (pdf, doc, image, etc)
///     maxFileSize: int (MB)
///     isPublished: bool
///     allowLateSubmission: bool
///     latePenaltyPercent: int
///     createdAt: timestamp
///     updatedAt: timestamp
///
/// assignment_submissions/
///   {submissionId}/
///     submissionId: string
///     assignmentId: string
///     studentId: string
///     courseId: string
///     submittedFiles: List<{name, url, type, size}>
///     textResponse: string (optional text answer)
///     submittedAt: timestamp
///     isLate: bool
///     status: string (submitted, graded, returned)
///     grade: int
///     feedback: string
///     gradedAt: timestamp
///     gradedBy: string (teacherId)

class AssignmentService {
  static final AssignmentService _instance = AssignmentService._internal();
  factory AssignmentService() => _instance;
  AssignmentService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  // ============ ASSIGNMENT MANAGEMENT (Teacher) ============

  /// Create a new assignment
  Future<String?> createAssignment({
    required String courseId,
    required String teacherId,
    required String title,
    String? description,
    String? instructions,
    required int dueDate, // timestamp
    int totalPoints = 100,
    List<Map<String, dynamic>>? attachments,
    List<String>? allowedFileTypes,
    int maxFileSize = 10, // MB
    bool allowLateSubmission = true,
    int latePenaltyPercent = 10,
  }) async {
    try {
      final assignmentRef = _db.child('assignments').push();
      final assignmentId = assignmentRef.key!;
      final timestamp = ServerValue.timestamp;

      await assignmentRef.set({
        'assignmentId': assignmentId,
        'courseId': courseId,
        'teacherId': teacherId,
        'title': title,
        'description': description ?? '',
        'instructions': instructions ?? '',
        'dueDate': dueDate,
        'totalPoints': totalPoints,
        'attachments': attachments ?? [],
        'allowedFileTypes': allowedFileTypes ?? ['pdf', 'doc', 'docx', 'image'],
        'maxFileSize': maxFileSize,
        'isPublished': false,
        'allowLateSubmission': allowLateSubmission,
        'latePenaltyPercent': latePenaltyPercent,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });

      // Link to course
      await _db
          .child('courses')
          .child(courseId)
          .child('assignments')
          .child(assignmentId)
          .set({
            'assignmentId': assignmentId,
            'title': title,
            'dueDate': dueDate,
            'createdAt': timestamp,
          });

      debugPrint('Assignment created: $assignmentId');
      return assignmentId;
    } catch (e) {
      debugPrint('Error creating assignment: $e');
      return null;
    }
  }

  /// Update an assignment
  Future<bool> updateAssignment({
    required String assignmentId,
    String? title,
    String? description,
    String? instructions,
    int? dueDate,
    int? totalPoints,
    List<Map<String, dynamic>>? attachments,
    List<String>? allowedFileTypes,
    int? maxFileSize,
    bool? allowLateSubmission,
    int? latePenaltyPercent,
  }) async {
    try {
      final updates = <String, dynamic>{'updatedAt': ServerValue.timestamp};

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (instructions != null) updates['instructions'] = instructions;
      if (dueDate != null) updates['dueDate'] = dueDate;
      if (totalPoints != null) updates['totalPoints'] = totalPoints;
      if (attachments != null) updates['attachments'] = attachments;
      if (allowedFileTypes != null) {
        updates['allowedFileTypes'] = allowedFileTypes;
      }
      if (maxFileSize != null) updates['maxFileSize'] = maxFileSize;
      if (allowLateSubmission != null) {
        updates['allowLateSubmission'] = allowLateSubmission;
      }
      if (latePenaltyPercent != null) {
        updates['latePenaltyPercent'] = latePenaltyPercent;
      }

      await _db.child('assignments').child(assignmentId).update(updates);

      // Update course link if title or dueDate changed
      if (title != null || dueDate != null) {
        final assignSnap = await _db
            .child('assignments')
            .child(assignmentId)
            .child('courseId')
            .get();
        if (assignSnap.exists) {
          final courseId = assignSnap.value.toString();
          final courseUpdates = <String, dynamic>{};
          if (title != null) courseUpdates['title'] = title;
          if (dueDate != null) courseUpdates['dueDate'] = dueDate;
          await _db
              .child('courses')
              .child(courseId)
              .child('assignments')
              .child(assignmentId)
              .update(courseUpdates);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating assignment: $e');
      return false;
    }
  }

  /// Publish/Unpublish assignment
  Future<bool> toggleAssignmentPublished(
    String assignmentId,
    bool isPublished,
  ) async {
    try {
      await _db.child('assignments').child(assignmentId).update({
        'isPublished': isPublished,
        'updatedAt': ServerValue.timestamp,
      });

      // If publishing, notify enrolled students
      if (isPublished) {
        final assignSnap = await _db
            .child('assignments')
            .child(assignmentId)
            .get();
        if (assignSnap.exists) {
          final assignment = Map<String, dynamic>.from(assignSnap.value as Map);
          final courseId = assignment['courseId'];
          final title = assignment['title'];

          // Get enrolled students and notify
          final enrolledSnap = await _db
              .child('courses')
              .child(courseId)
              .child('enrolledStudents')
              .get();
          if (enrolledSnap.exists && enrolledSnap.value != null) {
            final enrolled = Map<String, dynamic>.from(
              enrolledSnap.value as Map,
            );
            for (final studentId in enrolled.keys) {
              await _notificationService.sendNotification(
                toUid: studentId,
                title: '📝 New Assignment',
                message: 'A new assignment "$title" has been posted',
                type: 'assignment',
                relatedCourseId: courseId,
              );
            }
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error toggling assignment publish: $e');
      return false;
    }
  }

  /// Delete an assignment
  Future<bool> deleteAssignment(String assignmentId) async {
    try {
      // Get course ID first
      final assignSnap = await _db
          .child('assignments')
          .child(assignmentId)
          .get();
      if (assignSnap.exists) {
        final assignment = Map<String, dynamic>.from(assignSnap.value as Map);
        final courseId = assignment['courseId'];

        // Remove from course
        await _db
            .child('courses')
            .child(courseId)
            .child('assignments')
            .child(assignmentId)
            .remove();
      }

      // Delete assignment
      await _db.child('assignments').child(assignmentId).remove();

      // Delete all submissions
      final submissionsSnap = await _db
          .child('assignment_submissions')
          .orderByChild('assignmentId')
          .equalTo(assignmentId)
          .get();

      if (submissionsSnap.exists) {
        final submissions = Map<String, dynamic>.from(
          submissionsSnap.value as Map,
        );
        for (final submissionId in submissions.keys) {
          await _db
              .child('assignment_submissions')
              .child(submissionId)
              .remove();
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting assignment: $e');
      return false;
    }
  }

  /// Get assignments for a course
  Future<List<Map<String, dynamic>>> getCourseAssignments(
    String courseId,
  ) async {
    try {
      final snapshot = await _db
          .child('assignments')
          .orderByChild('courseId')
          .equalTo(courseId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final assignments = data.entries.map((e) {
        final assignment = Map<String, dynamic>.from(e.value as Map);
        assignment['id'] = e.key;
        return assignment;
      }).toList();

      // Sort by due date
      assignments.sort((a, b) {
        final aDue = a['dueDate'] ?? 0;
        final bDue = b['dueDate'] ?? 0;
        return aDue.compareTo(bDue);
      });

      return assignments;
    } catch (e) {
      debugPrint('Error getting course assignments: $e');
      return [];
    }
  }

  /// Get a single assignment
  Future<Map<String, dynamic>?> getAssignment(String assignmentId) async {
    try {
      final snapshot = await _db.child('assignments').child(assignmentId).get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final assignment = Map<String, dynamic>.from(snapshot.value as Map);
      assignment['id'] = assignmentId;
      return assignment;
    } catch (e) {
      debugPrint('Error getting assignment: $e');
      return null;
    }
  }

  // ============ SUBMISSIONS (Student) ============

  /// Submit an assignment
  Future<String?> submitAssignment({
    required String assignmentId,
    required String studentId,
    required String courseId,
    List<Map<String, dynamic>>? submittedFiles,
    String? textResponse,
  }) async {
    try {
      // Check if already submitted
      final existing = await getStudentSubmission(assignmentId, studentId);
      if (existing != null) {
        // Update existing submission
        return await updateSubmission(
              submissionId: existing['submissionId'],
              submittedFiles: submittedFiles,
              textResponse: textResponse,
            )
            ? existing['submissionId']
            : null;
      }

      // Get assignment to check due date
      final assignment = await getAssignment(assignmentId);
      if (assignment == null) return null;

      final dueDate = assignment['dueDate'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final isLate = now > dueDate;

      // Check if late submission allowed
      if (isLate && assignment['allowLateSubmission'] != true) {
        debugPrint('Late submission not allowed');
        return null;
      }

      final submissionRef = _db.child('assignment_submissions').push();
      final submissionId = submissionRef.key!;

      await submissionRef.set({
        'submissionId': submissionId,
        'assignmentId': assignmentId,
        'studentId': studentId,
        'courseId': courseId,
        'submittedFiles': submittedFiles ?? [],
        'textResponse': textResponse ?? '',
        'submittedAt': ServerValue.timestamp,
        'isLate': isLate,
        'status': 'submitted',
        'grade': null,
        'feedback': null,
        'gradedAt': null,
        'gradedBy': null,
      });

      // Notify teacher
      final teacherId = assignment['teacherId'];
      if (teacherId != null) {
        // Get student name
        final studentSnap = await _db
            .child('student')
            .child(studentId)
            .child('name')
            .get();
        final studentName = studentSnap.exists
            ? studentSnap.value.toString()
            : 'A student';

        await _notificationService.sendNotification(
          toUid: teacherId,
          title: '📥 New Submission',
          message: '$studentName submitted "${assignment['title']}"',
          type: 'submission',
          relatedCourseId: courseId,
        );
      }

      return submissionId;
    } catch (e) {
      debugPrint('Error submitting assignment: $e');
      return null;
    }
  }

  /// Update a submission (before grading)
  Future<bool> updateSubmission({
    required String submissionId,
    List<Map<String, dynamic>>? submittedFiles,
    String? textResponse,
  }) async {
    try {
      // Check if already graded
      final submission = await _db
          .child('assignment_submissions')
          .child(submissionId)
          .get();
      if (submission.exists) {
        final data = Map<String, dynamic>.from(submission.value as Map);
        if (data['status'] == 'graded') {
          debugPrint('Cannot update graded submission');
          return false;
        }
      }

      final updates = <String, dynamic>{'submittedAt': ServerValue.timestamp};
      if (submittedFiles != null) updates['submittedFiles'] = submittedFiles;
      if (textResponse != null) updates['textResponse'] = textResponse;

      await _db
          .child('assignment_submissions')
          .child(submissionId)
          .update(updates);
      return true;
    } catch (e) {
      debugPrint('Error updating submission: $e');
      return false;
    }
  }

  /// Get student's submission for an assignment
  Future<Map<String, dynamic>?> getStudentSubmission(
    String assignmentId,
    String studentId,
  ) async {
    try {
      final snapshot = await _db
          .child('assignment_submissions')
          .orderByChild('assignmentId')
          .equalTo(assignmentId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in data.entries) {
        final submission = Map<String, dynamic>.from(entry.value as Map);
        if (submission['studentId'] == studentId) {
          submission['id'] = entry.key;
          return submission;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting student submission: $e');
      return null;
    }
  }

  // ============ GRADING (Teacher) ============

  /// Grade a submission
  Future<bool> gradeSubmission({
    required String submissionId,
    required int grade,
    required String teacherId,
    String? feedback,
  }) async {
    try {
      await _db.child('assignment_submissions').child(submissionId).update({
        'grade': grade,
        'feedback': feedback ?? '',
        'gradedAt': ServerValue.timestamp,
        'gradedBy': teacherId,
        'status': 'graded',
      });

      // Notify student
      final submission = await _db
          .child('assignment_submissions')
          .child(submissionId)
          .get();
      if (submission.exists) {
        final data = Map<String, dynamic>.from(submission.value as Map);
        final studentId = data['studentId'];
        final assignmentId = data['assignmentId'];

        // Get assignment title
        final assignment = await getAssignment(assignmentId);
        final title = assignment?['title'] ?? 'Assignment';
        final totalPoints = assignment?['totalPoints'] ?? 100;

        await _notificationService.sendNotification(
          toUid: studentId,
          title: '📊 Assignment Graded',
          message:
              'Your submission for "$title" has been graded: $grade/$totalPoints',
          type: 'grade',
          relatedCourseId: data['courseId'],
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error grading submission: $e');
      return false;
    }
  }

  /// Return submission for revision
  Future<bool> returnSubmission({
    required String submissionId,
    required String teacherId,
    required String feedback,
  }) async {
    try {
      await _db.child('assignment_submissions').child(submissionId).update({
        'feedback': feedback,
        'gradedBy': teacherId,
        'status': 'returned',
      });

      // Notify student
      final submission = await _db
          .child('assignment_submissions')
          .child(submissionId)
          .get();
      if (submission.exists) {
        final data = Map<String, dynamic>.from(submission.value as Map);
        final studentId = data['studentId'];
        final assignmentId = data['assignmentId'];

        final assignment = await getAssignment(assignmentId);
        final title = assignment?['title'] ?? 'Assignment';

        await _notificationService.sendNotification(
          toUid: studentId,
          title: '🔄 Revision Needed',
          message: 'Your submission for "$title" needs revision',
          type: 'revision',
          relatedCourseId: data['courseId'],
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error returning submission: $e');
      return false;
    }
  }

  /// Get all submissions for an assignment (teacher view)
  Future<List<Map<String, dynamic>>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    try {
      final snapshot = await _db
          .child('assignment_submissions')
          .orderByChild('assignmentId')
          .equalTo(assignmentId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final submissions = <Map<String, dynamic>>[];

      for (final entry in data.entries) {
        final submission = Map<String, dynamic>.from(entry.value as Map);
        submission['id'] = entry.key;

        // Get student name
        final studentId = submission['studentId'];
        final studentSnap = await _db
            .child('student')
            .child(studentId)
            .child('name')
            .get();
        submission['studentName'] = studentSnap.exists
            ? studentSnap.value.toString()
            : 'Unknown';

        submissions.add(submission);
      }

      // Sort by submission time
      submissions.sort((a, b) {
        final aTime = a['submittedAt'] ?? 0;
        final bTime = b['submittedAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return submissions;
    } catch (e) {
      debugPrint('Error getting assignment submissions: $e');
      return [];
    }
  }

  /// Get assignment statistics (teacher view)
  Future<Map<String, dynamic>> getAssignmentStatistics(
    String assignmentId,
  ) async {
    try {
      final submissions = await getAssignmentSubmissions(assignmentId);
      final assignment = await getAssignment(assignmentId);

      if (assignment == null) {
        return {
          'totalSubmissions': 0,
          'gradedCount': 0,
          'pendingCount': 0,
          'lateCount': 0,
          'averageGrade': 0.0,
          'highestGrade': 0,
          'lowestGrade': 0,
        };
      }

      int gradedCount = 0;
      int pendingCount = 0;
      int lateCount = 0;
      int totalGrade = 0;
      int highestGrade = 0;
      int lowestGrade = assignment['totalPoints'] ?? 100;

      for (final submission in submissions) {
        if (submission['status'] == 'graded') {
          gradedCount++;
          final grade = submission['grade'] as int? ?? 0;
          totalGrade += grade;
          if (grade > highestGrade) highestGrade = grade;
          if (grade < lowestGrade) lowestGrade = grade;
        } else {
          pendingCount++;
        }
        if (submission['isLate'] == true) lateCount++;
      }

      return {
        'totalSubmissions': submissions.length,
        'gradedCount': gradedCount,
        'pendingCount': pendingCount,
        'lateCount': lateCount,
        'averageGrade': gradedCount > 0
            ? (totalGrade / gradedCount).roundToDouble()
            : 0.0,
        'highestGrade': highestGrade,
        'lowestGrade': gradedCount > 0 ? lowestGrade : 0,
        'totalPoints': assignment['totalPoints'] ?? 100,
      };
    } catch (e) {
      debugPrint('Error getting assignment statistics: $e');
      return {
        'totalSubmissions': 0,
        'gradedCount': 0,
        'pendingCount': 0,
        'lateCount': 0,
        'averageGrade': 0.0,
        'highestGrade': 0,
        'lowestGrade': 0,
      };
    }
  }

  /// Get all assignments for a student (across enrolled courses)
  Future<List<Map<String, dynamic>>> getStudentAssignments(
    String studentId,
  ) async {
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
      final List<Map<String, dynamic>> allAssignments = [];

      for (final courseId in enrolledCourses.keys) {
        final assignments = await getCourseAssignments(courseId);
        for (final assignment in assignments) {
          if (assignment['isPublished'] == true) {
            // Get student's submission
            final submission = await getStudentSubmission(
              assignment['assignmentId'],
              studentId,
            );
            assignment['submission'] = submission;
            assignment['hasSubmitted'] = submission != null;
            assignment['isGraded'] = submission?['status'] == 'graded';

            // Check if overdue
            final dueDate = assignment['dueDate'] as int? ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            assignment['isOverdue'] = now > dueDate && submission == null;

            allAssignments.add(assignment);
          }
        }
      }

      // Sort by due date
      allAssignments.sort((a, b) {
        final aDue = a['dueDate'] ?? 0;
        final bDue = b['dueDate'] ?? 0;
        return aDue.compareTo(bDue);
      });

      return allAssignments;
    } catch (e) {
      debugPrint('Error getting student assignments: $e');
      return [];
    }
  }
}
