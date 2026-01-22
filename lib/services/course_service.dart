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
      // Count videos: support Map, List, and legacy single video fields
      int videoCount = 0;
      if (courseData['videos'] != null) {
        final vids = courseData['videos'];
        if (vids is Map) {
          videoCount = vids.length;
        } else if (vids is List) {
          videoCount = vids.length;
        }
      } else if (courseData['videoUrl'] != null ||
          courseData['video'] != null) {
        videoCount = 1;
      }
      courses.add({
        "courseUid": key,
        "enrolledCount": enrolledCount,
        "videoCount": videoCount,
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

    // Also save review under the course node for per-course stats
    await _db
        .child('courses')
        .child(courseUid)
        .child('reviews')
        .child(studentUid)
        .set(reviewData);
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
    // Compute teacher rating as the average of per-course averages
    final coursesSnap = await _db
        .child('teacher')
        .child(teacherUid)
        .child('courses')
        .get();
    if (!coursesSnap.exists) return {'averageRating': 0.0, 'reviewCount': 0};

    final coursesMap = coursesSnap.value as Map<dynamic, dynamic>;
    double sumCourseAverages = 0.0;
    int coursesWithReviews = 0;
    int totalReviews = 0;

    for (final entry in coursesMap.entries) {
      final courseUid = entry.key.toString();
      final stats = await getCourseRatingStats(courseUid: courseUid);
      final avg = (stats['averageRating'] as double?) ?? 0.0;
      final cnt = (stats['reviewCount'] as int?) ?? 0;
      if (cnt > 0) {
        sumCourseAverages += avg;
        coursesWithReviews++;
        totalReviews += cnt;
      }
    }

    return {
      'averageRating': coursesWithReviews > 0
          ? (sumCourseAverages / coursesWithReviews)
          : 0.0,
      'reviewCount': totalReviews,
    };
  }

  /// Get per-course rating stats (reads from courses/{courseUid}/reviews)
  Future<Map<String, dynamic>> getCourseRatingStats({
    required String courseUid,
  }) async {
    // Try course node first
    final courseReviewsSnap = await _db
        .child('courses')
        .child(courseUid)
        .child('reviews')
        .get();
    if (courseReviewsSnap.exists) {
      final reviews = courseReviewsSnap.value as Map<dynamic, dynamic>;
      double total = 0.0;
      int count = 0;
      reviews.forEach((key, value) {
        final review = Map<String, dynamic>.from(value);
        total += (review['rating'] as num?)?.toDouble() ?? 0.0;
        count++;
      });
      return {
        'averageRating': count > 0 ? total / count : 0.0,
        'reviewCount': count,
      };
    }

    // Fallback: check teacher's stored reviews that reference this course
    final teacherReviewsSnap = await _db.child('teacher').get();
    if (!teacherReviewsSnap.exists) {
      return {'averageRating': 0.0, 'reviewCount': 0};
    }

    final teachers = teacherReviewsSnap.value as Map<dynamic, dynamic>;
    double total = 0.0;
    int count = 0;
    for (final t in teachers.entries) {
      final tData = t.value as Map<dynamic, dynamic>?;
      if (tData != null && tData['reviews'] != null) {
        final reviews = tData['reviews'] as Map<dynamic, dynamic>;
        reviews.forEach((k, v) {
          final review = Map<String, dynamic>.from(v);
          if (review['courseUid'] == courseUid) {
            total += (review['rating'] as num?)?.toDouble() ?? 0.0;
            count++;
          }
        });
      }
    }

    return {
      'averageRating': count > 0 ? total / count : 0.0,
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
    String? teacherUid,
  }) async {
    // First try from /courses path
    var snapshot = await _db
        .child("courses")
        .child(courseUid)
        .child("videos")
        .get();

    // If not found and teacherUid is provided, try from teacher's courses
    if (!snapshot.exists && teacherUid != null) {
      snapshot = await _db
          .child("teacher")
          .child(teacherUid)
          .child("courses")
          .child(courseUid)
          .child("videos")
          .get();
    }

    // If still not found, try to find the teacher by looking up all teachers
    if (!snapshot.exists) {
      final teachersSnapshot = await _db.child("teacher").get();
      if (teachersSnapshot.exists) {
        final teachers = teachersSnapshot.value as Map<dynamic, dynamic>;
        for (final entry in teachers.entries) {
          final tData = entry.value as Map<dynamic, dynamic>?;
          if (tData != null && tData['courses'] != null) {
            final courses = tData['courses'] as Map<dynamic, dynamic>;
            if (courses.containsKey(courseUid)) {
              final courseData = courses[courseUid] as Map<dynamic, dynamic>?;
              if (courseData != null && courseData['videos'] != null) {
                final videosData =
                    courseData['videos'] as Map<dynamic, dynamic>;
                final List<Map<String, dynamic>> videos = [];
                videosData.forEach((key, value) {
                  videos.add({
                    "videoId": key,
                    ...Map<String, dynamic>.from(value as Map),
                  });
                });
                videos.sort(
                  (a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0),
                );
                return videos;
              }
              // Check for legacy single video
              if (courseData != null && courseData['videoUrl'] != null) {
                return [
                  {
                    "videoId": "main",
                    "url": courseData['videoUrl'],
                    "title": courseData['title'] ?? "Course Video",
                    "description": "",
                    "order": 0,
                  },
                ];
              }
              break;
            }
          }
        }
      }
    }

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

  /// Get only public videos for students (filters out private videos)
  Future<List<Map<String, dynamic>>> getPublicCourseVideos({
    required String courseUid,
  }) async {
    final allVideos = await getCourseVideos(courseUid: courseUid);
    // Filter to only include public videos (isPublic is true or not set)
    return allVideos.where((video) {
      final isPublic = video['isPublic'];
      return isPublic == null || isPublic == true;
    }).toList();
  }

  /// Delete a video from a course
  Future<void> deleteVideo({
    required String teacherUid,
    required String courseUid,
    required String videoId,
  }) async {
    // Check if this is a legacy single video (videoId == "main")
    if (videoId == "main") {
      // Remove legacy videoUrl field from both locations
      await _db
          .child("teacher")
          .child(teacherUid)
          .child("courses")
          .child(courseUid)
          .child("videoUrl")
          .remove();

      await _db.child("courses").child(courseUid).child("videoUrl").remove();
    } else {
      // Delete from teacher's course
      await _db
          .child("teacher")
          .child(teacherUid)
          .child("courses")
          .child(courseUid)
          .child("videos")
          .child(videoId)
          .remove();

      // Delete from courses node
      await _db
          .child("courses")
          .child(courseUid)
          .child("videos")
          .child(videoId)
          .remove();
    }
  }

  /// Get all enrolled students for a course
  Future<List<Map<String, dynamic>>> getEnrolledStudents({
    required String courseUid,
  }) async {
    // First, find the course and its enrolled students
    final teachersSnapshot = await _db.child("teacher").get();

    if (!teachersSnapshot.exists) {
      return [];
    }

    final teachers = teachersSnapshot.value as Map<dynamic, dynamic>;

    for (final entry in teachers.entries) {
      final teacherData = entry.value as Map<dynamic, dynamic>?;
      if (teacherData != null && teacherData['courses'] != null) {
        final courses = teacherData['courses'] as Map<dynamic, dynamic>;
        if (courses.containsKey(courseUid)) {
          final courseData = courses[courseUid] as Map<dynamic, dynamic>?;
          if (courseData != null && courseData['enrolledStudents'] != null) {
            final enrolled =
                courseData['enrolledStudents'] as Map<dynamic, dynamic>;
            final List<Map<String, dynamic>> students = [];

            enrolled.forEach((uid, data) {
              students.add({
                'uid': uid.toString(),
                ...Map<String, dynamic>.from(data as Map),
              });
            });

            return students;
          }
        }
      }
    }

    return [];
  }

  /// Update video visibility (public/private)
  Future<void> updateVideoVisibility({
    required String teacherUid,
    required String courseUid,
    required String videoId,
    required bool isPublic,
  }) async {
    // Update in teacher's course
    await _db
        .child("teacher")
        .child(teacherUid)
        .child("courses")
        .child(courseUid)
        .child("videos")
        .child(videoId)
        .update({"isPublic": isPublic});

    // Update in courses node
    await _db
        .child("courses")
        .child(courseUid)
        .child("videos")
        .child(videoId)
        .update({"isPublic": isPublic});
  }

  /// Delete entire course
  Future<void> deleteCourse({
    required String teacherUid,
    required String courseUid,
  }) async {
    // Delete from teacher's courses
    await _db
        .child("teacher")
        .child(teacherUid)
        .child("courses")
        .child(courseUid)
        .remove();

    // Delete from courses node
    await _db.child("courses").child(courseUid).remove();

    // Remove from all enrolled students
    final studentsSnapshot = await _db.child("student").get();
    if (studentsSnapshot.exists) {
      final students = Map<String, dynamic>.from(studentsSnapshot.value as Map);
      for (final studentUid in students.keys) {
        await _db
            .child("student")
            .child(studentUid)
            .child("enrolledCourses")
            .child(courseUid)
            .remove();
      }
    }
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

  /// Calculate overall course progress percentage (only counts public videos for students)
  Future<double> calculateCourseProgress({
    required String studentUid,
    required String courseUid,
  }) async {
    // Get ALL videos (public + private) for total count
    final allVideos = await getCourseVideos(courseUid: courseUid);
    if (allVideos.isEmpty) return 0.0;

    // Get only public videos (what students can complete)
    final publicVideos = await getPublicCourseVideos(courseUid: courseUid);
    if (publicVideos.isEmpty) return 0.0;

    final progress = await getCourseProgress(
      studentUid: studentUid,
      courseUid: courseUid,
    );

    if (progress.isEmpty) return 0.0;

    // Count completed PUBLIC videos only (students can't complete private videos)
    int completedVideos = 0;
    for (final video in publicVideos) {
      final videoId = video['videoId'];
      if (progress[videoId] != null &&
          progress[videoId]['isCompleted'] == true) {
        completedVideos++;
      }
    }

    // Calculate: completed_public_videos / total_all_videos
    // Example: 2 completed out of 10 total (9 public + 1 private) = 20%
    return completedVideos / allVideos.length;
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

        for (final courseEntry in courses.entries) {
          final courseUid = courseEntry.key.toString();
          final courseData = Map<String, dynamic>.from(
            courseEntry.value as Map,
          );

          // Get per-course stats (prefer course node reviews)
          final stats = await getCourseRatingStats(courseUid: courseUid);

          // Determine video count: support both Map and List representations,
          // prefer teacher's course node, otherwise check global /courses node
          int videoCount = 0;
          int publicVideoCount = 0;
          int privateVideoCount = 0;

          Map<dynamic, dynamic>? videosMap;
          if (courseData['videos'] != null) {
            final vidsVal = courseData['videos'];
            if (vidsVal is Map) {
              videosMap = vidsVal;
              videoCount = vidsVal.length;
            } else if (vidsVal is List) {
              videoCount = vidsVal.length;
            }
          } else if (courseData['videoUrl'] != null ||
              courseData['video'] != null) {
            // Legacy single video fields
            videoCount = 1;
            publicVideoCount = 1;
          } else {
            final videosSnap = await _db
                .child('courses')
                .child(courseUid)
                .child('videos')
                .get();
            if (videosSnap.exists && videosSnap.value != null) {
              final vidsVal = videosSnap.value;
              if (vidsVal is Map) {
                videosMap = vidsVal;
                videoCount = vidsVal.length;
              } else if (vidsVal is List) {
                final List<dynamic> vidsList = vidsVal;
                videoCount = vidsList.length;
              }
            }
          }

          // Count public vs private videos
          if (videosMap != null) {
            videosMap.forEach((key, value) {
              final videoData = value is Map ? value : {};
              final isPublic = videoData['isPublic'];
              if (isPublic == false) {
                privateVideoCount++;
              } else {
                publicVideoCount++;
              }
            });
          } else if (publicVideoCount == 0 && videoCount > 0) {
            // For list-type videos or unknown, assume all public
            publicVideoCount = videoCount;
          }

          allCourses.add({
            "courseUid": courseUid,
            "teacherUid": teacherUid,
            "teacherName": teacherName,
            "teacherRating": teacherRating,
            "reviewCount": reviewCount,
            "courseRating": stats['averageRating'] ?? 0.0,
            "courseReviewCount": stats['reviewCount'] ?? 0,
            "videoCount": publicVideoCount,
            "privateVideoCount": privateVideoCount,
            "totalVideoCount": videoCount,
            ...courseData,
          });
        }
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
      final String? teacherUid = data["teacherUid"];

      Map<String, dynamic>? courseData;

      // First try to get from /courses path
      final courseSnapshot = await _db.child("courses").child(courseUid).get();

      if (courseSnapshot.exists && courseSnapshot.value != null) {
        courseData = Map<String, dynamic>.from(courseSnapshot.value as Map);
      } else if (teacherUid != null) {
        // Fallback: get from teacher's courses path
        final teacherCourseSnapshot = await _db
            .child("teacher")
            .child(teacherUid)
            .child("courses")
            .child(courseUid)
            .get();

        if (teacherCourseSnapshot.exists &&
            teacherCourseSnapshot.value != null) {
          courseData = Map<String, dynamic>.from(
            teacherCourseSnapshot.value as Map,
          );
        }
      }

      // If still no course data, skip this entry
      if (courseData == null) continue;

      final effectiveTeacherUid = teacherUid ?? courseData["teacherUid"];

      // Fetch teacher info
      String? teacherName;
      double? teacherRating;
      int? reviewCount;

      if (effectiveTeacherUid != null) {
        final teacherSnapshot = await _db
            .child("teacher")
            .child(effectiveTeacherUid)
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

      // Per-course rating stats (prefer course node reviews)
      final stats = await getCourseRatingStats(courseUid: courseUid);
      final double courseRating = (stats['averageRating'] as double?) ?? 0.0;
      final int courseReviewCount = (stats['reviewCount'] as int?) ?? 0;

      // Determine video count for enrolled course (support Map/List and legacy single video)
      int videoCount = 0;
      if (courseData['videos'] != null) {
        final vidsVal = courseData['videos'];
        if (vidsVal is Map) {
          videoCount = vidsVal.length;
        } else if (vidsVal is List) {
          videoCount = vidsVal.length;
        }
      } else if (courseData['videoUrl'] != null ||
          courseData['video'] != null) {
        videoCount = 1;
      } else {
        final videosSnap = await _db
            .child('courses')
            .child(courseUid)
            .child('videos')
            .get();
        if (videosSnap.exists && videosSnap.value != null) {
          final vidsVal = videosSnap.value;
          if (vidsVal is Map) {
            final Map<dynamic, dynamic> vidsMap = vidsVal;
            videoCount = vidsMap.length;
          } else if (vidsVal is List) {
            final List<dynamic> vidsList = vidsVal;
            videoCount = vidsList.length;
          }
        }
      }

      courses.add({
        "courseUid": courseUid,
        "teacherUid": effectiveTeacherUid,
        "enrolledAt": data["enrolledAt"],
        "isEnrolled": true,
        "teacherName": teacherName,
        "teacherRating": teacherRating,
        "reviewCount": reviewCount,
        "courseRating": courseRating,
        "courseReviewCount": courseReviewCount,
        "videoCount": videoCount,
        ...courseData,
      });
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

    // 2️⃣ Collect student UIDs with their enrolled courses
    final Map<String, Map<String, dynamic>> studentCourseMap = {};

    for (final courseEntry in courses.entries) {
      final courseId = courseEntry.key.toString();
      final courseData = courseEntry.value;
      final enrolledStudents = courseData['enrolledStudents'];

      if (enrolledStudents != null) {
        final Map<dynamic, dynamic> studentsMap =
            enrolledStudents as Map<dynamic, dynamic>;

        for (final studentEntry in studentsMap.entries) {
          final studentUid = studentEntry.key.toString();
          final enrollmentData = studentEntry.value;

          if (!studentCourseMap.containsKey(studentUid)) {
            studentCourseMap[studentUid] = {};
          }
          studentCourseMap[studentUid]![courseId] = {
            'enrolledAt': enrollmentData is Map
                ? enrollmentData['enrolledAt']
                : null,
            'teacherUid': teacherUid,
          };
        }
      }
    }

    if (studentCourseMap.isEmpty) return [];

    // 3️⃣ Fetch student profiles in parallel
    final futures = studentCourseMap.entries.map((entry) async {
      final uid = entry.key;
      final enrolledCourses = entry.value;

      final snap = await db.child('student').child(uid).get();
      if (!snap.exists) return null;

      final data = Map<String, dynamic>.from(
        snap.value as Map<dynamic, dynamic>,
      );

      data['uid'] = uid;
      data['enrolledCourses'] = enrolledCourses;
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

  /// Get all reviews for a specific course
  Future<List<Map<String, dynamic>>> getCourseReviews({
    required String courseUid,
  }) async {
    final List<Map<String, dynamic>> reviews = [];

    // First try from course node
    final courseReviewsSnap = await _db
        .child('courses')
        .child(courseUid)
        .child('reviews')
        .get();
    if (courseReviewsSnap.exists) {
      final reviewsData = courseReviewsSnap.value as Map<dynamic, dynamic>;
      reviewsData.forEach((key, value) {
        reviews.add({
          'reviewId': key.toString(),
          ...Map<String, dynamic>.from(value as Map),
        });
      });
    } else {
      // Fallback: check teacher's reviews for this course
      final teacherSnap = await _db.child('teacher').get();
      if (teacherSnap.exists) {
        final teachers = teacherSnap.value as Map<dynamic, dynamic>;
        for (final t in teachers.entries) {
          final tData = t.value as Map<dynamic, dynamic>?;
          if (tData != null && tData['reviews'] != null) {
            final teacherReviews = tData['reviews'] as Map<dynamic, dynamic>;
            teacherReviews.forEach((key, value) {
              final review = Map<String, dynamic>.from(value as Map);
              if (review['courseUid'] == courseUid) {
                reviews.add({'reviewId': key.toString(), ...review});
              }
            });
          }
        }
      }
    }

    // Sort by date (newest first)
    reviews.sort((a, b) {
      final aTime = a['createdAt'] ?? 0;
      final bTime = b['createdAt'] ?? 0;
      return bTime.compareTo(aTime);
    });

    return reviews;
  }

  /// Get all reviews for all courses of a teacher
  Future<List<Map<String, dynamic>>> getTeacherAllCourseReviews({
    required String teacherUid,
  }) async {
    final List<Map<String, dynamic>> allReviews = [];

    // Get teacher's courses
    final coursesSnap = await _db
        .child('teacher')
        .child(teacherUid)
        .child('courses')
        .get();
    if (!coursesSnap.exists) return [];

    final courses = coursesSnap.value as Map<dynamic, dynamic>;

    for (final courseEntry in courses.entries) {
      final courseUid = courseEntry.key.toString();
      final courseData = courseEntry.value as Map<dynamic, dynamic>;
      final courseTitle = courseData['title'] ?? 'Untitled Course';

      final reviews = await getCourseReviews(courseUid: courseUid);
      for (final review in reviews) {
        allReviews.add({
          ...review,
          'courseUid': courseUid,
          'courseId': courseUid, // Add both for compatibility
          'courseTitle': courseTitle,
        });
      }
    }

    // Sort by date (newest first)
    allReviews.sort((a, b) {
      final aTime = a['createdAt'] ?? 0;
      final bTime = b['createdAt'] ?? 0;
      return bTime.compareTo(aTime);
    });

    return allReviews;
  }

  // ===== ANNOUNCEMENT METHODS =====

  /// Create a new announcement
  Future<void> createAnnouncement({
    required String teacherUid,
    required String title,
    required String message,
    String? courseUid, // null means all courses
    required String priority, // 'normal', 'important', 'urgent'
  }) async {
    final announcementId = _db.push().key;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final announcementData = {
      'title': title,
      'message': message,
      'courseUid': courseUid,
      'priority': priority,
      'createdAt': timestamp,
      'teacherUid': teacherUid,
      'isActive': true,
    };

    await _db
        .child('teacher')
        .child(teacherUid)
        .child('announcements')
        .child(announcementId!)
        .set(announcementData);

    // Also notify enrolled students via notification service
    if (courseUid != null) {
      // Get course name
      final courseSnap = await _db
          .child('teacher')
          .child(teacherUid)
          .child('courses')
          .child(courseUid)
          .get();
      String courseName = 'Course';
      if (courseSnap.exists) {
        final courseData = courseSnap.value as Map<dynamic, dynamic>;
        courseName = courseData['title'] ?? 'Course';
      }

      // Get enrolled students
      final enrolledSnap = await _db
          .child('teacher')
          .child(teacherUid)
          .child('courses')
          .child(courseUid)
          .child('enrolledStudents')
          .get();
      if (enrolledSnap.exists) {
        final students = enrolledSnap.value as Map<dynamic, dynamic>;
        for (final studentUid in students.keys) {
          await _notificationService.sendNotification(
            toUid: studentUid.toString(),
            title: '📢 $title',
            message: '$message\n\nCourse: $courseName',
            type: 'announcement',
            relatedCourseId: courseUid,
            fromUid: teacherUid,
          );
        }
      }
    } else {
      // Notify all students across all courses
      final coursesSnap = await _db
          .child('teacher')
          .child(teacherUid)
          .child('courses')
          .get();
      if (coursesSnap.exists) {
        final courses = coursesSnap.value as Map<dynamic, dynamic>;
        final Set<String> notifiedStudents = {};

        for (final courseEntry in courses.entries) {
          final courseData = courseEntry.value as Map<dynamic, dynamic>;
          if (courseData['enrolledStudents'] != null) {
            final students =
                courseData['enrolledStudents'] as Map<dynamic, dynamic>;
            for (final studentUid in students.keys) {
              final uid = studentUid.toString();
              if (!notifiedStudents.contains(uid)) {
                notifiedStudents.add(uid);
                await _notificationService.sendNotification(
                  toUid: uid,
                  title: '📢 $title',
                  message: message,
                  type: 'announcement',
                  fromUid: teacherUid,
                );
              }
            }
          }
        }
      }
    }
  }

  /// Get all announcements for a teacher
  Future<List<Map<String, dynamic>>> getTeacherAnnouncements({
    required String teacherUid,
  }) async {
    final snapshot = await _db
        .child('teacher')
        .child(teacherUid)
        .child('announcements')
        .get();

    if (!snapshot.exists) return [];

    final data = snapshot.value as Map<dynamic, dynamic>;
    final List<Map<String, dynamic>> announcements = [];

    data.forEach((key, value) {
      announcements.add({
        'announcementId': key.toString(),
        ...Map<String, dynamic>.from(value as Map),
      });
    });

    // Sort by date (newest first)
    announcements.sort((a, b) {
      final aTime = a['createdAt'] ?? 0;
      final bTime = b['createdAt'] ?? 0;
      return bTime.compareTo(aTime);
    });

    return announcements;
  }

  /// Delete an announcement
  Future<void> deleteAnnouncement({
    required String teacherUid,
    required String announcementId,
  }) async {
    await _db
        .child('teacher')
        .child(teacherUid)
        .child('announcements')
        .child(announcementId)
        .remove();
  }

  /// Toggle announcement active status
  Future<void> toggleAnnouncementActive({
    required String teacherUid,
    required String announcementId,
    required bool isActive,
  }) async {
    await _db
        .child('teacher')
        .child(teacherUid)
        .child('announcements')
        .child(announcementId)
        .child('isActive')
        .set(isActive);
  }
}
