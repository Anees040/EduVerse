import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/utils/route_transitions.dart';
import 'package:eduverse/views/teacher/create_course_wizard.dart';
import 'package:eduverse/views/teacher/teacher_course_manage_screen.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  /// Clear static cache - call on logout
  static void clearCache() {
    _TeacherCoursesScreenState._cachedCourses = null;
    _TeacherCoursesScreenState._cachedStudentCount = null;
    _TeacherCoursesScreenState._cachedUid = null;
    _TeacherCoursesScreenState._hasLoadedOnce = false;
  }

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen>
    with AutomaticKeepAliveClientMixin {
  final CourseService _courseService = CourseService();
  final CacheService _cacheService = CacheService();

  // Static cache to persist across widget rebuilds
  static List<Map<String, dynamic>>? _cachedCourses;
  static int? _cachedStudentCount;
  static String? _cachedUid;
  static bool _hasLoadedOnce = false;

  bool _isInitialLoading = true;
  List<Map<String, dynamic>> courses = [];
  int uniqueStudentCount = 0;

  // Search and filter state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'newest'; // newest, oldest, students, videos, rating
  bool _showFilters = false;

  Timer? _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 120);

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final currentUid = currentUser.uid;
    // Use cached data immediately if available AND belongs to current teacher
    if (_hasLoadedOnce && _cachedCourses != null && _cachedUid == currentUid) {
      courses = _cachedCourses!;
      uniqueStudentCount = _cachedStudentCount ?? 0;
      _isInitialLoading = false;
    }
    _fetchCourses();

    // Start periodic auto-refresh
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _fetchCourses(forceRefresh: true);
      }
    });
  }

  Future<void> _fetchCourses({bool forceRefresh = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final teacherUid = currentUser.uid;
    final cacheKeyCourses = 'teacher_all_courses_$teacherUid';
    final cacheKeyStudents = 'teacher_all_students_$teacherUid';

    // Use static cache if available and not forcing refresh AND belongs to current teacher
    if (!forceRefresh &&
        _hasLoadedOnce &&
        _cachedCourses != null &&
        _cachedUid == teacherUid) {
      if (mounted) {
        setState(() {
          courses = _cachedCourses!;
          uniqueStudentCount = _cachedStudentCount ?? 0;
          _isInitialLoading = false;
        });
      }
      return;
    }

    // Check CacheService if static cache is empty
    if (!forceRefresh) {
      final cachedCourses = _cacheService.get<List<Map<String, dynamic>>>(
        cacheKeyCourses,
      );
      final cachedStudents = _cacheService.get<int>(cacheKeyStudents);

      if (cachedCourses != null && cachedStudents != null) {
        _cachedCourses = cachedCourses;
        _cachedStudentCount = cachedStudents;
        _cachedUid = teacherUid;
        _hasLoadedOnce = true;
        if (mounted) {
          setState(() {
            courses = cachedCourses;
            uniqueStudentCount = cachedStudents;
            _isInitialLoading = false;
          });
        }
        // Refresh in background
        _refreshCoursesInBackground(
          teacherUid,
          cacheKeyCourses,
          cacheKeyStudents,
        );
        return;
      }
    }

    // Show loading only if no data yet
    if (!mounted) return;
    if (courses.isEmpty) {
      setState(() => _isInitialLoading = true);
    }

    try {
      final results = await Future.wait([
        _courseService.getTeacherCourses(teacherUid: teacherUid),
        _courseService.getUniqueStudentCount(teacherUid: teacherUid),
      ]);

      final fetchedCourses = results[0] as List<Map<String, dynamic>>;
      final studentCount = results[1] as int;

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
      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);

      // Update static cache
      _cachedCourses = fetchedCourses;
      _cachedStudentCount = studentCount;
      _cachedUid = teacherUid;
      _hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          courses = fetchedCourses;
          uniqueStudentCount = studentCount;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load courses: $e')));
      }
    }
  }

  Future<void> _refreshCoursesInBackground(
    String teacherUid,
    String cacheKeyCourses,
    String cacheKeyStudents,
  ) async {
    try {
      final results = await Future.wait([
        _courseService.getTeacherCourses(teacherUid: teacherUid),
        _courseService.getUniqueStudentCount(teacherUid: teacherUid),
      ]);

      final fetchedCourses = results[0] as List<Map<String, dynamic>>;
      final studentCount = results[1] as int;

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

      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);

      // Update static cache
      _cachedCourses = fetchedCourses;
      _cachedStudentCount = studentCount;
      _cachedUid = teacherUid;
      _hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          courses = fetchedCourses;
          uniqueStudentCount = studentCount;
        });
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  void _createNewCourse() {
    Navigator.push(
      context,
      SlideAndFadeRoute(page: const CreateCourseWizard()),
    ).then((result) {
      // Only refresh if a course was actually added
      if (result == true) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;
        // Refresh in background without showing loading indicator
        // since we already have data displayed
        _refreshCoursesInBackground(
          currentUser.uid,
          'teacher_all_courses_${currentUser.uid}',
          'teacher_all_students_${currentUser.uid}',
        );
      }
    });
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      // Refresh in background, don't clear cache to avoid loading flash
      _refreshCoursesInBackground(
        currentUser.uid,
        'teacher_all_courses_${currentUser.uid}',
        'teacher_all_students_${currentUser.uid}',
      );
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Filtered and sorted courses
  List<Map<String, dynamic>> get filteredCourses {
    List<Map<String, dynamic>> result = courses;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      result = result.where((course) {
        final title = (course['title'] ?? '').toString().toLowerCase();
        final description = (course['description'] ?? '')
            .toString()
            .toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'newest':
        result.sort(
          (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
        );
        break;
      case 'oldest':
        result.sort(
          (a, b) => (a['createdAt'] ?? 0).compareTo(b['createdAt'] ?? 0),
        );
        break;
      case 'students':
        result.sort(
          (a, b) =>
              (b['enrolledCount'] ?? 0).compareTo(a['enrolledCount'] ?? 0),
        );
        break;
      case 'videos':
        result.sort((a, b) {
          int aVideos = _getVideoCount(a);
          int bVideos = _getVideoCount(b);
          return bVideos.compareTo(aVideos);
        });
        break;
      case 'rating':
        result.sort(
          (a, b) =>
              (b['averageRating'] ?? 0.0).compareTo(a['averageRating'] ?? 0.0),
        );
        break;
    }

    return result;
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: _isInitialLoading && courses.isEmpty
          ? const Center(
              child: EngagingLoadingIndicator(
                message: 'Loading your courses...',
                size: 70,
              ),
            )
          : courses.isEmpty
          ? _buildEmptyState()
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => _fetchCourses(forceRefresh: true),
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                  child: _buildCoursesList(),
                ),
                // Removed visible loading indicator - refresh happens silently in background
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create',
        backgroundColor: AppTheme.getButtonColor(context),
        onPressed: _createNewCourse,
        icon: Icon(Icons.add, color: AppTheme.getButtonTextColor(context)),
        label: Text(
          'Create Course',
          style: TextStyle(
            color: AppTheme.getButtonTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = AppTheme.isDarkMode(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color:
                    (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                        .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.video_library_outlined,
                size: 64,
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No courses yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first course and start teaching!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
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
                onPressed: _createNewCourse,
                icon: const Icon(Icons.add),
                label: const Text('Create First Course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: const Color(0xFFF0F8FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesList() {
    final isDark = AppTheme.isDarkMode(context);
    final displayCourses = filteredCourses;

    return CustomScrollView(
      slivers: [
        // Stats header
        SliverToBoxAdapter(child: _buildStatsHeader()),

        // Search and filter section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : Colors.grey,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                          // Filter toggle
                          IconButton(
                            icon: Icon(
                              _showFilters
                                  ? Icons.filter_list_off
                                  : Icons.filter_list,
                              color: _showFilters
                                  ? (isDark
                                        ? AppTheme.darkAccent
                                        : AppTheme.primaryColor)
                                  : (isDark
                                        ? AppTheme.darkTextSecondary
                                        : Colors.grey),
                            ),
                            onPressed: () =>
                                setState(() => _showFilters = !_showFilters),
                          ),
                        ],
                      ),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkCard : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Sort/filter options
                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  _buildSortFilterSection(isDark),
                ],
              ],
            ),
          ),
        ),

        // Section title with count
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Courses',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                if (_searchQuery.isNotEmpty || _sortBy != 'newest')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                              .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${displayCourses.length}/${courses.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Courses grid or empty state
        displayCourses.isEmpty
            ? SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No courses match your search',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final course = displayCourses[index];
                    return _buildCourseCard(course, isDark);
                  }, childCount: displayCourses.length),
                ),
              ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSortFilterSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
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
              Icon(
                Icons.sort,
                size: 16,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSortChip('newest', 'Newest', Icons.schedule, isDark),
                _buildSortChip('oldest', 'Oldest', Icons.history, isDark),
                _buildSortChip(
                  'students',
                  'Most Students',
                  Icons.people,
                  isDark,
                ),
                _buildSortChip(
                  'videos',
                  'Most Videos',
                  Icons.video_library,
                  isDark,
                ),
                _buildSortChip('rating', 'Highest Rated', Icons.star, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(
    String value,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _sortBy = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                  : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary),
              ),
              const SizedBox(width: 4),
              Text(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, bool isDark) {
    final videoCount = _getVideoCount(course);
    final enrolledCount = course['enrolledCount'] ?? 0;
    final rating = (course['averageRating'] ?? 0.0) as double;
    final reviewCount = (course['reviewCount'] ?? 0) as int;
    final isFree = course['isFree'] ?? true;
    final price = (course['price'] as num?)?.toDouble() ?? 0.0;
    final discountedPrice = (course['discountedPrice'] as num?)?.toDouble();
    final category = course['category'] as String?;

    return GestureDetector(
      onTap: () => _openCourseManagement(course),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppTheme.darkAccent.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with price badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: (course['imageUrl'] as String? ?? '').isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: course['imageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          )
                        : _buildPlaceholderImage(isDark),
                  ),
                ),
                // Price badge (top-left)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildPriceBadge(
                    isDark,
                    isFree,
                    price,
                    discountedPrice,
                  ),
                ),
                // Category badge (top-right)
                if (category != null && category.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      course['title'] ?? 'Untitled Course',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Stats row - improved visibility
                    Row(
                      children: [
                        Icon(
                          Icons.video_library,
                          size: 14,
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$videoCount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.people,
                          size: 14,
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$enrolledCount',
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
                    const SizedBox(height: 6),

                    // Rating row
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: isDark
                              ? AppTheme.darkWarning
                              : AppTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reviewCount > 0
                              ? '${rating.toStringAsFixed(1)} ($reviewCount)'
                              : 'No reviews',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: reviewCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontStyle: reviewCount > 0
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // View Reviews link
                    if (reviewCount > 0)
                      GestureDetector(
                        onTap: () => _showCourseReviewsDialog(context, course),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'View Reviews',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor,
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
                      )
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Tap to manage',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppTheme.darkTextTertiary
                                : Colors.grey,
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
    );
  }

  Widget _buildPriceBadge(
    bool isDark,
    bool isFree,
    double price,
    double? discountedPrice,
  ) {
    if (isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkSuccess, AppTheme.darkSuccess.withOpacity(0.8)]
                : [AppTheme.success, AppTheme.success.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                  .withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'FREE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    // Paid course
    final hasDiscount = discountedPrice != null && discountedPrice < price;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.darkPrimary, AppTheme.darkAccent]
              : [AppTheme.primaryColor, AppTheme.primaryLight],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                .withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDiscount) ...[
            Text(
              '\$${price.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
                decorationColor: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            hasDiscount
                ? '\$${discountedPrice.toStringAsFixed(0)}'
                : '\$${price.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isDark) {
    return Container(
      color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(
        0.1,
      ),
      child: Center(
        child: Icon(
          Icons.video_library,
          size: 32,
          color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        ),
      ),
    );
  }

  void _showCourseReviewsDialog(
    BuildContext context,
    Map<String, dynamic> course,
  ) async {
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
                    'Reviews',
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
                itemBuilder: (ctx, index) {
                  final review = reviews[index];
                  final rating = (review['rating'] ?? 0.0) as double;
                  final studentName = review['studentName'] ?? 'Student';
                  final reviewText = review['reviewText'] ?? '';
                  final createdAt = review['createdAt'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          review['createdAt'],
                        ).toLocal()
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkElevated
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade200,
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < rating.round()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 14,
                                  color: isDark
                                      ? AppTheme.darkWarning
                                      : AppTheme.warning,
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
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
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

  Widget _buildStatsHeader() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.darkPrimaryGradient
            : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.menu_book,
              value: '${courses.length}',
              label: 'Total Courses',
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white30),
          Expanded(
            child: _buildStatCard(
              icon: Icons.people,
              value: '$uniqueStudentCount',
              label: 'Total Students',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }
}
