import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/views/student/ai_camera_screen.dart';
import 'package:eduverse/views/student/ai_chat_screen.dart';
import 'package:eduverse/views/student/student_course_detail_screen.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

class HomeTab extends StatefulWidget {
  final String uid;
  final String role;
  final VoidCallback? onSeeAllCourses;
  const HomeTab({
    super.key,
    required this.uid,
    required this.role,
    this.onSeeAllCourses,
  });

  // Static cache to persist data across widget rebuilds
  static String? cachedUserName;
  static List<Map<String, dynamic>>? cachedAllCourses;
  static Set<String>? cachedEnrolledCourseIds;
  static String? cachedUid;
  static bool hasLoadedOnce = false;

  /// Clear all static caches - call when data changes
  static void clearCache() {
    cachedUserName = null;
    cachedAllCourses = null;
    cachedEnrolledCourseIds = null;
    cachedUid = null;
    hasLoadedOnce = false;
  }

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  final userService = UserService();
  final _cacheService = CacheService();
  final _courseService = CourseService();

  String userName = "...";

  List<Map<String, dynamic>> allCourses = [];
  Set<String> enrolledCourseIds = {}; // Track enrolled courses
  bool _isInitialLoading = true;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Auto-scroll carousel
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88, initialPage: 0);

    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    // Use cached data immediately if available AND belongs to current user
    if (HomeTab.hasLoadedOnce &&
        HomeTab.cachedAllCourses != null &&
        HomeTab.cachedUid == currentUid) {
      userName = HomeTab.cachedUserName ?? "Student";
      allCourses = HomeTab.cachedAllCourses!;
      enrolledCourseIds = HomeTab.cachedEnrolledCourseIds ?? {};
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
    if (allCourses.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || allCourses.isEmpty) return;

      _currentPage++;
      if (_currentPage >= allCourses.length) {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Load all data in parallel for faster loading
  Future<void> _loadAllData() async {
    final studentUid = FirebaseAuth.instance.currentUser!.uid;
    final cacheKeyName = 'user_name_${widget.uid}';
    final cacheKeyCourses = 'all_courses_home';
    final cacheKeyEnrolled = 'enrolled_course_ids_$studentUid';

    // Use static cache if available AND belongs to current user
    if (HomeTab.hasLoadedOnce &&
        HomeTab.cachedAllCourses != null &&
        HomeTab.cachedUid == studentUid) {
      if (mounted) {
        setState(() {
          userName = HomeTab.cachedUserName ?? "Student";
          allCourses = HomeTab.cachedAllCourses!;
          enrolledCourseIds = HomeTab.cachedEnrolledCourseIds ?? {};
          _isInitialLoading = false;
        });
        _startAutoScroll();
      }
      return;
    }

    // Check cache first for instant display
    final cachedName = _cacheService.get<String>(cacheKeyName);
    final cachedCourses = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyCourses,
    );
    final cachedEnrolledIds = _cacheService.get<Set<String>>(cacheKeyEnrolled);

    if (cachedName != null && cachedCourses != null) {
      // Update static cache
      HomeTab.cachedUserName = cachedName;
      HomeTab.cachedAllCourses = cachedCourses;
      HomeTab.cachedEnrolledCourseIds = cachedEnrolledIds;
      HomeTab.cachedUid = studentUid;
      HomeTab.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          userName = cachedName;
          allCourses = cachedCourses;
          enrolledCourseIds = cachedEnrolledIds ?? {};
          _isInitialLoading = false;
        });
        _startAutoScroll();
      }
      // Refresh in background
      _refreshDataInBackground(
        studentUid,
        cacheKeyName,
        cacheKeyCourses,
        cacheKeyEnrolled,
      );
      return;
    }

    // Load in parallel
    try {
      final results = await Future.wait([
        userService.getUserName(uid: widget.uid, role: widget.role),
        _courseService.getAllCourses(), // Get ALL courses
        _courseService.getEnrolledCourses(
          studentUid: studentUid,
        ), // Get enrolled courses
      ]);

      final name = results[0] as String? ?? "Student";
      final courses = results[1] as List<Map<String, dynamic>>;
      final enrolled = results[2] as List<Map<String, dynamic>>;

      // Extract enrolled course IDs
      final enrolledIds = enrolled.map((c) => c['courseUid'] as String).toSet();

      // Cache the results
      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, courses);
      _cacheService.set(cacheKeyEnrolled, enrolledIds);

      // Update static cache
      HomeTab.cachedUserName = name;
      HomeTab.cachedAllCourses = courses;
      HomeTab.cachedEnrolledCourseIds = enrolledIds;
      HomeTab.cachedUid = studentUid;
      HomeTab.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          userName = name;
          allCourses = courses;
          enrolledCourseIds = enrolledIds;
          _isInitialLoading = false;
        });
        _startAutoScroll();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load data: $e")));
      }
    }
  }

  /// Refresh data in background without blocking UI
  Future<void> _refreshDataInBackground(
    String studentUid,
    String cacheKeyName,
    String cacheKeyCourses,
    String cacheKeyEnrolled,
  ) async {
    try {
      final results = await Future.wait([
        userService.getUserName(uid: widget.uid, role: widget.role),
        _courseService.getAllCourses(),
        _courseService.getEnrolledCourses(studentUid: studentUid),
      ]);

      final name = results[0] as String? ?? "Student";
      final courses = results[1] as List<Map<String, dynamic>>;
      final enrolled = results[2] as List<Map<String, dynamic>>;
      final enrolledIds = enrolled.map((c) => c['courseUid'] as String).toSet();

      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, courses);
      _cacheService.set(cacheKeyEnrolled, enrolledIds);

      // Update static cache
      HomeTab.cachedUserName = name;
      HomeTab.cachedAllCourses = courses;
      HomeTab.cachedEnrolledCourseIds = enrolledIds;
      HomeTab.cachedUid = studentUid;
      HomeTab.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          userName = name;
          allCourses = courses;
          enrolledCourseIds = enrolledIds;
        });
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  List<Map<String, dynamic>> get filteredCourses {
    if (searchQuery.isEmpty) return allCourses;
    return allCourses.where((course) {
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
                gradient: AppTheme.getGradient(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
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
                          "Continue your learning journey today",
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
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
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
                decoration: InputDecoration(
                  hintText: "Search all courses...",
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

            // Featured Courses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Featured Courses",
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

            // Auto-sliding carousel
            SizedBox(
              height: 220,
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
                                : "No courses available",
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
                            if (_pageController.position.haveDimensions) {
                              value = (_pageController.page! - index).abs();
                              value = (1 - (value * 0.15)).clamp(0.85, 1.0);
                            }
                            return Transform.scale(scale: value, child: child);
                          },
                          child: _buildCourseCard(course, isDark),
                        );
                      },
                    ),
            ),

            // Page indicator dots
            if (filteredCourses.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  filteredCourses.length.clamp(0, 8),
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

            // AI Learning Section
            Text(
              "AI Learning Tools",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 16),

            // Study with AI Card
            _buildFeatureCard(
              icon: Icons.smart_toy_outlined,
              title: "Study with AI",
              subtitle: "Chat with our AI assistant for personalized help",
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AIChatScreen(openNew: true),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Homework Help Card
            _buildFeatureCard(
              icon: Icons.camera_alt_outlined,
              title: "Homework Help",
              subtitle: "Snap a photo and get step-by-step solutions",
              color: AppTheme.accentColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MathwayHelpScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive course card for carousel with modern design
  Widget _buildCourseCard(Map<String, dynamic> course, bool isDark) {
    final imageUrl = course['imageUrl'] as String? ?? '';
    final title = course['title'] as String? ?? 'Untitled Course';
    final description = course['description'] as String? ?? '';
    final teacherName =
        course['teacherName'] as String? ?? 'Unknown Instructor';
    final courseUid = course['courseUid'] as String?;
    final isEnrolled =
        courseUid != null && enrolledCourseIds.contains(courseUid);
    final courseRating = course['courseRating'] as num?;
    final courseReviewCount = course['courseReviewCount'] as int?;
    int computeVideoCount(Map<String, dynamic> c) {
      final v = c['videoCount'];
      if (v is int) return v;
      final vids = c['videos'];
      if (vids is Map) return vids.length;
      if (vids is List) return vids.length;
      if (c['videoUrl'] != null || c['video'] != null) return 1;
      return 0;
    }

    final videoCount = computeVideoCount(course);
    final privateVideoCount = (() {
      final pv = course['privateVideoCount'];
      if (pv is int) return pv;
      return 0;
    })();

    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return GestureDetector(
      onTap: () {
        if (isEnrolled) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentCourseDetailScreen(
                courseUid: courseUid,
                courseTitle: title,
                imageUrl: imageUrl,
                description: description,
                createdAt: course['createdAt'],
              ),
            ),
          );
        } else {
          _showEnrollmentPrompt(course, isDark);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? accentColor.withOpacity(0.3) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? accentColor.withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Image with gradient overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              height: 95,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildPlaceholderImage(isDark, accentColor),
                            )
                          : _buildPlaceholderImage(isDark, accentColor),
                      // Gradient overlay for depth
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Enrollment badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEnrolled
                              ? Icons.play_arrow_rounded
                              : Icons.add_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isEnrolled ? 'Continue' : 'Enroll',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Video count badge
                if (videoCount > 0)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$videoCount videos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Show private video indicator
                          if (privateVideoCount > 0 && !isEnrolled) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.lock_outline,
                              color: Colors.amber.shade300,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '+$privateVideoCount',
                              style: TextStyle(
                                color: Colors.amber.shade300,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Course Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.getTextPrimary(context),
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Instructor with avatar
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withOpacity(0.7),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Rating or description
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : accentColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          courseRating != null &&
                              courseReviewCount != null &&
                              courseReviewCount > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  courseRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.getTextPrimary(context),
                                  ),
                                ),
                                Text(
                                  ' ($courseReviewCount reviews)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 12,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    description.isNotEmpty
                                        ? description
                                        : 'Explore this course',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.getTextSecondary(context),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isDark, Color accentColor) {
    return Container(
      height: 95,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [accentColor.withOpacity(0.3), accentColor.withOpacity(0.1)]
              : [accentColor.withOpacity(0.2), accentColor.withOpacity(0.05)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_rounded,
            size: 36,
            color: accentColor.withOpacity(0.6),
          ),
          const SizedBox(height: 4),
          Text(
            'EduVerse',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accentColor.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Show enrollment prompt dialog
  void _showEnrollmentPrompt(Map<String, dynamic> course, bool isDark) {
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
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.school,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enroll First',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need to enroll in this course before you can start learning.',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 12),
            Text(
              'Would you like to go to Explore Courses to enroll?',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
          ],
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
              // Navigate to explore courses tab
              widget.onSeeAllCourses?.call();
            },
            icon: const Icon(Icons.explore, size: 18),
            label: const Text('Explore Courses'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.getButtonColor(context),
              foregroundColor: AppTheme.getButtonTextColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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

    // Use brighter, more vibrant colors in dark mode
    final displayColor = isDark
        ? const Color(0xFF4ECDC4) // Vibrant teal for both (consistent)
        : color;

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
