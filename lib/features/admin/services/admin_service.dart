import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Admin Service - Handles all admin-related backend operations
/// Uses Firebase Realtime Database to match app architecture
class AdminService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Email server URL
  static const String _emailServerUrl = 'http://localhost:3001';

  // Pagination constants
  static const int pageSize = 20;

  /// Helper to send emails via the local email server
  Future<void> _sendEmailViaServer({
    required String to,
    required String name,
    required String subject,
    required String emailType,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_emailServerUrl/send-admin-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': to,
          'name': name,
          'subject': subject,
          'emailType': emailType,
          ...?extraData,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Email server error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to send email: $e');
    }
  }

  /// Verify if the current user is an admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _db
          .child('admin')
          .child(user.uid)
          .child('role')
          .get();
      return snapshot.exists && snapshot.value == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// Check if a uid is an admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      final snapshot = await _db.child('admin').child(uid).child('role').get();
      return snapshot.exists && snapshot.value == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// Get the current admin's data
  Future<Map<String, dynamic>?> getAdminData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _db.child('admin').child(user.uid).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        if (data['role'] == 'admin') {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // =====================
  // KPI Statistics
  // =====================

  /// Get platform-wide KPI statistics
  Future<Map<String, dynamic>> getKPIStats() async {
    try {
      // Get all students
      final studentsSnapshot = await _db.child('student').get();
      int totalStudents = 0;
      if (studentsSnapshot.exists && studentsSnapshot.value != null) {
        final studentsMap = studentsSnapshot.value as Map?;
        totalStudents = studentsMap?.length ?? 0;
      }

      // Get all teachers
      final teachersSnapshot = await _db.child('teacher').get();
      int totalTeachers = 0;
      int verifiedTeachers = 0;
      int pendingTeachers = 0;
      if (teachersSnapshot.exists && teachersSnapshot.value != null) {
        final teachersMap = Map<String, dynamic>.from(
          teachersSnapshot.value as Map,
        );
        totalTeachers = teachersMap.length;
        for (var entry in teachersMap.entries) {
          final teacher = Map<String, dynamic>.from(entry.value as Map);
          if (teacher['isVerified'] == true ||
              teacher['status'] == 'approved') {
            verifiedTeachers++;
          } else if (teacher['status'] == 'pending') {
            pendingTeachers++;
          }
        }
      }

      // Get all courses
      final coursesSnapshot = await _db.child('courses').get();
      int totalCourses = 0;
      double totalRevenue = 0.0;
      if (coursesSnapshot.exists && coursesSnapshot.value != null) {
        final coursesMap = Map<String, dynamic>.from(
          coursesSnapshot.value as Map,
        );
        totalCourses = coursesMap.length;
        for (var entry in coursesMap.entries) {
          final course = Map<String, dynamic>.from(entry.value as Map);
          // Calculate revenue from enrollments if price exists
          final price = (course['price'] ?? 0).toDouble();
          final enrollments = (course['enrollmentCount'] ?? 0) as int;
          totalRevenue += price * enrollments;
        }
      }

      return {
        'totalUsers': totalStudents + totalTeachers,
        'totalStudents': totalStudents,
        'totalTeachers': totalTeachers,
        'activeTeachers': verifiedTeachers,
        'verifiedTeachers': verifiedTeachers,
        'pendingTeachers': pendingTeachers,
        'totalCourses': totalCourses,
        'totalRevenue': totalRevenue,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'totalUsers': 0,
        'totalStudents': 0,
        'totalTeachers': 0,
        'verifiedTeachers': 0,
        'pendingTeachers': 0,
        'totalCourses': 0,
        'totalRevenue': 0.0,
        'error': e.toString(),
      };
    }
  }

  // =====================
  // User Management
  // =====================

  /// Get users with pagination
  /// Returns a map with 'users' list and 'lastKey' for pagination
  Future<Map<String, dynamic>> getUsers({
    String? role, // 'student', 'teacher', or null for all
    String? startAfterKey,
    int limit = pageSize,
    String? searchQuery,
  }) async {
    try {
      List<Map<String, dynamic>> allUsers = [];

      List<String> rolesToFetch = role != null
          ? [role]
          : ['student', 'teacher'];

      for (String r in rolesToFetch) {
        final snapshot = await _db.child(r).get();
        if (snapshot.exists && snapshot.value != null) {
          final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
          for (var entry in usersMap.entries) {
            final userData = Map<String, dynamic>.from(entry.value as Map);
            userData['uid'] = entry.key;
            userData['role'] = r;

            // Apply search filter if provided
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final name = (userData['name'] ?? '').toString().toLowerCase();
              final email = (userData['email'] ?? '').toString().toLowerCase();
              final query = searchQuery.toLowerCase();
              if (!name.contains(query) && !email.contains(query)) {
                continue;
              }
            }

            allUsers.add(userData);
          }
        }
      }

      // Sort by createdAt descending
      allUsers.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      // Apply pagination
      int startIndex = 0;
      if (startAfterKey != null) {
        startIndex = allUsers.indexWhere((u) => u['uid'] == startAfterKey) + 1;
      }

      final paginatedUsers = allUsers.skip(startIndex).take(limit).toList();
      final lastKey = paginatedUsers.isNotEmpty
          ? paginatedUsers.last['uid']
          : null;

      return {
        'users': paginatedUsers,
        'lastKey': lastKey,
        'hasMore': startIndex + limit < allUsers.length,
      };
    } catch (e) {
      return {
        'users': <Map<String, dynamic>>[],
        'lastKey': null,
        'hasMore': false,
        'error': e.toString(),
      };
    }
  }

  /// Get a single user by ID and role
  Future<Map<String, dynamic>?> getUser(String uid, String role) async {
    try {
      final snapshot = await _db.child(role).child(uid).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data['uid'] = uid;
        data['role'] = role;
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Suspend/Unsuspend a user
  Future<bool> toggleUserSuspension(
    String uid,
    String role,
    bool suspend, {
    String? reason,
  }) async {
    try {
      await _db.child(role).child(uid).update({
        'isSuspended': suspend,
        'suspendedAt': suspend ? ServerValue.timestamp : null,
        'suspensionReason': suspend ? reason : null,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Suspend user with detailed information and email notification
  Future<bool> suspendUserWithDetails({
    required String uid,
    required String role,
    required String reason,
    required bool isPermanent,
    required String userEmail,
    required String userName,
  }) async {
    try {
      // Update user status in database
      await _db.child(role).child(uid).update({
        'isSuspended': true,
        'suspendedAt': ServerValue.timestamp,
        'suspensionReason': reason,
        'suspensionType': isPermanent ? 'permanent' : 'temporary',
      });

      // Send suspension email (using the email server)
      try {
        await _sendSuspensionEmail(
          email: userEmail,
          name: userName,
          reason: reason,
          isPermanent: isPermanent,
        );
      } catch (e) {
        // Email failed but suspension was successful
        debugPrint('Failed to send suspension email: $e');
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send suspension notification email
  Future<void> _sendSuspensionEmail({
    required String email,
    required String name,
    required String reason,
    required bool isPermanent,
  }) async {
    // Send suspension email via email server
    debugPrint('Sending suspension email to $email');
    await _sendEmailViaServer(
      to: email,
      name: name,
      subject: 'EduVerse Account Suspension Notice',
      emailType: 'suspension',
      extraData: {'reason': reason, 'isPermanent': isPermanent},
    );
  }

  /// Verify a teacher and send approval email
  Future<bool> verifyTeacher(String uid, {String? email, String? name}) async {
    try {
      await _db.child('teacher').child(uid).update({
        'isVerified': true,
        'verifiedAt': ServerValue.timestamp,
      });
      
      // Send approval email if email provided
      if (email != null && email.isNotEmpty) {
        try {
          await sendVerificationEmail(
            email: email,
            name: name ?? 'Teacher',
            isApproved: true,
          );
        } catch (e) {
          debugPrint('Failed to send teacher approval email: $e');
          // Verification was successful, just email failed
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error verifying teacher: $e');
      return false;
    }
  }

  /// Reject a teacher and send rejection email
  Future<bool> rejectTeacher(String uid, {String? email, String? name, String? reason}) async {
    try {
      await _db.child('teacher').child(uid).update({
        'isVerified': false,
        'isRejected': true,
        'rejectedAt': ServerValue.timestamp,
        'rejectionReason': reason,
      });
      
      // Send rejection email if email provided
      if (email != null && email.isNotEmpty) {
        try {
          await sendVerificationEmail(
            email: email,
            name: name ?? 'Teacher',
            isApproved: false,
            reason: reason,
          );
        } catch (e) {
          debugPrint('Failed to send teacher rejection email: $e');
          // Rejection was successful, just email failed
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error rejecting teacher: $e');
      return false;
    }
  }

  /// Send verification result email (approval/rejection)
  Future<void> sendVerificationEmail({
    required String email,
    required String name,
    required bool isApproved,
    String? reason,
  }) async {
    await _sendEmailViaServer(
      to: email,
      name: name,
      subject: isApproved
          ? 'Congratulations! Your EduVerse Teacher Application is Approved'
          : 'EduVerse Teacher Application Update',
      emailType: isApproved ? 'teacher_approved' : 'teacher_rejected',
      extraData: reason != null ? {'reason': reason} : null,
    );
  }

  /// Delete a user
  Future<bool> deleteUser(String uid, String role) async {
    try {
      await _db.child(role).child(uid).remove();
      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================
  // Content Moderation
  // =====================

  /// Get flagged content for moderation
  Future<Map<String, dynamic>> getFlaggedContent({
    String? startAfterKey,
    int limit = pageSize,
  }) async {
    try {
      List<Map<String, dynamic>> flaggedItems = [];

      // Check Q&A for reported content
      final qaSnapshot = await _db.child('qa').get();
      if (qaSnapshot.exists && qaSnapshot.value != null) {
        final qaMap = Map<String, dynamic>.from(qaSnapshot.value as Map);
        for (var courseEntry in qaMap.entries) {
          final courseQa = Map<String, dynamic>.from(courseEntry.value as Map);
          for (var qaEntry in courseQa.entries) {
            final qa = Map<String, dynamic>.from(qaEntry.value as Map);
            if (qa['isReported'] == true || qa['flagged'] == true) {
              flaggedItems.add({
                'id': qaEntry.key,
                'courseId': courseEntry.key,
                'type': 'qa',
                'content': qa['question'] ?? qa['content'] ?? '',
                'reportedBy': qa['reportedBy'],
                'reportReason': qa['reportReason'],
                'createdAt': qa['createdAt'],
                ...qa,
              });
            }
          }
        }
      }

      // Check reviews for reported content
      final teachersSnapshot = await _db.child('teacher').get();
      if (teachersSnapshot.exists && teachersSnapshot.value != null) {
        final teachersMap = Map<String, dynamic>.from(
          teachersSnapshot.value as Map,
        );
        for (var teacherEntry in teachersMap.entries) {
          final teacher = Map<String, dynamic>.from(teacherEntry.value as Map);
          if (teacher['reviews'] != null) {
            final reviews = Map<String, dynamic>.from(
              teacher['reviews'] as Map,
            );
            for (var reviewEntry in reviews.entries) {
              final review = Map<String, dynamic>.from(
                reviewEntry.value as Map,
              );
              if (review['isReported'] == true || review['flagged'] == true) {
                flaggedItems.add({
                  'id': reviewEntry.key,
                  'teacherId': teacherEntry.key,
                  'type': 'review',
                  'content': review['review'] ?? review['comment'] ?? '',
                  'rating': review['rating'],
                  'reportedBy': review['reportedBy'],
                  'reportReason': review['reportReason'],
                  'createdAt': review['createdAt'],
                  ...review,
                });
              }
            }
          }
        }
      }

      // Sort by reportedAt/createdAt
      flaggedItems.sort((a, b) {
        final aTime = a['reportedAt'] ?? a['createdAt'] ?? 0;
        final bTime = b['reportedAt'] ?? b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      // Apply pagination
      int startIndex = 0;
      if (startAfterKey != null) {
        startIndex =
            flaggedItems.indexWhere((i) => i['id'] == startAfterKey) + 1;
      }

      final paginatedItems = flaggedItems.skip(startIndex).take(limit).toList();
      final lastKey = paginatedItems.isNotEmpty
          ? paginatedItems.last['id']
          : null;

      return {
        'items': paginatedItems,
        'lastKey': lastKey,
        'hasMore': startIndex + limit < flaggedItems.length,
      };
    } catch (e) {
      return {
        'items': <Map<String, dynamic>>[],
        'lastKey': null,
        'hasMore': false,
        'error': e.toString(),
      };
    }
  }

  /// Report content
  Future<bool> reportContent({
    required String contentId,
    required String contentType, // 'qa', 'review', 'course_review', 'course'
    required String reason,
    required String reportedBy,
    String? parentId, // courseId for qa/course_review, teacherId for review
  }) async {
    try {
      String path;
      if (contentType == 'qa' && parentId != null) {
        // Questions are stored at courses/$courseId/questions/$questionId
        path = 'courses/$parentId/questions/$contentId';
      } else if (contentType == 'course_review' && parentId != null) {
        // Course reviews are stored at courses/$courseId/reviews/$reviewId
        path = 'courses/$parentId/reviews/$contentId';
      } else if (contentType == 'review' && parentId != null) {
        // Teacher reviews are stored at teacher/$teacherId/reviews/$reviewId
        path = 'teacher/$parentId/reviews/$contentId';
      } else {
        path = 'courses/$contentId';
      }

      await _db.child(path).update({
        'isReported': true,
        'flagged': true,
        'reportedBy': reportedBy,
        'reportReason': reason,
        'reportedAt': ServerValue.timestamp,
      });
      
      // Also add to moderation queue for admin review
      await _db.child('moderation').push().set({
        'contentId': contentId,
        'contentType': contentType,
        'contentPath': path, // Store the full path for easy moderation
        'parentId': parentId,
        'reason': reason,
        'reportedBy': reportedBy,
        'reportedAt': ServerValue.timestamp,
        'status': 'pending',
      });
      
      return true;
    } catch (e) {
      debugPrint('Error reporting content: $e');
      return false;
    }
  }

  /// Moderate content (approve/remove)
  Future<bool> moderateContent({
    required String contentId,
    required String contentType,
    required bool approve,
    String? parentId,
    String? contentPath, // Direct path to content (if available)
    String? moderatorNote,
  }) async {
    try {
      String path;
      if (contentPath != null && contentPath.isNotEmpty) {
        // Use the stored path directly if available
        path = contentPath;
      } else if (contentType == 'qa' && parentId != null) {
        // Questions are stored at courses/$courseId/questions/$questionId
        path = 'courses/$parentId/questions/$contentId';
      } else if (contentType == 'course_review' && parentId != null) {
        // Course reviews are stored at courses/$courseId/reviews/$reviewId
        path = 'courses/$parentId/reviews/$contentId';
      } else if (contentType == 'review' && parentId != null) {
        path = 'teacher/$parentId/reviews/$contentId';
      } else {
        path = 'courses/$contentId';
      }

      if (approve) {
        // Clear the flag
        await _db.child(path).update({
          'isReported': false,
          'flagged': false,
          'moderatedAt': ServerValue.timestamp,
          'moderatorNote': moderatorNote,
        });
      } else {
        // Remove the content
        await _db.child(path).remove();
      }
      return true;
    } catch (e) {
      debugPrint('Error moderating content: $e');
      return false;
    }
  }

  /// Issue a warning to a user
  Future<bool> issueWarning({
    required String uid,
    required String role,
    required String reason,
    required String issuedBy,
  }) async {
    try {
      final warningRef = _db.child(role).child(uid).child('warnings').push();
      await warningRef.set({
        'reason': reason,
        'issuedBy': issuedBy,
        'issuedAt': ServerValue.timestamp,
      });

      // Increment warning count
      final userRef = _db.child(role).child(uid);
      final snapshot = await userRef.child('warningCount').get();
      final currentCount = (snapshot.value ?? 0) as int;
      await userRef.update({'warningCount': currentCount + 1});

      return true;
    } catch (e) {
      return false;
    }
  }

  // =====================
  // Analytics Data
  // =====================

  /// Get user growth analytics
  Future<List<Map<String, dynamic>>> getUserGrowthData({int days = 30}) async {
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> growthData = [];

      // Get all users with createdAt
      List<int> timestamps = [];

      for (String role in ['student', 'teacher']) {
        final snapshot = await _db.child(role).get();
        if (snapshot.exists && snapshot.value != null) {
          final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
          for (var entry in usersMap.entries) {
            final user = Map<String, dynamic>.from(entry.value as Map);
            final createdAt = user['createdAt'];
            if (createdAt != null) {
              timestamps.add(createdAt is int ? createdAt : 0);
            }
          }
        }
      }

      // Group by day
      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayStart = DateTime(
          date.year,
          date.month,
          date.day,
        ).millisecondsSinceEpoch;
        final dayEnd = dayStart + 86400000; // 24 hours in milliseconds

        final count = timestamps
            .where((t) => t >= dayStart && t < dayEnd)
            .length;

        growthData.add({
          'date': date.toIso8601String().split('T')[0],
          'count': count,
        });
      }

      return growthData;
    } catch (e) {
      return [];
    }
  }

  /// Get revenue analytics
  Future<List<Map<String, dynamic>>> getRevenueData({int months = 12}) async {
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> revenueData = [];

      // Get all purchases/enrollments
      final coursesSnapshot = await _db.child('courses').get();
      List<Map<String, dynamic>> purchases = [];

      if (coursesSnapshot.exists && coursesSnapshot.value != null) {
        final coursesMap = Map<String, dynamic>.from(
          coursesSnapshot.value as Map,
        );
        for (var entry in coursesMap.entries) {
          final course = Map<String, dynamic>.from(entry.value as Map);
          if (course['enrollments'] != null) {
            final enrollments = Map<String, dynamic>.from(
              course['enrollments'] as Map,
            );
            final price = (course['price'] ?? 0).toDouble();
            for (var enrollEntry in enrollments.entries) {
              final enrollment = Map<String, dynamic>.from(
                enrollEntry.value as Map,
              );
              purchases.add({
                'amount': price,
                'timestamp': enrollment['enrolledAt'] ?? 0,
              });
            }
          }
        }
      }

      // Group by month
      for (int i = months - 1; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthStart = date.millisecondsSinceEpoch;
        final monthEnd = DateTime(
          date.year,
          date.month + 1,
          1,
        ).millisecondsSinceEpoch;

        final monthRevenue = purchases
            .where(
              (p) => p['timestamp'] >= monthStart && p['timestamp'] < monthEnd,
            )
            .fold(0.0, (sum, p) => sum + (p['amount'] as double));

        revenueData.add({
          'month': '${date.year}-${date.month.toString().padLeft(2, '0')}',
          'revenue': monthRevenue,
        });
      }

      return revenueData;
    } catch (e) {
      return [];
    }
  }

  /// Get course enrollment analytics
  Future<List<Map<String, dynamic>>> getCourseAnalytics({
    int limit = 10,
  }) async {
    try {
      final coursesSnapshot = await _db.child('courses').get();
      List<Map<String, dynamic>> courses = [];

      if (coursesSnapshot.exists && coursesSnapshot.value != null) {
        final coursesMap = Map<String, dynamic>.from(
          coursesSnapshot.value as Map,
        );
        for (var entry in coursesMap.entries) {
          final course = Map<String, dynamic>.from(entry.value as Map);
          courses.add({
            'id': entry.key,
            'title': course['title'] ?? 'Untitled',
            'enrollments': course['enrollmentCount'] ?? 0,
            'rating': course['averageRating'] ?? 0.0,
          });
        }
      }

      // Sort by enrollments
      courses.sort(
        (a, b) => (b['enrollments'] as int).compareTo(a['enrollments'] as int),
      );

      return courses.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  // =====================
  // Data Export
  // =====================

  /// Export all users data
  Future<List<Map<String, dynamic>>> exportUsers() async {
    try {
      List<Map<String, dynamic>> allUsers = [];

      for (String role in ['student', 'teacher']) {
        final snapshot = await _db.child(role).get();
        if (snapshot.exists && snapshot.value != null) {
          final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
          for (var entry in usersMap.entries) {
            final userData = Map<String, dynamic>.from(entry.value as Map);
            allUsers.add({
              'uid': entry.key,
              'role': role,
              'name': userData['name'] ?? '',
              'email': userData['email'] ?? '',
              'createdAt': userData['createdAt'],
              'isVerified': userData['isVerified'] ?? false,
              'isSuspended': userData['isSuspended'] ?? false,
            });
          }
        }
      }

      return allUsers;
    } catch (e) {
      return [];
    }
  }

  /// Export all courses data
  Future<List<Map<String, dynamic>>> exportCourses() async {
    try {
      final snapshot = await _db.child('courses').get();
      List<Map<String, dynamic>> courses = [];

      if (snapshot.exists && snapshot.value != null) {
        final coursesMap = Map<String, dynamic>.from(snapshot.value as Map);
        for (var entry in coursesMap.entries) {
          final course = Map<String, dynamic>.from(entry.value as Map);
          courses.add({
            'id': entry.key,
            'title': course['title'] ?? '',
            'description': course['description'] ?? '',
            'teacherUid': course['teacherUid'] ?? '',
            'price': course['price'] ?? 0,
            'enrollmentCount': course['enrollmentCount'] ?? 0,
            'averageRating': course['averageRating'] ?? 0,
            'createdAt': course['createdAt'],
          });
        }
      }

      return courses;
    } catch (e) {
      return [];
    }
  }

  /// Export analytics summary
  Future<Map<String, dynamic>> exportAnalyticsSummary() async {
    try {
      final kpi = await getKPIStats();
      final userGrowth = await getUserGrowthData(days: 30);
      final revenue = await getRevenueData(months: 12);
      final topCourses = await getCourseAnalytics(limit: 10);

      return {
        'generatedAt': DateTime.now().toIso8601String(),
        'kpiStats': kpi,
        'userGrowth': userGrowth,
        'monthlyRevenue': revenue,
        'topCourses': topCourses,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
