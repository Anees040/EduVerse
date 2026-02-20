import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/views/student/ai_chat_screen.dart';
import 'package:eduverse/views/teacher/teacher_course_manage_screen.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/utils/route_transitions.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

class TeacherHomeTab extends StatefulWidget {
  final String uid;
  final String role;
  final VoidCallback? onSeeAllCourses;
  final VoidCallback? onSeeAllStudents;
  const TeacherHomeTab({
    super.key,
    required this.uid,
    required this.role,
    this.onSeeAllCourses,
    this.onSeeAllStudents,
  });

  // Static cache to persist data across widget rebuilds
  static String? cachedUserName;
  static List<Map<String, dynamic>>? cachedCourses;
  static int? cachedStudentCount;
  static List<Map<String, dynamic>>? cachedAnnouncements;
  static String? cachedUid;
  static bool hasLoadedOnce = false;

  /// Clear all static caches - call when data changes
  static void clearCache() {
    cachedUserName = null;
    cachedCourses = null;
    cachedStudentCount = null;
    cachedAnnouncements = null;
    cachedUid = null;
    hasLoadedOnce = false;
  }

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab>
    with AutomaticKeepAliveClientMixin {
  final userService = UserService();
  final _cacheService = CacheService();
  final _courseService = CourseService();

  List<Map<String, dynamic>> recentSubmissions = [];
  List<Map<String, dynamic>> announcements = [];
  bool _isInitialLoading = true;
  String userName = "...";
  List<Map<String, dynamic>> courses = [];
  int uniqueStudentCount = 0;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Auto-scroll carousel for teacher courses
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  // Theme helper
  bool get isDark => mounted ? AppTheme.isDarkMode(context) : false;

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88, initialPage: 0);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final currentUid = currentUser.uid;
    // Use cached data immediately if available AND belongs to current teacher
    if (TeacherHomeTab.hasLoadedOnce &&
        TeacherHomeTab.cachedCourses != null &&
        TeacherHomeTab.cachedUid == currentUid) {
      userName = TeacherHomeTab.cachedUserName ?? "Teacher";
      courses = TeacherHomeTab.cachedCourses!;
      uniqueStudentCount = TeacherHomeTab.cachedStudentCount ?? 0;
      announcements = TeacherHomeTab.cachedAnnouncements ?? [];
      _isInitialLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoScroll();
      });
    }

    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (filteredCourses.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || filteredCourses.isEmpty) return;

      _currentPage++;
      if (_currentPage >= filteredCourses.length) _currentPage = 0;

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Load all data in parallel with caching
  Future<void> _loadAllData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final teacherUid = currentUser.uid;
    final cacheKeyName = 'teacher_name_${widget.uid}';
    final cacheKeyCourses = 'teacher_courses_$teacherUid';
    final cacheKeyStudents = 'teacher_students_$teacherUid';
    final cacheKeyAnnouncements = 'teacher_announcements_$teacherUid';

    // Use static cache if available AND belongs to current teacher
    if (TeacherHomeTab.hasLoadedOnce &&
        TeacherHomeTab.cachedCourses != null &&
        TeacherHomeTab.cachedUid == teacherUid) {
      if (mounted) {
        setState(() {
          userName = TeacherHomeTab.cachedUserName ?? "Teacher";
          courses = TeacherHomeTab.cachedCourses!;
          uniqueStudentCount = TeacherHomeTab.cachedStudentCount ?? 0;
          announcements = TeacherHomeTab.cachedAnnouncements ?? [];
          _isInitialLoading = false;
        });
        _startAutoScroll();
      }
      return;
    }

    // Check cache first
    final cachedName = _cacheService.get<String>(cacheKeyName);
    final cachedCourses = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyCourses,
    );
    final cachedStudents = _cacheService.get<int>(cacheKeyStudents);
    final cachedAnnouncements = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyAnnouncements,
    );

    if (cachedName != null && cachedCourses != null && cachedStudents != null) {
      // Update static cache
      TeacherHomeTab.cachedUserName = cachedName;
      TeacherHomeTab.cachedCourses = cachedCourses;
      TeacherHomeTab.cachedStudentCount = cachedStudents;
      TeacherHomeTab.cachedAnnouncements = cachedAnnouncements;
      TeacherHomeTab.cachedUid = teacherUid;
      TeacherHomeTab.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          userName = cachedName;
          courses = cachedCourses;
          uniqueStudentCount = cachedStudents;
          announcements = cachedAnnouncements ?? [];
          _isInitialLoading = false;
        });
        _startAutoScroll();
      }
      // Refresh in background
      _refreshDataInBackground(
        teacherUid,
        cacheKeyName,
        cacheKeyCourses,
        cacheKeyStudents,
        cacheKeyAnnouncements,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isInitialLoading = true);

    try {
      final results = await Future.wait([
        userService.getUserName(role: widget.role, uid: widget.uid),
        CourseService().getTeacherCourses(teacherUid: teacherUid),
        CourseService().getUniqueStudentCount(teacherUid: teacherUid),
        _courseService.getTeacherAnnouncements(teacherUid: teacherUid),
      ]);

      final name = results[0] as String? ?? "Teacher";
      final fetchedCourses = results[1] as List<Map<String, dynamic>>;
      final studentCount = results[2] as int;
      final fetchedAnnouncements = results[3] as List<Map<String, dynamic>>;

      // Fetch rating stats for each course
      for (int i = 0; i < fetchedCourses.length; i++) {
        final courseUid = fetchedCourses[i]['courseUid'];
        try {
          final stats = await _courseService.getCourseRatingStats(
            courseUid: courseUid,
          );
          fetchedCourses[i]['averageRating'] = stats['averageRating'] ?? 0.0;
          fetchedCourses[i]['reviewCount'] = stats['reviewCount'] ?? 0;
        } catch (_) {
          fetchedCourses[i]['averageRating'] = 0.0;
          fetchedCourses[i]['reviewCount'] = 0;
        }
      }

      // Cache results
      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);
      _cacheService.set(cacheKeyAnnouncements, fetchedAnnouncements);

      // Update static cache
      TeacherHomeTab.cachedUserName = name;
      TeacherHomeTab.cachedCourses = fetchedCourses;
      TeacherHomeTab.cachedStudentCount = studentCount;
      TeacherHomeTab.cachedAnnouncements = fetchedAnnouncements;
      TeacherHomeTab.cachedUid = teacherUid;
      TeacherHomeTab.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          userName = name;
          courses = fetchedCourses;
          uniqueStudentCount = studentCount;
          announcements = fetchedAnnouncements;
          _isInitialLoading = false;
        });
        _startAutoScroll();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  Future<void> _refreshDataInBackground(
    String teacherUid,
    String cacheKeyName,
    String cacheKeyCourses,
    String cacheKeyStudents,
    String cacheKeyAnnouncements,
  ) async {
    try {
      final results = await Future.wait([
        userService.getUserName(role: widget.role, uid: widget.uid),
        CourseService().getTeacherCourses(teacherUid: teacherUid),
        CourseService().getUniqueStudentCount(teacherUid: teacherUid),
        _courseService.getTeacherAnnouncements(teacherUid: teacherUid),
      ]);

      final name = results[0] as String? ?? "Teacher";
      final fetchedCourses = results[1] as List<Map<String, dynamic>>;
      final studentCount = results[2] as int;
      final fetchedAnnouncements = results[3] as List<Map<String, dynamic>>;

      // Fetch rating stats for each course
      for (int i = 0; i < fetchedCourses.length; i++) {
        final courseUid = fetchedCourses[i]['courseUid'];
        try {
          final stats = await _courseService.getCourseRatingStats(
            courseUid: courseUid,
          );
          fetchedCourses[i]['averageRating'] = stats['averageRating'] ?? 0.0;
          fetchedCourses[i]['reviewCount'] = stats['reviewCount'] ?? 0;
        } catch (_) {
          fetchedCourses[i]['averageRating'] = 0.0;
          fetchedCourses[i]['reviewCount'] = 0;
        }
      }

      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);
      _cacheService.set(cacheKeyAnnouncements, fetchedAnnouncements);

      // Update static cache
      TeacherHomeTab.cachedUserName = name;
      TeacherHomeTab.cachedCourses = fetchedCourses;
      TeacherHomeTab.cachedStudentCount = studentCount;
      TeacherHomeTab.cachedAnnouncements = fetchedAnnouncements;
      TeacherHomeTab.cachedUid = teacherUid;
      TeacherHomeTab.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          userName = name;
          courses = fetchedCourses;
          uniqueStudentCount = studentCount;
          announcements = fetchedAnnouncements;
        });
        _startAutoScroll();
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  void _openCourseManagement(Map<String, dynamic> course) {
    Navigator.push(
      context,
      SlideAndFadeRoute(
        page: TeacherCourseManageScreen(
          courseUid: course['courseUid'],
          courseTitle: course['title'] ?? 'Untitled Course',
          imageUrl: course['imageUrl'] ?? '',
          description: course['description'] ?? '',
          enrolledCount: course['enrolledCount'] ?? 0,
        ),
      ),
    ).then((_) {
      _cacheService.clearPrefix('teacher_');
      _loadAllData();
    });
  }

  List<Map<String, dynamic>> get filteredCourses {
    if (searchQuery.isEmpty) return courses;
    return courses.where((course) {
      final title = (course['title'] as String? ?? '').toLowerCase();
      final description = (course['description'] as String? ?? '')
          .toLowerCase();
      final query = searchQuery.toLowerCase();
      return title.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isDark = AppTheme.isDarkMode(context);

    if (_isInitialLoading) {
      return const Center(
        child: EngagingLoadingIndicator(
          message: 'Loading your dashboard...',
          size: 70,
        ),
      );
    }

    return Container(
      color: AppTheme.getBackgroundColor(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.darkPrimaryGradient
                    : AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor)
                            .withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello, $userName!",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Manage your courses and students",
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildClickableStatCard(
                    "Total Courses",
                    courses.length.toString(),
                    Icons.book,
                    isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                    () {
                      // Navigate to Courses tab (index 1)
                      if (widget.onSeeAllCourses != null) {
                        widget.onSeeAllCourses!();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildClickableStatCard(
                    "Total Students",
                    uniqueStudentCount.toString(),
                    Icons.people,
                    isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                    () {
                      // Navigate to Students tab (index 2)
                      if (widget.onSeeAllStudents != null) {
                        widget.onSeeAllStudents!();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: isDark
                    ? Border.all(color: AppTheme.darkBorderColor)
                    : null,
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  hintText: "Search courses...",
                  hintStyle: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark
                        ? AppTheme.darkPrimaryLight
                        : AppTheme.primaryColor,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              searchQuery = "";
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.getCardColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Your Courses Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Your Courses",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                TextButton(
                  onPressed: widget.onSeeAllCourses,
                  child: const Text("See All"),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 210,
              child: filteredCourses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.book_outlined,
                            size: 48,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isNotEmpty
                                ? "No courses match '$searchQuery'"
                                : "No courses created yet",
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      padEnds: true,
                      itemCount: filteredCourses.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final course = filteredCourses[index];
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            double dx = 0.0;
                            if (_pageController.hasClients) {
                              final page =
                                  _pageController.page ??
                                  _pageController.initialPage.toDouble();
                              final delta = page - index;
                              value = (delta).abs();
                              value = (1 - (value * 0.15))
                                  .clamp(0.85, 1.0)
                                  .toDouble();
                              dx = (delta) * -30; // horizontal parallax
                            }
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: Transform.scale(
                                scale: value,
                                child: child,
                              ),
                            );
                          },
                          child: InkWell(
                            onTap: () => _openCourseManagement(course),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 170,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.getCardColor(context),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? (AppTheme.darkAccent).withOpacity(0.3)
                                      : Colors.grey.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? AppTheme.darkAccent.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.10),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image + overlays
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(18),
                                            ),
                                        child:
                                            (course['imageUrl'] as String? ??
                                                    '')
                                                .isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl:
                                                    course['imageUrl']
                                                        as String,
                                                height: 95,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey,
                                                        ),
                                              )
                                            : Container(
                                                height: 95,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: isDark
                                                        ? [
                                                            AppTheme.darkAccent
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            AppTheme.darkAccent
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                          ]
                                                        : [
                                                            AppTheme
                                                                .primaryColor
                                                                .withOpacity(
                                                                  0.15,
                                                                ),
                                                            AppTheme
                                                                .primaryColor
                                                                .withOpacity(
                                                                  0.05,
                                                                ),
                                                          ],
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.image,
                                                  size: 40,
                                                ),
                                              ),
                                      ),
                                      // gradient overlay
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.3),
                                              ],
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(18),
                                                ),
                                          ),
                                        ),
                                      ),
                                      // (Manage badge removed for cleaner card look)
                                      // enrolled count moved below title for cleaner layout
                                    ],
                                  ),
                                  // Info
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        12,
                                        8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            course['title'] as String? ??
                                                'Untitled Course',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: AppTheme.getTextPrimary(
                                                context,
                                              ),
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          // Stats row with videos, students, rating
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.video_library,
                                                size: 12,
                                                color: isDark
                                                    ? AppTheme.darkAccent
                                                    : AppTheme.primaryColor,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${_getVideoCount(course)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppTheme.getTextPrimary(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                Icons.people,
                                                size: 12,
                                                color: isDark
                                                    ? AppTheme.darkAccent
                                                    : AppTheme.primaryColor,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${course['enrolledCount'] ?? 0}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppTheme.getTextPrimary(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                Icons.star_rounded,
                                                size: 12,
                                                color: isDark
                                                    ? AppTheme.darkWarning
                                                    : AppTheme.warning,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                _getCourseRating(course),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppTheme.getTextSecondary(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(
                                              DateTime.fromMillisecondsSinceEpoch(
                                                course['createdAt'] ?? 0,
                                              ).toLocal(),
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.getTextSecondary(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (filteredCourses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  math.min(filteredCourses.length, 8),
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? (isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor)
                          : (isDark ? Colors.white24 : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // AI Learning Tools (match student)
            Text(
              "AI Learning Tools",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.smart_toy_outlined,
              title: "Get Help from AI",
              subtitle: "Ask questions and get instant assistance",
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  SlideAndFadeRoute(page: const AIChatScreen(openNew: true)),
                );
              },
            ),

            const SizedBox(height: 24),

            // Announcements
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Announcements",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                Row(
                  children: [
                    if (announcements.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color:
                              (isDark ? AppTheme.darkWarning : AppTheme.warning)
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${announcements.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.darkWarning
                                : AppTheme.warning,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: () => _showCreateAnnouncementDialog(context),
                      borderRadius: BorderRadius.circular(8),
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
                                  .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 14,
                              color: isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'New',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Announcement list or empty state
            if (announcements.isEmpty)
              GestureDetector(
                onTap: () => _showCreateAnnouncementDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade200,
                      style: BorderStyle.solid,
                    ),
                  ),
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
                          Icons.campaign_outlined,
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "No Announcements Yet",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Tap to create your first announcement for students",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.add_circle_outline,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...announcements
                  .take(3)
                  .map((announcement) => _buildAnnouncementCard(announcement)),

            // View all announcements link
            if (announcements.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _showAllAnnouncementsDialog(context),
                  child: Text(
                    'View All Announcements (${announcements.length})',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
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

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final priority = announcement['priority'] ?? 'normal';
    final isActive = announcement['isActive'] ?? true;
    final createdAt = announcement['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            announcement['createdAt'],
          ).toLocal()
        : null;

    Color priorityColor;
    IconData priorityIcon;
    switch (priority) {
      case 'urgent':
        priorityColor = isDark ? AppTheme.darkError : AppTheme.error;
        priorityIcon = Icons.priority_high;
        break;
      case 'important':
        priorityColor = isDark ? AppTheme.darkWarning : AppTheme.warning;
        priorityIcon = Icons.warning_amber;
        break;
      default:
        priorityColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
        priorityIcon = Icons.campaign;
    }

    return GestureDetector(
      onTap: () => _showAnnouncementDetailsDialog(context, announcement),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? priorityColor.withOpacity(0.35)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? priorityColor.withOpacity(0.08)
                  : Colors.transparent,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(priorityIcon, color: priorityColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          announcement['title'] ?? 'Announcement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isActive
                                ? (isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary)
                                : (isDark
                                      ? AppTheme.darkTextTertiary
                                      : Colors.grey),
                          ),
                        ),
                      ),
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcement['message'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive
                          ? (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary)
                          : (isDark ? AppTheme.darkTextTertiary : Colors.grey),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 11,
                        color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        createdAt != null
                            ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                            : 'Recently',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : Colors.grey,
                        ),
                      ),
                      if (announcement['courseUid'] != null) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.book_outlined,
                          size: 11,
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Specific course',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextTertiary
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementDialog(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedPriority = 'normal';
    String? selectedCourseUid;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.campaign,
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Create Announcement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title field
                  TextField(
                    controller: titleController,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.darkElevated
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Message field
                  TextField(
                    controller: messageController,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      labelStyle: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppTheme.darkElevated
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Priority selector
                  Text(
                    'Priority',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPriorityChip(
                        'normal',
                        'Normal',
                        Icons.campaign,
                        Colors.blue,
                        selectedPriority,
                        (val) {
                          setDialogState(() => selectedPriority = val);
                        },
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityChip(
                        'important',
                        'Important',
                        Icons.warning_amber,
                        Colors.orange,
                        selectedPriority,
                        (val) {
                          setDialogState(() => selectedPriority = val);
                        },
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityChip(
                        'urgent',
                        'Urgent',
                        Icons.priority_high,
                        Colors.red,
                        selectedPriority,
                        (val) {
                          setDialogState(() => selectedPriority = val);
                        },
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Course selector
                  Text(
                    'Send To',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkElevated
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedCourseUid,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? AppTheme.darkElevated
                            : Colors.white,
                        hint: Text(
                          'All Courses (All Students)',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'All Courses (All Students)',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          ...courses.map(
                            (course) => DropdownMenuItem<String?>(
                              value: course['courseUid'],
                              child: Text(
                                course['title'] ?? 'Untitled',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => selectedCourseUid = val),
                      ),
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
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    messageController.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please fill in all fields')),
                  );
                  return;
                }

                // Store values before closing dialog
                final title = titleController.text;
                final message = messageController.text;
                final courseUid = selectedCourseUid;
                final priority = selectedPriority;

                Navigator.pop(ctx);

                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;
                  final teacherUid = currentUser.uid;

                  // Create announcement data for optimistic UI update
                  final newAnnouncement = {
                    'announcementId': DateTime.now().millisecondsSinceEpoch
                        .toString(),
                    'title': title,
                    'message': message,
                    'courseUid': courseUid,
                    'priority': priority,
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                    'isActive': true,
                  };

                  // Optimistic UI update - add to list immediately with animation
                  setState(() {
                    announcements.insert(0, newAnnouncement);
                  });

                  // Clear cache and save to backend
                  _cacheService.clearPrefix('teacher_announcements_');

                  await _courseService.createAnnouncement(
                    teacherUid: teacherUid,
                    title: title,
                    message: message,
                    courseUid: courseUid,
                    priority: priority,
                  );

                  // Update cache with new data
                  _cacheService.set(
                    'teacher_announcements_$teacherUid',
                    announcements,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Announcement created successfully! 📢'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  // Revert optimistic update on failure
                  setState(() {
                    announcements.removeWhere(
                      (a) => a['title'] == title && a['message'] == message,
                    );
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create announcement: $e'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.send),
              label: const Text('Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(
    String value,
    String label,
    IconData icon,
    Color color,
    String selected,
    Function(String) onSelect,
    bool isDark,
  ) {
    final isSelected = selected == value;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.2)
                : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? color
                    : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? color
                      : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDetailsDialog(
    BuildContext context,
    Map<String, dynamic> announcement,
  ) {
    final isDark = AppTheme.isDarkMode(context);
    final priority = announcement['priority'] ?? 'normal';
    final isActive = announcement['isActive'] ?? true;
    final createdAt = announcement['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            announcement['createdAt'],
          ).toLocal()
        : null;

    Color priorityColor;
    switch (priority) {
      case 'urgent':
        priorityColor = isDark ? AppTheme.darkError : AppTheme.error;
        break;
      case 'important':
        priorityColor = isDark ? AppTheme.darkWarning : AppTheme.warning;
        break;
      default:
        priorityColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
    }

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
                color: priorityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.campaign, color: priorityColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                announcement['title'] ?? 'Announcement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                priority.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: priorityColor,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              announcement['message'] ?? '',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            if (createdAt != null)
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Posted: ${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isActive ? Icons.visibility : Icons.visibility_off,
                  size: 14,
                  color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle active button
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) return;
              final teacherUid = currentUser.uid;
              final announcementId = announcement['announcementId'];
              final newActiveStatus = !isActive;

              // Optimistic UI update
              setState(() {
                final index = announcements.indexWhere(
                  (a) => a['announcementId'] == announcementId,
                );
                if (index != -1) {
                  announcements[index] = {
                    ...announcements[index],
                    'isActive': newActiveStatus,
                  };
                }
              });

              try {
                await _courseService.toggleAnnouncementActive(
                  teacherUid: teacherUid,
                  announcementId: announcementId,
                  isActive: newActiveStatus,
                );
                _cacheService.clearPrefix('teacher_announcements_');
                _cacheService.set(
                  'teacher_announcements_$teacherUid',
                  announcements,
                );
              } catch (e) {
                // Revert on failure
                setState(() {
                  final index = announcements.indexWhere(
                    (a) => a['announcementId'] == announcementId,
                  );
                  if (index != -1) {
                    announcements[index] = {
                      ...announcements[index],
                      'isActive': isActive, // Revert to original
                    };
                  }
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              }
            },
            icon: Icon(
              isActive ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
            label: Text(
              isActive ? 'Deactivate' : 'Activate',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          // Delete button
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) return;
              final teacherUid = currentUser.uid;
              final announcementId = announcement['announcementId'];

              // Store for potential undo
              final removedAnnouncement = Map<String, dynamic>.from(
                announcement,
              );
              final removedIndex = announcements.indexWhere(
                (a) => a['announcementId'] == announcementId,
              );

              // Optimistic UI update - remove immediately
              setState(() {
                announcements.removeWhere(
                  (a) => a['announcementId'] == announcementId,
                );
              });

              try {
                await _courseService.deleteAnnouncement(
                  teacherUid: teacherUid,
                  announcementId: announcementId,
                );

                // Clear cache and update
                _cacheService.clearPrefix('teacher_announcements_');
                _cacheService.set(
                  'teacher_announcements_$teacherUid',
                  announcements,
                );

                if (mounted) {
                  final messenger = ScaffoldMessenger.of(context);

                  messenger.showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text('Announcement deleted'),
                        ],
                      ),
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      action: SnackBarAction(
                        label: 'UNDO',
                        textColor: AppTheme.warning,
                        onPressed: () async {
                          // Restore locally
                          setState(() {
                            if (removedIndex >= 0 &&
                                removedIndex <= announcements.length) {
                              announcements.insert(
                                removedIndex,
                                removedAnnouncement,
                              );
                            } else {
                              announcements.insert(0, removedAnnouncement);
                            }
                          });
                          // Restore to backend
                          try {
                            await _courseService.createAnnouncement(
                              teacherUid: teacherUid,
                              title: removedAnnouncement['title'] ?? '',
                              message: removedAnnouncement['message'] ?? '',
                              courseUid: removedAnnouncement['courseUid'],
                              priority:
                                  removedAnnouncement['priority'] ?? 'normal',
                            );
                            _cacheService.clearPrefix('teacher_announcements_');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.restore,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Announcement restored'),
                                    ],
                                  ),
                                  backgroundColor: AppTheme.success,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          } catch (_) {}
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                // Revert on failure
                setState(() {
                  if (removedIndex >= 0 &&
                      removedIndex <= announcements.length) {
                    announcements.insert(removedIndex, removedAnnouncement);
                  } else {
                    announcements.insert(0, removedAnnouncement);
                  }
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: isDark ? AppTheme.darkError : AppTheme.error,
            ),
            label: Text(
              'Delete',
              style: TextStyle(
                color: isDark ? AppTheme.darkError : AppTheme.error,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAllAnnouncementsDialog(BuildContext context) {
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
                Icons.campaign,
                color: isDark ? AppTheme.darkWarning : AppTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'All Announcements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.5,
          child: announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 48,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No announcements yet',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: announcements.length,
                  itemBuilder: (ctx, index) =>
                      _buildAnnouncementCard(announcements[index]),
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateAnnouncementDialog(context);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getVideoCount(Map<String, dynamic> course) {
    final v = course['videoCount'];
    if (v is int) return v;
    final vids = course['videos'];
    if (vids is Map) return vids.length;
    if (vids is List) return vids.length;
    if (course['videoUrl'] != null || course['video'] != null) return 1;
    return 0;
  }

  String _getCourseRating(Map<String, dynamic> course) {
    final rating = course['averageRating'];
    if (rating == null) return '0.0';
    if (rating is double) return rating.toStringAsFixed(1);
    if (rating is int) return rating.toDouble().toStringAsFixed(1);
    if (rating is String) {
      final parsed = double.tryParse(rating);
      return parsed?.toStringAsFixed(1) ?? '0.0';
    }
    return '0.0';
  }

  Widget _buildClickableStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    // Use vibrant colors in dark mode
    final displayColor = isDark
        ? (color == AppTheme.primaryColor
              ? const Color(0xFF9B7DFF) // Vibrant purple for courses
              : const Color(0xFF4ECDC4)) // Vibrant teal for students
        : color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? Border.all(color: displayColor.withOpacity(0.3))
              : null,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: displayColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        colors: [
                          displayColor.withOpacity(0.25),
                          displayColor.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDark ? null : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(color: displayColor.withOpacity(0.3))
                    : null,
              ),
              child: Icon(icon, color: displayColor, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: displayColor,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode(context);

    // Use brighter, more vibrant colors in dark mode (match student teal)
    final displayColor = isDark ? const Color(0xFF4ECDC4) : color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? displayColor.withOpacity(0.3)
                : color.withOpacity(0.2),
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: displayColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        colors: [
                          displayColor.withOpacity(0.25),
                          displayColor.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDark ? null : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(color: displayColor.withOpacity(0.3))
                    : null,
              ),
              child: Icon(icon, color: displayColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark
                  ? displayColor.withOpacity(0.7)
                  : AppTheme.getTextSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
