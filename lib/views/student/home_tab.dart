import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:eduverse/widgets/study_streak_card.dart';
import 'package:eduverse/services/course_recommendation_service.dart';
import 'package:eduverse/features/admin/services/admin_feature_service.dart';

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

  // Recommendations
  final _recommendationService = CourseRecommendationService();
  List<Map<String, dynamic>> _recommendedCourses = [];
  bool _isLoadingRecommendations = false;

  // Platform Announcements
  final _announcementService = AdminFeatureService();
  List<Map<String, dynamic>> _announcements = [];

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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final currentUid = currentUser.uid;
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
    _loadAnnouncements();
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final studentUid = currentUser.uid;
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
        _loadRecommendations();
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
        _loadRecommendations();
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

  /// Load personalized course recommendations
  Future<void> _loadRecommendations() async {
    if (_isLoadingRecommendations) return;
    _isLoadingRecommendations = true;
    try {
      final recs = await _recommendationService.getRecommendations(limit: 6);
      if (mounted) {
        setState(() {
          _recommendedCourses = recs;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }

  /// Load platform announcements for students
  Future<void> _loadAnnouncements() async {
    try {
      final items = await _announcementService.getActiveAnnouncementsForUser('student');
      if (mounted) {
        setState(() => _announcements = items);
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
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
            const SizedBox(height: 16),

            // Platform Announcements
            if (_announcements.isNotEmpty)
              _buildAnnouncementsSection(isDark),

            // Study Streak & Stats
            const StudyStreakCard(),
            const SizedBox(height: 20),

            // Recommended For You
            if (_recommendedCourses.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            AppTheme.darkAccent.withOpacity(0.08),
                            AppTheme.darkCard.withOpacity(0.5),
                          ]
                        : [
                            AppTheme.primaryColor.withOpacity(0.04),
                            AppTheme.accentColor.withOpacity(0.04),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorderColor.withOpacity(0.5)
                        : AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                                    isDark ? AppTheme.darkAccent.withOpacity(0.7) : AppTheme.accentColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Recommended For You",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.getTextPrimary(context),
                                  ),
                                ),
                                Text(
                                  "Personalized by AI",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                              size: 18,
                            ),
                          ),
                          onPressed: _loadRecommendations,
                          tooltip: 'Refresh recommendations',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recommendedCourses.length,
                        itemBuilder: (context, index) {
                          final course = _recommendedCourses[index];
                          return _buildRecommendationCard(course, isDark);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

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
              height: 260,
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

  /// Professional recommendation card with rich info
  Widget _buildRecommendationCard(Map<String, dynamic> course, bool isDark) {
    final title = (course['title'] as String? ?? 'Course').toString();
    final category = (course['category'] as String? ?? '').toString();
    final imageUrl = (course['imageUrl'] as String? ?? '').toString();
    final courseUid = course['courseUid'] as String?;
    final price = course['price'];
    final isFree = price == null || price == 0 || price == '0' || price == 'free';
    final rating = course['rating'];
    final ratingStr = rating != null ? (rating is num ? rating.toStringAsFixed(1) : rating.toString()) : null;
    final enrolledCount = course['enrolledStudents'] is Map
        ? (course['enrolledStudents'] as Map).length
        : (course['enrolledCount'] is int ? course['enrolledCount'] as int : null);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return GestureDetector(
      onTap: () {
        if (courseUid != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentCourseDetailScreen(
                courseUid: courseUid,
                courseTitle: title,
                imageUrl: imageUrl,
                description: course['description'] as String? ?? '',
                createdAt: course['createdAt'],
              ),
            ),
          );
        }
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 105,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withOpacity(0.15),
                                  accentColor.withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image,
                                color: accentColor.withOpacity(0.3),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 105,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withOpacity(0.15),
                                  accentColor.withOpacity(0.05),
                                ],
                              ),
                            ),
                            child: Icon(Icons.school, color: accentColor),
                          ),
                        )
                      : Container(
                          height: 105,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor.withOpacity(0.15),
                                accentColor.withOpacity(0.05),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.school, color: accentColor, size: 30),
                          ),
                        ),
                ),
                // Bottom gradient over image
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Price badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFree ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      isFree ? 'FREE' : '\$$price',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Rating badge (bottom left)
                if (ratingStr != null)
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            ratingStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            // Bottom row: category + students
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  if (category.isNotEmpty)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (enrolledCount != null && enrolledCount > 0) ...[
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_outlined,
                          size: 12,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$enrolledCount',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
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
      height: 120,
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

  Widget _buildAnnouncementsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.campaign_rounded,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                size: 20),
            const SizedBox(width: 6),
            Text(
              'Announcements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._announcements.take(3).map((a) => _buildAnnouncementCard(a, isDark)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement, bool isDark) {
    final priority = announcement['priority'] as String? ?? 'normal';
    final Color borderColor;
    switch (priority) {
      case 'urgent':
        borderColor = Colors.red;
        break;
      case 'important':
        borderColor = Colors.orange;
        break;
      default:
        borderColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (priority != 'normal')
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(color: borderColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: Text(
                  announcement['title'] as String? ?? '',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            announcement['message'] as String? ?? '',
            style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
