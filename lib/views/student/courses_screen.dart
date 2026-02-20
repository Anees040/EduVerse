import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/services/payment_service.dart';
import 'package:eduverse/features/admin/services/admin_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/course_card.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';
import 'package:eduverse/widgets/teacher_public_profile_widget.dart';
import 'package:eduverse/views/student/student_course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  // Static cache to persist data across widget rebuilds
  static List<Map<String, dynamic>>? cachedUnenrolledCourses;
  static List<Map<String, dynamic>>? cachedEnrolledCourses;
  static Map<String, double>? cachedCourseProgress;
  static String? cachedUid;
  static bool hasLoadedOnce = false;

  /// Clear all static caches - call when progress changes
  static void clearCache() {
    cachedUnenrolledCourses = null;
    cachedEnrolledCourses = null;
    cachedCourseProgress = null;
    cachedUid = null;
    hasLoadedOnce = false;
  }

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final CourseService _courseService = CourseService();
  final CacheService _cacheService = CacheService();
  final String _studentUid = FirebaseAuth.instance.currentUser!.uid;

  // Separate search for explore and enrolled tabs
  final TextEditingController _exploreSearchController =
      TextEditingController();
  final TextEditingController _enrolledSearchController =
      TextEditingController();
  String _exploreSearchQuery = '';
  String _enrolledSearchQuery = '';

  // Filter options for explore tab
  String _exploreFilterBy = 'all'; // all, recent, rating, videos
  String _pricingFilter = 'all'; // all, free, paid

  // Filter options for enrolled tab
  String _enrolledFilterBy = 'all'; // all, recent, progress, completed

  bool _isInitialLoading = true;
  List<Map<String, dynamic>> courses = [];
  List<Map<String, dynamic>> enrolledCourses = [];
  Map<String, double> courseProgress = {};

  Timer? _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 120);

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Use cached data immediately if available AND belongs to current user
    if (CoursesScreen.hasLoadedOnce &&
        CoursesScreen.cachedUnenrolledCourses != null &&
        CoursesScreen.cachedEnrolledCourses != null &&
        CoursesScreen.cachedUid == _studentUid) {
      courses = CoursesScreen.cachedUnenrolledCourses!;
      enrolledCourses = CoursesScreen.cachedEnrolledCourses!;
      courseProgress = CoursesScreen.cachedCourseProgress ?? {};
      _isInitialLoading = false;
    }

    _loadData();

    // Start periodic auto-refresh for enrolled courses progress
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted && _tabController.index == 1) {
        // Only refresh when on enrolled tab
        _fetchEnrolledCourses();
      }
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final cacheKeyUnenrolled = 'unenrolled_courses_$_studentUid';
    final cacheKeyEnrolled = 'enrolled_courses_detail_$_studentUid';
    final cacheKeyProgress = 'course_progress_$_studentUid';

    // Use static cache if available and not forcing refresh AND belongs to current user
    if (!forceRefresh &&
        CoursesScreen.hasLoadedOnce &&
        CoursesScreen.cachedUnenrolledCourses != null &&
        CoursesScreen.cachedUid == _studentUid) {
      if (mounted) {
        setState(() {
          courses = CoursesScreen.cachedUnenrolledCourses!;
          enrolledCourses = CoursesScreen.cachedEnrolledCourses ?? [];
          courseProgress = CoursesScreen.cachedCourseProgress ?? {};
          _isInitialLoading = false;
        });
      }
      return;
    }

    // Check CacheService if static cache is empty
    if (!forceRefresh) {
      final cachedUnenrolled = _cacheService.get<List<Map<String, dynamic>>>(
        cacheKeyUnenrolled,
      );
      final cachedEnrolled = _cacheService.get<List<Map<String, dynamic>>>(
        cacheKeyEnrolled,
      );
      final cachedProgress = _cacheService.get<Map<String, double>>(
        cacheKeyProgress,
      );

      if (cachedUnenrolled != null && cachedEnrolled != null) {
        // Update static cache
        CoursesScreen.cachedUnenrolledCourses = cachedUnenrolled;
        CoursesScreen.cachedEnrolledCourses = cachedEnrolled;
        CoursesScreen.cachedCourseProgress = cachedProgress;
        CoursesScreen.cachedUid = _studentUid;
        CoursesScreen.hasLoadedOnce = true;

        if (!mounted) return;
        setState(() {
          courses = cachedUnenrolled;
          enrolledCourses = cachedEnrolled;
          courseProgress = cachedProgress ?? {};
          _isInitialLoading = false;
        });
        // Refresh in background
        _refreshDataInBackground(
          cacheKeyUnenrolled,
          cacheKeyEnrolled,
          cacheKeyProgress,
        );
        return;
      }
    }

    // Show loading only if no data yet
    if (!mounted) return;
    if (courses.isEmpty) {
      setState(() => _isInitialLoading = true);
    }

    await Future.wait([_fetchUnenrolledCourses(), _fetchEnrolledCourses()]);

    // Cache the results
    _cacheService.set(cacheKeyUnenrolled, courses);
    _cacheService.set(cacheKeyEnrolled, enrolledCourses);
    _cacheService.set(cacheKeyProgress, courseProgress);

    // Update static cache
    CoursesScreen.cachedUnenrolledCourses = courses;
    CoursesScreen.cachedEnrolledCourses = enrolledCourses;
    CoursesScreen.cachedCourseProgress = courseProgress;
    CoursesScreen.cachedUid = _studentUid;
    CoursesScreen.hasLoadedOnce = true;

    if (!mounted) return;
    setState(() {
      _isInitialLoading = false;
    });
  }

  Future<void> _refreshDataInBackground(
    String cacheKeyUnenrolled,
    String cacheKeyEnrolled,
    String cacheKeyProgress,
  ) async {
    try {
      await Future.wait([_fetchUnenrolledCourses(), _fetchEnrolledCourses()]);
      _cacheService.set(cacheKeyUnenrolled, courses);
      _cacheService.set(cacheKeyEnrolled, enrolledCourses);
      _cacheService.set(cacheKeyProgress, courseProgress);

      // Update static cache
      CoursesScreen.cachedUnenrolledCourses = courses;
      CoursesScreen.cachedEnrolledCourses = enrolledCourses;
      CoursesScreen.cachedCourseProgress = courseProgress;
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  Future<void> _fetchUnenrolledCourses() async {
    try {
      final fetchedCourses = await _courseService.getUnenrolledCourses(
        studentUid: _studentUid,
      );
      if (!mounted) return;
      setState(() {
        courses = fetchedCourses;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load courses: $e")));
    }
  }

  Future<void> _enrollInCourse(String courseUid) async {
    try {
      await _courseService.enrollInCourse(
        courseUid: courseUid,
        studentUid: _studentUid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enrolled successfully! 🎉"),
          backgroundColor: AppTheme.success,
        ),
      );

      // Clear static cache to force fresh load
      CoursesScreen.cachedUnenrolledCourses = null;
      CoursesScreen.cachedEnrolledCourses = null;
      CoursesScreen.cachedCourseProgress = null;
      CoursesScreen.hasLoadedOnce = false;

      await _loadData(forceRefresh: true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to enroll: $e")));
    }
  }

  /// Enroll in course and immediately navigate to it
  Future<void> _enrollAndOpenCourse(Map<String, dynamic> course) async {
    try {
      await _courseService.enrollInCourse(
        courseUid: course['courseUid'],
        studentUid: _studentUid,
      );

      // Clear static cache
      CoursesScreen.cachedUnenrolledCourses = null;
      CoursesScreen.cachedEnrolledCourses = null;
      CoursesScreen.cachedCourseProgress = null;
      CoursesScreen.hasLoadedOnce = false;

      if (!mounted) return;

      // Navigate to course detail screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StudentCourseDetailScreen(
            courseUid: course['courseUid'],
            courseTitle: course['title'],
            imageUrl: course['imageUrl'] ?? '',
            description: course['description'] ?? '',
            createdAt: course['createdAt'],
          ),
        ),
      ).then((_) {
        _loadData(forceRefresh: true);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to enroll: $e")));
    }
  }

  void _openCourse(Map<String, dynamic> course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCourseDetailScreen(
          courseUid: course['courseUid'],
          courseTitle: course['title'],
          imageUrl: course['imageUrl'] ?? '',
          description: course['description'] ?? '',
          createdAt: course['createdAt'],
        ),
      ),
    ).then((_) {
      // Clear static cache to force fresh progress data
      CoursesScreen.cachedEnrolledCourses = null;
      CoursesScreen.cachedCourseProgress = null;
      CoursesScreen.hasLoadedOnce = false;

      // Also clear CacheService
      final cacheKeyEnrolled = 'enrolled_courses_detail_$_studentUid';
      final cacheKeyProgress = 'course_progress_$_studentUid';
      _cacheService.remove(cacheKeyEnrolled);
      _cacheService.remove(cacheKeyProgress);

      _loadData(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text("Courses"),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore),
                  const SizedBox(width: 8),
                  const Text("Explore"),
                  if (courses.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${courses.length}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school),
                  const SizedBox(width: 8),
                  const Text("My Courses"),
                  if (enrolledCourses.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${enrolledCourses.length}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isInitialLoading
          ? const Center(
              child: EngagingLoadingIndicator(
                message: 'Loading courses...',
                size: 70,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildExploreCourses(), _buildEnrolledCourses()],
            ),
    );
  }

  // Helper to filter explore courses by search query
  List<Map<String, dynamic>> _filterExploreCoursesByQuery(
    List<Map<String, dynamic>> courseList,
  ) {
    if (_exploreSearchQuery.isEmpty) return courseList;
    return courseList.where((course) {
      final title = (course['title'] ?? '').toString().toLowerCase();
      final description = (course['description'] ?? '')
          .toString()
          .toLowerCase();
      final teacherName = (course['teacherName'] ?? '')
          .toString()
          .toLowerCase();
      final query = _exploreSearchQuery.toLowerCase();
      return title.contains(query) ||
          description.contains(query) ||
          teacherName.contains(query);
    }).toList();
  }

  // Helper to filter enrolled courses by search query
  List<Map<String, dynamic>> _filterEnrolledCoursesByQuery(
    List<Map<String, dynamic>> courseList,
  ) {
    if (_enrolledSearchQuery.isEmpty) return courseList;
    return courseList.where((course) {
      final title = (course['title'] ?? '').toString().toLowerCase();
      final description = (course['description'] ?? '')
          .toString()
          .toLowerCase();
      final teacherName = (course['teacherName'] ?? '')
          .toString()
          .toLowerCase();
      final query = _enrolledSearchQuery.toLowerCase();
      return title.contains(query) ||
          description.contains(query) ||
          teacherName.contains(query);
    }).toList();
  }

  // Filter and sort explore courses
  List<Map<String, dynamic>> _sortExploreCourses(
    List<Map<String, dynamic>> courseList,
  ) {
    List<Map<String, dynamic>> filtered;

    switch (_exploreFilterBy) {
      case 'recent':
        // Filter to courses created in last 30 days, sorted by most recent
        final thirtyDaysAgo = DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch;
        filtered = courseList.where((course) {
          final createdAt = course['createdAt'] ?? 0;
          return createdAt > thirtyDaysAgo;
        }).toList();
        filtered.sort(
          (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
        );
        // If no recent courses, show all sorted by most recent
        if (filtered.isEmpty) {
          filtered = List<Map<String, dynamic>>.from(courseList);
          filtered.sort(
            (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
          );
        }
        break;
      case 'rating':
        // Filter to courses with rating >= 4.0, sorted by highest rating
        filtered = courseList.where((course) {
          final rating =
              (course['courseRating'] ?? course['teacherRating'] ?? 0.0) as num;
          return rating >= 4.0;
        }).toList();
        filtered.sort((a, b) {
          final ratingA =
              (a['courseRating'] ?? a['teacherRating'] ?? 0.0) as num;
          final ratingB =
              (b['courseRating'] ?? b['teacherRating'] ?? 0.0) as num;
          return ratingB.compareTo(ratingA);
        });
        // If no top rated courses, show all sorted by rating
        if (filtered.isEmpty) {
          filtered = List<Map<String, dynamic>>.from(courseList);
          filtered.sort((a, b) {
            final ratingA =
                (a['courseRating'] ?? a['teacherRating'] ?? 0.0) as num;
            final ratingB =
                (b['courseRating'] ?? b['teacherRating'] ?? 0.0) as num;
            return ratingB.compareTo(ratingA);
          });
        }
        break;
      case 'videos':
        // Filter to courses with >= 5 videos, sorted by most videos
        filtered = courseList.where((course) {
          final count = (course['videoCount'] ?? 0) as int;
          return count >= 5;
        }).toList();
        filtered.sort((a, b) {
          final countA = (a['videoCount'] ?? 0) as int;
          final countB = (b['videoCount'] ?? 0) as int;
          return countB.compareTo(countA);
        });
        // If no courses with many videos, show all sorted by video count
        if (filtered.isEmpty) {
          filtered = List<Map<String, dynamic>>.from(courseList);
          filtered.sort((a, b) {
            final countA = (a['videoCount'] ?? 0) as int;
            final countB = (b['videoCount'] ?? 0) as int;
            return countB.compareTo(countA);
          });
        }
        break;
      default:
        // 'all' - no filtering, keep default order
        filtered = List<Map<String, dynamic>>.from(courseList);
        break;
    }
    return filtered;
  }

  // Filter and sort enrolled courses
  List<Map<String, dynamic>> _sortEnrolledCourses(
    List<Map<String, dynamic>> courseList,
  ) {
    List<Map<String, dynamic>> filtered;

    switch (_enrolledFilterBy) {
      case 'recent':
        // Filter to recently enrolled (last 7 days), sorted by most recent
        final sevenDaysAgo = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
        filtered = courseList.where((course) {
          final enrolledAt = course['enrolledAt'] ?? course['createdAt'] ?? 0;
          return enrolledAt > sevenDaysAgo;
        }).toList();
        filtered.sort((a, b) {
          final enrolledAtA = a['enrolledAt'] ?? a['createdAt'] ?? 0;
          final enrolledAtB = b['enrolledAt'] ?? b['createdAt'] ?? 0;
          return enrolledAtB.compareTo(enrolledAtA);
        });
        // If no recent enrollments, show all sorted by enrollment date
        if (filtered.isEmpty) {
          filtered = List<Map<String, dynamic>>.from(courseList);
          filtered.sort((a, b) {
            final enrolledAtA = a['enrolledAt'] ?? a['createdAt'] ?? 0;
            final enrolledAtB = b['enrolledAt'] ?? b['createdAt'] ?? 0;
            return enrolledAtB.compareTo(enrolledAtA);
          });
        }
        break;
      case 'progress':
        // Filter to courses in progress (0% < progress < 100%), sorted by highest progress
        filtered = courseList.where((course) {
          final progress = courseProgress[course['courseUid']] ?? 0.0;
          return progress > 0.0 && progress < 1.0;
        }).toList();
        filtered.sort((a, b) {
          final progressA = courseProgress[a['courseUid']] ?? 0.0;
          final progressB = courseProgress[b['courseUid']] ?? 0.0;
          return progressB.compareTo(progressA);
        });
        // If no courses in progress, show all sorted by progress
        if (filtered.isEmpty) {
          filtered = List<Map<String, dynamic>>.from(courseList);
          filtered.sort((a, b) {
            final progressA = courseProgress[a['courseUid']] ?? 0.0;
            final progressB = courseProgress[b['courseUid']] ?? 0.0;
            return progressB.compareTo(progressA);
          });
        }
        break;
      case 'completed':
        // Filter to only completed courses (100% progress)
        filtered = courseList.where((course) {
          final progress = courseProgress[course['courseUid']] ?? 0.0;
          return progress >= 1.0;
        }).toList();
        break;
      default:
        // 'all' - no filtering, keep default order
        filtered = List<Map<String, dynamic>>.from(courseList);
        break;
    }
    return filtered;
  }

  // Build filter chip widget
  Widget _buildFilterChip(
    String label,
    String value,
    bool isSelected,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
              : (isDark ? AppTheme.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF1A1A2E) : Colors.white)
                : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingFilterChip(
    String label,
    String value,
    bool isSelected,
    bool isDark,
    VoidCallback onTap,
  ) {
    Color chipColor;
    if (value == 'free') {
      chipColor = isDark ? AppTheme.darkSuccess : AppTheme.success;
    } else if (value == 'paid') {
      chipColor = isDark ? AppTheme.darkPrimary : AppTheme.primaryColor;
    } else {
      chipColor = isDark ? AppTheme.darkAccent : AppTheme.accentColor;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor
              : (isDark ? AppTheme.darkSurface : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildExploreCourses() {
    final isDark = AppTheme.isDarkMode(context);
    // Filter and sort courses
    var filteredCourses = _filterExploreCoursesByQuery(courses);
    filteredCourses = _sortExploreCourses(filteredCourses);

    // Apply pricing filter
    if (_pricingFilter == 'free') {
      filteredCourses = filteredCourses.where((course) {
        return course['isFree'] == true ||
            course['price'] == null ||
            course['price'] == 0;
      }).toList();
    } else if (_pricingFilter == 'paid') {
      filteredCourses = filteredCourses.where((course) {
        return course['isFree'] == false &&
            course['price'] != null &&
            course['price'] > 0;
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _exploreSearchController,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
              onChanged: (value) {
                setState(() {
                  _exploreSearchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search available courses...',
                hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                ),
                suffixIcon: _exploreSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        onPressed: () {
                          setState(() {
                            _exploreSearchController.clear();
                            _exploreSearchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.getCardColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.getBorderColor(context),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.getBorderColor(context),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.darkPrimaryLight
                        : AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All',
                    'all',
                    _exploreFilterBy == 'all',
                    isDark,
                    () {
                      setState(() => _exploreFilterBy = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Recent',
                    'recent',
                    _exploreFilterBy == 'recent',
                    isDark,
                    () {
                      setState(() => _exploreFilterBy = 'recent');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Top Rated',
                    'rating',
                    _exploreFilterBy == 'rating',
                    isDark,
                    () {
                      setState(() => _exploreFilterBy = 'rating');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Most Videos',
                    'videos',
                    _exploreFilterBy == 'videos',
                    isDark,
                    () {
                      setState(() => _exploreFilterBy = 'videos');
                    },
                  ),
                  const SizedBox(width: 16),
                  // Divider
                  Container(
                    height: 24,
                    width: 1,
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  ),
                  const SizedBox(width: 16),
                  // Pricing filters
                  _buildPricingFilterChip(
                    '💰 All',
                    'all',
                    _pricingFilter == 'all',
                    isDark,
                    () {
                      setState(() => _pricingFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPricingFilterChip(
                    '🆓 Free',
                    'free',
                    _pricingFilter == 'free',
                    isDark,
                    () {
                      setState(() => _pricingFilter = 'free');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildPricingFilterChip(
                    '💎 Paid',
                    'paid',
                    _pricingFilter == 'paid',
                    isDark,
                    () {
                      setState(() => _pricingFilter = 'paid');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Results count when searching
          if (_exploreSearchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 16,
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${filteredCourses.length} result${filteredCourses.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Course grid or empty state
          Expanded(
            child: filteredCourses.isEmpty
                ? _exploreSearchQuery.isNotEmpty
                      ? _buildEmptyState(
                          icon: Icons.search_off,
                          title: 'No Results Found',
                          subtitle:
                              'Try searching with different keywords\nor browse all available courses.',
                        )
                      : enrolledCourses.isNotEmpty
                      ? _buildEmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'You\'re All Caught Up!',
                          subtitle:
                              'You have enrolled in all available courses.\nNew courses will appear here when they become available.',
                        )
                      : _buildEmptyState(
                          icon: Icons.school_outlined,
                          title: 'No Courses Available',
                          subtitle:
                              'There are no courses available at this time.\nPlease check back later for new courses.',
                        )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GridView.builder(
                      itemCount: filteredCourses.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 0.58,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemBuilder: (context, index) {
                        final course = filteredCourses[index];

                        return CourseCard(
                          title: course['title'] ?? 'Untitled Course',
                          description: course['description'],
                          imageUrl: course['imageUrl'] ?? '',
                          createdAt: course['createdAt'],
                          isEnrolled: false,
                          showEnrollButton: true,
                          progress: 0.0,
                          instructorName: course['teacherName'],
                          instructorRating: course['courseRating'] != null
                              ? (course['courseRating'] as num).toDouble()
                              : (course['teacherRating'] != null
                                    ? (course['teacherRating'] as num)
                                          .toDouble()
                                    : null),
                          reviewCount:
                              course['courseReviewCount'] ??
                              course['reviewCount'],
                          videoCount: (() {
                            final v = course['videoCount'];
                            if (v is int) return v;
                            final vids = course['videos'];
                            if (vids is Map) return vids.length;
                            if (vids is List) return vids.length;
                            if (course['videoUrl'] != null ||
                                course['video'] != null) {
                              return 1;
                            }
                            return 0;
                          })(),
                          privateVideoCount: (() {
                            final pv = course['privateVideoCount'];
                            if (pv is int) return pv;
                            return 0;
                          })(),
                          isFree: course['isFree'] ?? true,
                          price: (course['price'] as num?)?.toDouble(),
                          discountedPrice: (course['discountedPrice'] as num?)
                              ?.toDouble(),
                          category: course['category'],
                          onTap: () => _showEnrollDialog(course),
                          onEnroll: () => _showEnrollDialog(course),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showEnrollDialog(Map<String, dynamic> course) {
    final isDark = AppTheme.isDarkMode(context);
    final courseRating = course['courseRating'] != null
        ? (course['courseRating'] as num).toDouble()
        : (course['teacherRating'] != null
              ? (course['teacherRating'] as num).toDouble()
              : 0.0);
    final reviewCount =
        course['courseReviewCount'] ?? course['reviewCount'] ?? 0;

    // Check if course is paid
    final isFree = course['isFree'] ?? true;
    final price = (course['price'] as num?)?.toDouble() ?? 0.0;
    final discountedPrice = (course['discountedPrice'] as num?)?.toDouble();
    final hasDiscount = discountedPrice != null && discountedPrice < price;
    final finalPrice = hasDiscount ? discountedPrice : price;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.school,
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enroll in Course',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: course['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  course['title'] ?? 'Untitled Course',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),

                // Instructor name
                if (course['teacherName'] != null)
                  GestureDetector(
                    onTap: () {
                      if (course['teacherUid'] != null) {
                        Navigator.pop(ctx); // Close dialog first
                        TeacherPublicProfileWidget.showProfile(
                          context: context,
                          teacherUid: course['teacherUid'],
                          teacherName: course['teacherName'],
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            course['teacherName'],
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // Rating display
                if (reviewCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.darkWarning : AppTheme.warning)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(
                          5,
                          (index) => Icon(
                            index < courseRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: isDark
                                ? AppTheme.darkWarning
                                : AppTheme.warning,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${courseRating.toStringAsFixed(1)} ($reviewCount reviews)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),
                Text(
                  course['description'] ?? 'No description',
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Reviews section
                if (reviewCount > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.rate_review,
                        size: 16,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Student Reviews',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showAllCourseReviewsDialog(course),
                        child: Text(
                          'See All →',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Show recent reviews preview
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _courseService.getCourseReviews(
                      courseUid: course['courseUid'],
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final reviews = snapshot.data ?? [];
                      final previewReviews = reviews.take(2).toList();

                      if (previewReviews.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        children: previewReviews
                            .map(
                              (review) =>
                                  _buildReviewPreviewCard(review, isDark),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],

                // Pricing section for paid courses
                if (!isFree) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                AppTheme.darkAccent.withOpacity(0.2),
                                AppTheme.darkPrimaryLight.withOpacity(0.1),
                              ]
                            : [
                                AppTheme.primaryColor.withOpacity(0.1),
                                AppTheme.accentColor.withOpacity(0.05),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkAccent.withOpacity(0.3)
                            : AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 18,
                              color: isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Order Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Course Price',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: hasDiscount
                                    ? AppTheme.getTextSecondary(context)
                                    : AppTheme.getTextPrimary(context),
                                fontSize: 13,
                                decoration: hasDiscount
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Discount',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppTheme.darkSuccess
                                          : AppTheme.success,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isDark
                                                  ? AppTheme.darkSuccess
                                                  : AppTheme.success)
                                              .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '-${((price - discountedPrice) / price * 100).round()}%',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppTheme.darkSuccess
                                            : AppTheme.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '-\$${(price - discountedPrice).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkSuccess
                                      : AppTheme.success,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              '\$${finalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  isFree
                      ? 'Would you like to enroll in this course?'
                      : 'Ready to unlock this premium course?',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              if (isFree) {
                _enrollInCourse(course['courseUid']);
              } else {
                _showMockPaymentFlow(course, finalPrice);
              }
            },
            icon: Icon(isFree ? Icons.check : Icons.payment),
            label: Text(isFree ? 'Enroll Now' : 'Proceed to Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
              foregroundColor: const Color(0xFFF0F8FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 6,
              shadowColor:
                  (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showMockPaymentFlow(Map<String, dynamic> course, double amount) {
    final isDark = AppTheme.isDarkMode(context);
    String selectedPaymentMethod = 'card';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.getTextSecondary(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                          Text(
                            'Secure mock payment',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkElevated
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: course['imageUrl'] ?? '',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    course['title'] ?? 'Untitled',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.getTextPrimary(context),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'by ${course['teacherName'] ?? 'Instructor'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Payment methods
                      Text(
                        'Payment Method',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Card option
                      _buildPaymentMethodTile(
                        icon: Icons.credit_card,
                        title: 'Credit / Debit Card',
                        subtitle: '**** **** **** 4242',
                        isSelected: selectedPaymentMethod == 'card',
                        isDark: isDark,
                        onTap: () =>
                            setModalState(() => selectedPaymentMethod = 'card'),
                      ),
                      const SizedBox(height: 10),

                      // PayPal option
                      _buildPaymentMethodTile(
                        icon: Icons.account_balance_wallet,
                        title: 'PayPal',
                        subtitle: 'user@email.com',
                        isSelected: selectedPaymentMethod == 'paypal',
                        isDark: isDark,
                        onTap: () => setModalState(
                          () => selectedPaymentMethod = 'paypal',
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Apple Pay option
                      _buildPaymentMethodTile(
                        icon: Icons.apple,
                        title: 'Apple Pay',
                        subtitle: 'Quick checkout',
                        isSelected: selectedPaymentMethod == 'apple',
                        isDark: isDark,
                        onTap: () => setModalState(
                          () => selectedPaymentMethod = 'apple',
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Security note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              (isDark ? AppTheme.darkSuccess : AppTheme.success)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                (isDark
                                        ? AppTheme.darkSuccess
                                        : AppTheme.success)
                                    .withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 20,
                              color: isDark
                                  ? AppTheme.darkSuccess
                                  : AppTheme.success,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This is a mock payment for demonstration purposes. No real charges will be made.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.darkSuccess
                                      : AppTheme.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _processPayment(course, amount);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Pay \$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.1)
              : isDark
              ? AppTheme.darkElevated
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : isDark
                ? AppTheme.darkBorder
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) => onTap(),
              activeColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _processPayment(Map<String, dynamic> course, double amount) async {
    final isDark = AppTheme.isDarkMode(context);
    final paymentService = PaymentService();

    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppTheme.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Processing Payment...',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your payment',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    // Process payment through PaymentService
    try {
      // Get student name - just use a simple name for now
      const studentName = 'Student';

      final result = await paymentService.processCoursePayment(
        studentUid: _studentUid,
        studentName: studentName,
        courseId: course['courseUid'],
        courseName: course['title'] ?? 'Course',
        teacherUid: course['teacherUid'] ?? '',
        teacherName: course['teacherName'] ?? 'Instructor',
        coursePrice: amount,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (result.success) {
        _showPaymentSuccessDialog(course, amount, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${result.error}'),
            backgroundColor: isDark ? AppTheme.darkError : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: isDark ? AppTheme.darkError : AppTheme.error,
        ),
      );
    }
  }

  void _showPaymentSuccessDialog(
    Map<String, dynamic> course,
    double amount,
    PaymentResult paymentResult,
  ) {
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 56,
                color: isDark ? AppTheme.darkSuccess : AppTheme.success,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have been enrolled in\n"${course['title']}"',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Amount Paid: \$${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _enrollAndOpenCourse(course);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Learning',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewPreviewCard(Map<String, dynamic> review, bool isDark) {
    final rating = (review['rating'] ?? 0.0) as double;
    final studentName = review['studentName'] ?? 'Student';
    final reviewText = review['reviewText'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                child: Text(
                  studentName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  studentName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
              // Stars
              ...List.generate(
                5,
                (index) => Icon(
                  index < rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 12,
                  color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                ),
              ),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reviewText,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showAllCourseReviewsDialog(Map<String, dynamic> course) {
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkWarning : AppTheme.warning)
                    .withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.rate_review,
                color: isDark ? AppTheme.darkWarning : AppTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Course Reviews',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    course['title'] ?? 'Course',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.5,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _courseService.getCourseReviews(
              courseUid: course['courseUid'],
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reviews = snapshot.data ?? [];

              if (reviews.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: reviews.length,
                itemBuilder: (ctx, index) => _buildFullReviewCard(
                  reviews[index],
                  isDark,
                  course['courseUid'],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullReviewCard(
    Map<String, dynamic> review,
    bool isDark,
    String courseUid,
  ) {
    final rating = (review['rating'] ?? 0.0) as double;
    final studentName = review['studentName'] ?? 'Student';
    final reviewText = review['reviewText'] ?? '';
    final createdAt = review['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(review['createdAt']).toLocal()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                child: Text(
                  studentName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  studentName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              // Report button
              IconButton(
                icon: Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: isDark
                      ? AppTheme.darkTextTertiary
                      : Colors.grey.shade500,
                ),
                tooltip: 'Report review',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: () => _showReportDialog(review, isDark, courseUid),
              ),
              const SizedBox(width: 4),
              // Rating stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reviewText,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showReportDialog(
    Map<String, dynamic> review,
    bool isDark,
    String courseUid,
  ) {
    String selectedReason = 'Inappropriate content';
    final reasons = [
      'Inappropriate content',
      'Spam or advertising',
      'Harassment or bullying',
      'Fake review',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.flag_rounded,
                color: isDark ? AppTheme.darkError : AppTheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Report Review',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting this review?',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ...reasons.map(
                (reason) => RadioListTile<String>(
                  title: Text(
                    reason,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  value: reason,
                  groupValue: selectedReason,
                  activeColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.accentColor,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  onChanged: (value) {
                    setDialogState(() => selectedReason = value!);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = selectedReason;
                final reviewId = review['reviewId'] ?? review['id'] ?? '';
                final dialogCtx = context;
                Navigator.pop(dialogCtx);

                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                if (currentUid == null) return;

                // Report as course review with courseUid as parentId
                final success = await AdminService().reportContent(
                  contentId: reviewId,
                  contentType: 'course_review', // Use course_review type
                  reason: reason,
                  reportedBy: currentUid,
                  parentId: courseUid,
                );

                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Review reported. Our team will review it.'
                            : 'Failed to report. Please try again.',
                      ),
                      backgroundColor: success
                          ? (isDark ? AppTheme.darkSuccess : AppTheme.success)
                          : (isDark ? AppTheme.darkError : AppTheme.error),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkError : AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledCourses() {
    final isDark = AppTheme.isDarkMode(context);

    if (enrolledCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_outline,
        title: 'No enrolled courses',
        subtitle: 'Explore and enroll in courses to start learning',
        showExploreButton: true,
      );
    }

    // Filter and sort enrolled courses
    var filteredCourses = _filterEnrolledCoursesByQuery(enrolledCourses);
    filteredCourses = _sortEnrolledCourses(filteredCourses);

    return RefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: Column(
        children: [
          // Search Bar for enrolled courses
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _enrolledSearchController,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
              onChanged: (value) {
                setState(() {
                  _enrolledSearchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search your enrolled courses...',
                hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                ),
                suffixIcon: _enrolledSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        onPressed: () {
                          setState(() {
                            _enrolledSearchController.clear();
                            _enrolledSearchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.getCardColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.getBorderColor(context),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.getBorderColor(context),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppTheme.darkPrimaryLight
                        : AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Filter chips for enrolled courses
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All',
                    'all',
                    _enrolledFilterBy == 'all',
                    isDark,
                    () {
                      setState(() => _enrolledFilterBy = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Recent',
                    'recent',
                    _enrolledFilterBy == 'recent',
                    isDark,
                    () {
                      setState(() => _enrolledFilterBy = 'recent');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'In Progress',
                    'progress',
                    _enrolledFilterBy == 'progress',
                    isDark,
                    () {
                      setState(() => _enrolledFilterBy = 'progress');
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Completed',
                    'completed',
                    _enrolledFilterBy == 'completed',
                    isDark,
                    () {
                      setState(() => _enrolledFilterBy = 'completed');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Results count when searching
          if (_enrolledSearchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 16,
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${filteredCourses.length} result${filteredCourses.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Course grid
          Expanded(
            child: filteredCourses.isEmpty
                ? _buildEmptyState(
                    icon: Icons.search_off,
                    title: 'No Results Found',
                    subtitle: 'Try searching with different keywords.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: filteredCourses.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: 0.52,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (context, index) {
                      final course = filteredCourses[index];
                      final progress =
                          courseProgress[course['courseUid']] ?? 0.0;

                      return CourseCard(
                        title: course['title'] ?? 'Untitled Course',
                        description: course['description'],
                        imageUrl: course['imageUrl'] ?? '',
                        createdAt: course['createdAt'],
                        isEnrolled: true,
                        progress: progress,
                        instructorName: course['teacherName'],
                        instructorRating: course['courseRating'] != null
                            ? (course['courseRating'] as num).toDouble()
                            : (course['teacherRating'] != null
                                  ? (course['teacherRating'] as num).toDouble()
                                  : null),
                        reviewCount:
                            course['courseReviewCount'] ??
                            course['reviewCount'],
                        videoCount: (() {
                          final v = course['videoCount'];
                          if (v is int) return v;
                          final vids = course['videos'];
                          if (vids is Map) return vids.length;
                          if (vids is List) return vids.length;
                          if (course['videoUrl'] != null ||
                              course['video'] != null) {
                            return 1;
                          }
                          return 0;
                        })(),
                        isFree: course['isFree'] ?? true,
                        price: (course['price'] as num?)?.toDouble(),
                        discountedPrice: (course['discountedPrice'] as num?)
                            ?.toDouble(),
                        category: course['category'],
                        onTap: () => _openCourse(course),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showExploreButton = false,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                        .withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            if (showExploreButton) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                              .withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.explore),
                  label: const Text('Explore Courses'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                    foregroundColor: const Color(0xFFF0F8FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _exploreSearchController.dispose();
    _enrolledSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEnrolledCourses() async {
    try {
      final fetched = await _courseService.getEnrolledCourses(
        studentUid: _studentUid,
      );
      if (!mounted) return;
      // Populate enrolled courses and compute per-course progress
      final Map<String, double> progressMap = {};
      for (final c in fetched) {
        final cid = c['courseUid'] as String?;
        if (cid == null) continue;
        try {
          final p = await _courseService.calculateCourseProgress(
            studentUid: _studentUid,
            courseUid: cid,
          );
          progressMap[cid] = p;
        } catch (_) {
          progressMap[cid] = 0.0;
        }
      }

      setState(() {
        enrolledCourses = fetched;
        courseProgress = progressMap;
      });

      // Cache progress map for faster loads
      try {
        _cacheService.set('course_progress_$_studentUid', courseProgress);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load enrolled courses: $e")),
      );
    }
  }
}
