import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/user_service.dart';

/// A service that preloads all screen data in parallel when user logs in
/// This ensures smooth navigation between tabs without loading delays
class DataPreloaderService {
  static final DataPreloaderService _instance =
      DataPreloaderService._internal();
  factory DataPreloaderService() => _instance;
  DataPreloaderService._internal();

  final CacheService _cacheService = CacheService();
  final CourseService _courseService = CourseService();
  final UserService _userService = UserService();

  // Track preload status
  bool _isPreloading = false;
  bool _studentDataPreloaded = false;
  bool _teacherDataPreloaded = false;

  // Completers to allow waiting for preload completion
  Completer<void>? _studentPreloadCompleter;
  Completer<void>? _teacherPreloadCompleter;

  /// Check if student data is preloaded
  bool get isStudentDataReady => _studentDataPreloaded;

  /// Check if teacher data is preloaded
  bool get isTeacherDataReady => _teacherDataPreloaded;

  /// Wait for student data preload to complete
  Future<void> waitForStudentData() async {
    if (_studentDataPreloaded) return;
    if (_studentPreloadCompleter != null) {
      await _studentPreloadCompleter!.future;
    }
  }

  /// Wait for teacher data preload to complete
  Future<void> waitForTeacherData() async {
    if (_teacherDataPreloaded) return;
    if (_teacherPreloadCompleter != null) {
      await _teacherPreloadCompleter!.future;
    }
  }

  /// Preload all student-related data in parallel
  /// Call this immediately after student login
  Future<void> preloadStudentData({
    required String uid,
    required String role,
  }) async {
    if (_isPreloading && _studentPreloadCompleter != null) {
      await _studentPreloadCompleter!.future;
      return;
    }

    _isPreloading = true;
    _studentPreloadCompleter = Completer<void>();

    try {
      debugPrint('🚀 Starting parallel preload for student data...');
      final startTime = DateTime.now();

      // Preload all data in parallel
      await Future.wait([
        _preloadStudentHomeData(uid, role),
        _preloadStudentCoursesData(uid),
        _preloadStudentProfileData(uid, role),
      ], eagerError: false);

      final duration = DateTime.now().difference(startTime);
      debugPrint(
        '✅ Student data preload completed in ${duration.inMilliseconds}ms',
      );

      _studentDataPreloaded = true;
      _studentPreloadCompleter?.complete();
    } catch (e) {
      debugPrint('⚠️ Error during student data preload: $e');
      _studentPreloadCompleter?.complete(); // Complete even on error
    } finally {
      _isPreloading = false;
    }
  }

  /// Preload all teacher-related data in parallel
  /// Call this immediately after teacher login
  Future<void> preloadTeacherData({
    required String uid,
    required String role,
  }) async {
    if (_isPreloading && _teacherPreloadCompleter != null) {
      await _teacherPreloadCompleter!.future;
      return;
    }

    _isPreloading = true;
    _teacherPreloadCompleter = Completer<void>();

    try {
      debugPrint('🚀 Starting parallel preload for teacher data...');
      final startTime = DateTime.now();

      // Preload all data in parallel
      await Future.wait([
        _preloadTeacherHomeData(uid, role),
        _preloadTeacherCoursesData(uid),
        _preloadTeacherProfileData(uid, role),
        _preloadTeacherAnalyticsData(uid),
      ], eagerError: false);

      final duration = DateTime.now().difference(startTime);
      debugPrint(
        '✅ Teacher data preload completed in ${duration.inMilliseconds}ms',
      );

      _teacherDataPreloaded = true;
      _teacherPreloadCompleter?.complete();
    } catch (e) {
      debugPrint('⚠️ Error during teacher data preload: $e');
      _teacherPreloadCompleter?.complete(); // Complete even on error
    } finally {
      _isPreloading = false;
    }
  }

  /// Preload student home tab data
  Future<void> _preloadStudentHomeData(String uid, String role) async {
    try {
      final cacheKeyName = 'user_name_$uid';
      final cacheKeyCourses = 'all_courses_home';
      final cacheKeyEnrolled = 'enrolled_course_ids_$uid';

      // Skip if already cached
      if (_cacheService.has(cacheKeyName) &&
          _cacheService.has(cacheKeyCourses)) {
        return;
      }

      final results = await Future.wait([
        _userService.getUserName(uid: uid, role: role),
        _courseService.getAllCourses(),
        _courseService.getEnrolledCourses(studentUid: uid),
      ]);

      final name = results[0] as String? ?? "Student";
      final courses = results[1] as List<Map<String, dynamic>>;
      final enrolled = results[2] as List<Map<String, dynamic>>;
      final enrolledIds = enrolled.map((c) => c['courseUid'] as String).toSet();

      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, courses);
      _cacheService.set(cacheKeyEnrolled, enrolledIds);
    } catch (e) {
      debugPrint('Error preloading student home data: $e');
    }
  }

  /// Preload student courses screen data
  Future<void> _preloadStudentCoursesData(String uid) async {
    try {
      final cacheKeyUnenrolled = 'unenrolled_courses_$uid';
      final cacheKeyEnrolled = 'enrolled_courses_detail_$uid';
      final cacheKeyProgress = 'course_progress_$uid';

      // Skip if already cached
      if (_cacheService.has(cacheKeyUnenrolled) &&
          _cacheService.has(cacheKeyEnrolled)) {
        return;
      }

      final results = await Future.wait([
        _courseService.getUnenrolledCourses(studentUid: uid),
        _courseService.getEnrolledCourses(studentUid: uid),
      ]);

      final unenrolledCourses = results[0];
      final enrolledCourses = results[1];

      // Calculate progress for enrolled courses
      Map<String, double> courseProgress = {};
      if (enrolledCourses.isNotEmpty) {
        final progressFutures = enrolledCourses.map((course) async {
          final progress = await _courseService.calculateCourseProgress(
            studentUid: uid,
            courseUid: course['courseUid'],
          );
          return MapEntry(course['courseUid'] as String, progress);
        });

        final progressResults = await Future.wait(progressFutures);
        courseProgress = Map.fromEntries(progressResults);
      }

      _cacheService.set(cacheKeyUnenrolled, unenrolledCourses);
      _cacheService.set(cacheKeyEnrolled, enrolledCourses);
      _cacheService.set(cacheKeyProgress, courseProgress);
    } catch (e) {
      debugPrint('Error preloading student courses data: $e');
    }
  }

  /// Preload student profile screen data
  Future<void> _preloadStudentProfileData(String uid, String role) async {
    try {
      final cacheKey = 'profile_data_$uid';

      // Skip if already cached
      if (_cacheService.has(cacheKey)) return;

      final userData = await _userService.getUser(uid: uid, role: role);
      if (userData == null) return;

      final enrolledCoursesList = await _courseService.getEnrolledCourses(
        studentUid: uid,
      );

      int completed = 0;
      double totalProgress = 0.0;

      if (enrolledCoursesList.isNotEmpty) {
        final progressFutures = enrolledCoursesList.map(
          (course) => _courseService.calculateCourseProgress(
            studentUid: uid,
            courseUid: course['courseUid'],
          ),
        );

        final progressResults = await Future.wait(progressFutures);

        for (final progress in progressResults) {
          totalProgress += progress;
          if (progress >= 1.0) completed++;
        }
      }

      final avgProgress = enrolledCoursesList.isNotEmpty
          ? totalProgress / enrolledCoursesList.length
          : 0.0;

      _cacheService.set(cacheKey, {
        'userName': userData['name'],
        'email': userData['email'],
        'joinedDate': userData['createdAt'],
        'enrolledCourses': enrolledCoursesList.length,
        'completedCourses': completed,
        'overallProgress': avgProgress,
      });
    } catch (e) {
      debugPrint('Error preloading student profile data: $e');
    }
  }

  /// Preload teacher home tab data
  Future<void> _preloadTeacherHomeData(String uid, String role) async {
    try {
      final cacheKeyName = 'teacher_name_$uid';
      final cacheKeyCourses = 'teacher_courses_$uid';
      final cacheKeyStudents = 'teacher_students_$uid';
      final cacheKeyAnnouncements = 'teacher_announcements_$uid';

      // Skip if already cached
      if (_cacheService.has(cacheKeyName) &&
          _cacheService.has(cacheKeyCourses)) {
        return;
      }

      final results = await Future.wait([
        _userService.getUserName(role: role, uid: uid),
        _courseService.getTeacherCourses(teacherUid: uid),
        _courseService.getUniqueStudentCount(teacherUid: uid),
        _courseService.getTeacherAnnouncements(teacherUid: uid),
      ]);

      final name = results[0] as String? ?? "Teacher";
      final courses = results[1] as List<Map<String, dynamic>>;
      final studentCount = results[2] as int;
      final announcements = results[3] as List<Map<String, dynamic>>;

      // Fetch rating stats for each course
      for (int i = 0; i < courses.length; i++) {
        final courseUid = courses[i]['courseUid'];
        try {
          final stats = await _courseService.getCourseRatingStats(
            courseUid: courseUid,
          );
          courses[i]['averageRating'] = stats['averageRating'] ?? 0.0;
          courses[i]['reviewCount'] = stats['reviewCount'] ?? 0;
        } catch (_) {
          courses[i]['averageRating'] = 0.0;
          courses[i]['reviewCount'] = 0;
        }
      }

      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, courses);
      _cacheService.set(cacheKeyStudents, studentCount);
      _cacheService.set(cacheKeyAnnouncements, announcements);
    } catch (e) {
      debugPrint('Error preloading teacher home data: $e');
    }
  }

  /// Preload teacher courses screen data
  Future<void> _preloadTeacherCoursesData(String uid) async {
    try {
      final cacheKeyCourses = 'teacher_all_courses_$uid';
      final cacheKeyStudents = 'teacher_all_students_$uid';

      // Skip if already cached
      if (_cacheService.has(cacheKeyCourses)) return;

      final results = await Future.wait([
        _courseService.getTeacherCourses(teacherUid: uid),
        _courseService.getUniqueStudentCount(teacherUid: uid),
      ]);

      final courses = results[0] as List<Map<String, dynamic>>;
      final studentCount = results[1] as int;

      // Fetch rating stats for each course
      for (int i = 0; i < courses.length; i++) {
        final courseUid = courses[i]['courseUid'];
        try {
          final stats = await _courseService.getCourseRatingStats(
            courseUid: courseUid,
          );
          courses[i]['averageRating'] = stats['averageRating'] ?? 0.0;
          courses[i]['reviewCount'] = stats['reviewCount'] ?? 0;
        } catch (_) {
          courses[i]['averageRating'] = 0.0;
          courses[i]['reviewCount'] = 0;
        }
      }

      _cacheService.set(cacheKeyCourses, courses);
      _cacheService.set(cacheKeyStudents, studentCount);
    } catch (e) {
      debugPrint('Error preloading teacher courses data: $e');
    }
  }

  /// Preload teacher profile screen data
  Future<void> _preloadTeacherProfileData(String uid, String role) async {
    try {
      final cacheKey = 'teacher_profile_$uid';

      // Skip if already cached
      if (_cacheService.has(cacheKey)) return;

      final results = await Future.wait([
        _userService.getUser(uid: uid, role: role),
        _courseService.getTeacherCourses(teacherUid: uid),
        _courseService.getUniqueStudentCount(teacherUid: uid),
        _courseService.getTeacherRatingStats(teacherUid: uid),
      ]);

      final userData = results[0] as Map<String, dynamic>?;
      final courses = results[1] as List<Map<String, dynamic>>;
      final uniqueStudents = results[2] as int;
      final ratingStats = results[3] as Map<String, dynamic>;

      if (userData != null) {
        _cacheService.set(cacheKey, {
          'userName': userData['name'],
          'email': userData['email'],
          'joinedDate': userData['createdAt'],
          'totalCourses': courses.length,
          'totalStudents': uniqueStudents,
          'averageRating': ratingStats['averageRating'] ?? 0.0,
          'reviewCount': ratingStats['reviewCount'] ?? 0,
        });
      }
    } catch (e) {
      debugPrint('Error preloading teacher profile data: $e');
    }
  }

  /// Preload teacher analytics screen data
  Future<void> _preloadTeacherAnalyticsData(String uid) async {
    try {
      final cacheKey = 'teacher_analytics_$uid';

      // Skip if already cached
      if (_cacheService.has(cacheKey)) return;

      // Preload analytics data
      final courses = await _courseService.getTeacherCourses(teacherUid: uid);

      // Calculate basic analytics
      int totalStudents = 0;
      double totalRating = 0.0;
      int ratingCount = 0;

      for (final course in courses) {
        totalStudents += (course['enrolledCount'] ?? 0) as int;
        final rating = course['averageRating'];
        if (rating != null && rating > 0) {
          totalRating += rating as double;
          ratingCount++;
        }
      }

      _cacheService.set(cacheKey, {
        'totalCourses': courses.length,
        'totalStudents': totalStudents,
        'averageRating': ratingCount > 0 ? totalRating / ratingCount : 0.0,
        'courses': courses,
      });
    } catch (e) {
      debugPrint('Error preloading teacher analytics data: $e');
    }
  }

  /// Clear all preloaded data (call on logout)
  void clearAllPreloadedData() {
    _cacheService.clear();
    _studentDataPreloaded = false;
    _teacherDataPreloaded = false;
    _studentPreloadCompleter = null;
    _teacherPreloadCompleter = null;
    debugPrint('🧹 All preloaded data cleared');
  }

  /// Refresh specific screen data in background
  Future<void> refreshStudentDataInBackground(String uid, String role) async {
    // Don't block, just refresh in background
    unawaited(
      Future.wait([
        _preloadStudentHomeData(uid, role),
        _preloadStudentCoursesData(uid),
        _preloadStudentProfileData(uid, role),
      ]),
    );
  }

  /// Refresh teacher data in background
  Future<void> refreshTeacherDataInBackground(String uid, String role) async {
    // Don't block, just refresh in background
    unawaited(
      Future.wait([
        _preloadTeacherHomeData(uid, role),
        _preloadTeacherCoursesData(uid),
        _preloadTeacherProfileData(uid, role),
        _preloadTeacherAnalyticsData(uid),
      ]),
    );
  }
}
