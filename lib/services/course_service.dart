import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/services/notification_service.dart';

class CourseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  /// Get teacher courses with enrolled count per course
  Future<List<Map<String, dynamic>>> getTeacherCourses({
    required String teacherUid,
  }) async {
    final snapshot = await _db
        .child("teacher")
        .child(teacherUid)
        .child("courses")
        .get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

    final List<Map<String, dynamic>> courses = [];

    data.forEach((key, value) {
      final courseData = Map<String, dynamic>.from(value);
      // Count enrolled students
      int enrolledCount = 0;
      if (courseData['enrolledStudents'] != null) {
        enrolledCount = (courseData['enrolledStudents'] as Map).length;
      }
      courses.add({
        "courseUid": key,
        "enrolledCount": enrolledCount,
        ...courseData,
      });
    });

    return courses;
  }

  /// Get unique student count across all teacher's courses
  /// This counts each student only once, even if enrolled in multiple courses
  Future<int> getUniqueStudentCount({required String teacherUid}) async {
    final snapshot = await _db
        .child("teacher")
        .child(teacherUid)
        .child("courses")
        .get();

    if (!snapshot.exists) {
      return 0;
    }

    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
    final Set<String> uniqueStudentUids = {};

    data.forEach((key, value) {
      final courseData = Map<String, dynamic>.from(value);
      if (courseData['enrolledStudents'] != null) {
        final enrolledStudents = courseData['enrolledStudents'] as Map;
        uniqueStudentUids.addAll(
          enrolledStudents.keys.map((e) => e.toString()),
        );
      }
    });

    return uniqueStudentUids.length;
  }

  /// Get courses that the student is NOT enrolled in (for explore tab)
  Future<List<Map<String, dynamic>>> getUnenrolledCourses({
    required String studentUid,
  }) async {
    // Get all courses
    final allCourses = await getAllCourses();

    // Get enrolled course IDs
    final enrolledSnapshot = await _db
        .child("student")
        .child(studentUid)
        .child("enrolledCourses")
        .get();

    if (!enrolledSnapshot.exists) {
      return allCourses; // Not enrolled in any course
    }

    final Map<dynamic, dynamic> enrolledCourses =
        enrolledSnapshot.value as Map<dynamic, dynamic>;
    final Set<String> enrolledCourseIds = enrolledCourses.keys
        .map((e) => e.toString())
        .toSet();

    // Filter out enrolled courses
    return allCourses
        .where((course) => !enrolledCourseIds.contains(course['courseUid']))
        .toList();
  }

  /// Submit a review for a course
  Future<void> submitCourseReview({
    required String studentUid,
    required String courseUid,
    required String teacherUid,
    required double rating,
    required String reviewText,
    required String studentName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final reviewData = {
      'studentUid': studentUid,
      'studentName': studentName,
      'courseUid': courseUid,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': timestamp,
    };

    // Save review under teacher's reviews
    await _db
        .child('teacher')
        .child(teacherUid)
        .child('reviews')
        .child(studentUid + '_' + courseUid)
        .set(reviewData);

    // Also mark that student has reviewed this course
    await _db
        .child('student')
        .child(studentUid)
        .child('enrolledCourses')
        .child(courseUid)
        .child('hasReviewed')
        .set(true);
  }

  /// Check if student has already reviewed a course
  Future<bool> hasStudentReviewedCourse({
    required String studentUid,
    required String courseUid,
  }) async {
    final snapshot = await _db
        .child('student')
        .child(studentUid)
        .child('enrolledCourses')
        .child(courseUid)
        .child('hasReviewed')
        .get();

    return snapshot.exists && snapshot.value == true;
  }

  /// Get teacher's average rating and review count
  Future<Map<String, dynamic>> getTeacherRatingStats({
    required String teacherUid,
  }) async {
    final snapshot = await _db
        .child('teacher')
        .child(teacherUid)
        .child('reviews')
        .get();

    if (!snapshot.exists) {
      return {'averageRating': 0.0, 'reviewCount': 0};
    }

    final reviews = snapshot.value as Map<dynamic, dynamic>;
    double totalRating = 0.0;
    int count = 0;

    reviews.forEach((key, value) {
      final review = Map<String, dynamic>.from(value);
      totalRating += (review['rating'] as num?)?.toDouble() ?? 0.0;
      count++;
    });

    return {
      'averageRating': count > 0 ? totalRating / count : 0.0,
      'reviewCount': count,
    };
  }

  /// Add a new video to an existing course
  Future<void> addVideoToCourse({
    required String teacherUid,
    required String courseUid,
    required String videoUrl,
    required String videoTitle,
    String? videoDescription,
  }) async {
    final videoId = _db.push().key;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final videoData = {
      "url": videoUrl,
      "title": videoTitle,
      "description": videoDescription ?? "",
      "createdAt": timestamp,
      "order": timestamp, // Used for ordering videos
    };

    // First, check if this course has a legacy single video that needs migration
    final courseSnap = await _db.child("courses").child(courseUid).get();
    if (courseSnap.exists) {
      final data = Map<String, dynamic>.from(courseSnap.value as Map);
      // If there's a legacy videoUrl but no videos node yet, migrate it
      if (data['videoUrl'] != null) {
        final videosSnap = await _db
            .child("courses")
            .child(courseUid)
            .child("videos")
            .get();
        if (!videosSnap.exists) {
          // Migrate the legacy video
          final legacyVideoId = _db.push().key;
          final legacyVideoData = {
            "url": data['videoUrl'],
            "title": data['title'] ?? "Course Video",
            "description": "",
            "createdAt": data['createdAt'] ?? timestamp - 1000,
            "order": data['createdAt'] ?? timestamp - 1000,
          };

          await _db
              .child("courses")
              .child(courseUid)
              .child("videos")
              .child(legacyVideoId!)
              .set(legacyVideoData);

          await _db
              .child("teacher")
              .child(teacherUid)
              .child("courses")
              .child(courseUid)
              .child("videos")
              .child(legacyVideoId)
              .set(legacyVideoData);
        }
      }
    }

    // Add the new video to teacher's course
    await _db
        .child("teacher")
        .child(teacherUid)
        .child("courses")
        .child(courseUid)
        .child("videos")
        .child(videoId!)
        .set(videoData);

    // Add to courses node
    await _db
        .child("courses")
        .child(courseUid)
        .child("videos")
        .child(videoId)
        .set(videoData);
  }

  /// Get all videos for a course
  Future<List<Map<String, dynamic>>> getCourseVideos({
    required String courseUid,
  }) async {
    final snapshot = await _db
        .child("courses")
        .child(courseUid)
        .child("videos")
        .get();

    if (!snapshot.exists) {
      // Check if there's a legacy single video
      final courseSnap = await _db.child("courses").child(courseUid).get();
      if (courseSnap.exists) {
        final data = Map<String, dynamic>.from(courseSnap.value as Map);
        if (data['videoUrl'] != null) {
          return [
            {
              "videoId": "main",
              "url": data['videoUrl'],
              "title": data['title'] ?? "Course Video",
              "description": "",
              "order": 0,
            },
          ];
        }
      }
      return [];
    }

    final Map<dynamic, dynamic> videosData =
        snapshot.value as Map<dynamic, dynamic>;
    final List<Map<String, dynamic>> videos = [];

    videosData.forEach((key, value) {
      videos.add({"videoId": key, ...Map<String, dynamic>.from(value)});
    });

    // Sort by order
    videos.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
    return videos;
  }

  /// Save student's video progress
  Future<void> saveVideoProgress({
    required String studentUid,
    required String courseUid,
    required String videoId,
    required int positionSeconds,
    required bool isCompleted,
  }) async {
    final progressData = {
      "positionSeconds": positionSeconds,
      "isCompleted": isCompleted,
      "lastWatched": DateTime.now().millisecondsSinceEpoch,
    };

    await _db
        .child("student")
        .child(studentUid)
        .child("enrolledCourses")
        .child(courseUid)
        .child("videoProgress")
        .child(videoId)
        .update(progressData);
  }

  /// Get student's progress for a course
  Future<Map<String, dynamic>> getCourseProgress({
    required String studentUid,
    required String courseUid,
  }) async {
    final snapshot = await _db
        .child("student")
        .child(studentUid)
        .child("enrolledCourses")
        .child(courseUid)
        .child("videoProgress")
        .get();

    if (!snapshot.exists) {
      return {};
    }

    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  /// Calculate overall course progress percentage
  Future<double> calculateCourseProgress({
    required String studentUid,
    required String courseUid,
  }) async {
    final videos = await getCourseVideos(courseUid: courseUid);
    if (videos.isEmpty) return 0.0;

    final progress = await getCourseProgress(
      studentUid: studentUid,
      courseUid: courseUid,
    );

    if (progress.isEmpty) return 0.0;

    int completedVideos = 0;
    for (final video in videos) {
      final videoId = video['videoId'];
      if (progress[videoId] != null &&
          progress[videoId]['isCompleted'] == true) {
        completedVideos++;
      }
    }

    return completedVideos / videos.length;
  }

  Future<List<Map<String, dynamic>>> getAllCourses() async {
    final snapshot = await _db.child("teacher").get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> teachers =
        snapshot.value as Map<dynamic, dynamic>;

    final List<Map<String, dynamic>> allCourses = [];

    for (final teacherEntry in teachers.entries) {
      final teacherUid = teacherEntry.key;
      final teacherData = teacherEntry.value;

      if (teacherData["courses"] != null) {
        // Get teacher name
        final String teacherName = teacherData["name"] ?? "Instructor";

        // Get teacher rating stats
        double teacherRating = 0.0;
        int reviewCount = 0;
        if (teacherData["reviews"] != null) {
          final reviews = teacherData["reviews"] as Map<dynamic, dynamic>;
          double totalRating = 0.0;
          reviews.forEach((key, value) {
            totalRating += (value['rating'] as num?)?.toDouble() ?? 0.0;
            reviewCount++;
          });
          if (reviewCount > 0) {
            teacherRating = totalRating / reviewCount;
          }
        }

        final Map<dynamic, dynamic> courses =
            teacherData["courses"] as Map<dynamic, dynamic>;

        courses.forEach((courseUid, courseData) {
          allCourses.add({
            "courseUid": courseUid,
            "teacherUid": teacherUid,
            "teacherName": teacherName,
            "teacherRating": teacherRating,
            "reviewCount": reviewCount,
            ...Map<String, dynamic>.from(courseData),
          });
        });
      }
    }

    return allCourses;
  }

  Future<void> enrollInCourse({
    required String studentUid,
    required String courseUid,
  }) async {
    try {
      // Get course details for notification
      final courseSnap = await _db.child("courses").child(courseUid).get();

      if (!courseSnap.exists || courseSnap.value == null) {
        throw Exception("Course not found: $courseUid");
      }

      final courseData = Map<String, dynamic>.from(courseSnap.value as Map);
      final String? teacherUid = courseData['teacherUid'];
      final String courseName = courseData['title'] ?? 'Untitled Course';

      if (teacherUid == null) {
        throw Exception("Teacher UID not found for course $courseUid");
      }

      // Get student name for notification
      final studentSnap = await _db
          .child("student")
          .child(studentUid)
          .child("name")
          .get();
      final String studentName = studentSnap.exists
          ? studentSnap.value.toString()
          : 'A student';

      final int timestamp = DateTime.now().millisecondsSinceEpoch;

      final DatabaseReference studentCourseRef = _db
          .child("student")
          .child(studentUid)
          .child("enrolledCourses")
          .child(courseUid);

      final DatabaseReference teacherCourseStudentRef = _db
          .child("teacher")
          .child(teacherUid)
          .child("courses")
          .child(courseUid)
          .child("enrolledStudents")
          .child(studentUid);

      final DatabaseReference courseStudentRef = _db
          .child("courses")
          .child(courseUid)
          .child("enrolledStudents")
          .child(studentUid);

      await Future.wait([
        studentCourseRef.set({
          "teacherUid": teacherUid,
          "enrolledAt": timestamp,
        }),

        teacherCourseStudentRef.set({"enrolledAt": timestamp}),

        courseStudentRef.set({"enrolledAt": timestamp}),
      ]);

      // Send notification to teacher
      await _notificationService.notifyTeacherOfEnrollment(
        teacherUid: teacherUid,
        studentName: studentName,
        courseName: courseName,
        courseId: courseUid,
        studentUid: studentUid,
      );
    } catch (e) {
      throw Exception("Enrollment failed: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getEnrolledCourses({
    required String studentUid,
  }) async {
    final DatabaseReference studentCoursesRef = _db
        .child("student")
        .child(studentUid)
        .child("enrolledCourses");

    final snapshot = await studentCoursesRef.get();

    if (!snapshot.exists) {
      return [];
    }

    final Map<dynamic, dynamic> enrolledCourses =
        snapshot.value as Map<dynamic, dynamic>;

    final List<Map<String, dynamic>> courses = [];

    for (final entry in enrolledCourses.entries) {
      final String courseUid = entry.key;
      final Map data = entry.value;

      final courseSnapshot = await _db.child("courses").child(courseUid).get();

      if (courseSnapshot.exists) {
        final courseData = Map<String, dynamic>.from(
          courseSnapshot.value as Map,
        );
        final teacherUid = data["teacherUid"] ?? courseData["teacherUid"];

        // Fetch teacher info
        String? teacherName;
        double? teacherRating;
        int? reviewCount;

        if (teacherUid != null) {
          final teacherSnapshot = await _db
              .child("teacher")
              .child(teacherUid)
              .get();
          if (teacherSnapshot.exists) {
            final teacherData = Map<String, dynamic>.from(
              teacherSnapshot.value as Map,
            );
            teacherName = teacherData['name'];

            // Calculate teacher rating from reviews
            if (teacherData['reviews'] != null) {
              final reviews = Map<String, dynamic>.from(
                teacherData['reviews'] as Map,
              );
              reviewCount = reviews.length;
              if (reviewCount > 0) {
                double totalRating = 0;
                reviews.forEach((_, review) {
                  totalRating += (review['rating'] ?? 0).toDouble();
                });
                teacherRating = totalRating / reviewCount;
              }
            }
          }
        }

        courses.add({
          "courseUid": courseUid,
          "teacherUid": teacherUid,
          "enrolledAt": data["enrolledAt"],
          "isEnrolled": true,
          "teacherName": teacherName,
          "teacherRating": teacherRating,
          "reviewCount": reviewCount,
          ...courseData,
        });
      }
    }

    return courses;
  }

  Future<List<Map<String, dynamic>>> getAllEnrolledStudentsForTeacher({
    required String teacherUid,
  }) async {
    final DatabaseReference db = FirebaseDatabase.instance.ref();

    // 1️⃣ Get teacher courses
    final coursesSnap = await db
        .child('teacher')
        .child(teacherUid)
        .child('courses')
        .get();

    if (!coursesSnap.exists) return [];

    final Map<dynamic, dynamic> courses =
        coursesSnap.value as Map<dynamic, dynamic>;

    // 2️⃣ Collect unique student UIDs
    final Set<String> studentUids = {};

    for (final courseEntry in courses.entries) {
      final enrolledStudents = courseEntry.value['enrolledStudents'];
      if (enrolledStudents != null) {
        final Map<dynamic, dynamic> studentsMap =
            enrolledStudents as Map<dynamic, dynamic>;

        studentUids.addAll(studentsMap.keys.map((e) => e.toString()));
      }
    }

    if (studentUids.isEmpty) return [];

    // 3️⃣ Fetch student profiles in parallel
    final futures = studentUids.map((uid) async {
      final snap = await db.child('student').child(uid).get();
      if (!snap.exists) return null;

      final data = Map<String, dynamic>.from(
        snap.value as Map<dynamic, dynamic>,
      );

      data['uid'] = uid; // attach uid
      return data;
    });

    // 4️⃣ Resolve futures and remove nulls
    final students = (await Future.wait(
      futures,
    )).whereType<Map<String, dynamic>>().toList();

    return students;
  }

  Future<Map<String, dynamic>?> getCourseDetails({
    required String courseUid,
  }) async {
    final snapshot = await _db.child("courses").child(courseUid).get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final Map<dynamic, dynamic> rawData =
        snapshot.value as Map<dynamic, dynamic>;

    // Convert to Map<String, dynamic>
    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);

    return data;
  }
}
