import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/course_card.dart';
import 'package:eduverse/views/student/student_course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final CourseService _courseService = CourseService();
  final CacheService _cacheService = CacheService();
  final String _studentUid = FirebaseAuth.instance.currentUser!.uid;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool isLoading = true;
  List<Map<String, dynamic>> courses = [];
  List<Map<String, dynamic>> enrolledCourses = [];
  Map<String, double> courseProgress = {};

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final cacheKeyUnenrolled = 'unenrolled_courses_$_studentUid';
    final cacheKeyEnrolled = 'enrolled_courses_detail_$_studentUid';
    final cacheKeyProgress = 'course_progress_$_studentUid';

    // Check cache first for instant display
    final cachedUnenrolled = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyUnenrolled,
    );
    final cachedEnrolled = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyEnrolled,
    );
    final cachedProgress = _cacheService.get<Map<String, double>>(
      cacheKeyProgress,
    );

    if (cachedUnenrolled != null &&
        cachedEnrolled != null &&
        cachedProgress != null) {
      if (!mounted) return;
      setState(() {
        courses = cachedUnenrolled;
        enrolledCourses = cachedEnrolled;
        courseProgress = cachedProgress;
        isLoading = false;
      });
      // Refresh in background
      _refreshDataInBackground(
        cacheKeyUnenrolled,
        cacheKeyEnrolled,
        cacheKeyProgress,
      );
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);
    await Future.wait([_fetchUnenrolledCourses(), _fetchEnrolledCourses()]);

    // Cache the results
    _cacheService.set(cacheKeyUnenrolled, courses);
    _cacheService.set(cacheKeyEnrolled, enrolledCourses);
    _cacheService.set(cacheKeyProgress, courseProgress);

    if (!mounted) return;
    setState(() => isLoading = false);
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load courses: $e")));
      }
    }
  }

  Future<void> _fetchEnrolledCourses() async {
    try {
      final fetchedCourses = await _courseService.getEnrolledCourses(
        studentUid: _studentUid,
      );

      if (!mounted) return;

      // Load progress for each enrolled course
      final Map<String, double> progress = {};
      for (final course in fetchedCourses) {
        if (!mounted) return;
        final courseUid = course['courseUid'];
        final courseProgress = await _courseService.calculateCourseProgress(
          studentUid: _studentUid,
          courseUid: courseUid,
        );
        progress[courseUid] = courseProgress;
      }

      if (!mounted) return;
      setState(() {
        enrolledCourses = fetchedCourses;
        courseProgress = progress;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load enrolled courses: $e")),
        );
      }
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

      await _loadData();
    } catch (e) {
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
    ).then((_) => _loadData()); // Refresh on return
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
          decoration: BoxDecoration(gradient: isDark ? AppTheme.darkPrimaryGradient : AppTheme.primaryGradient),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildExploreCourses(), _buildEnrolledCourses()],
            ),
    );
  }

  Widget _buildExploreCourses() {
    final isDark = AppTheme.isDarkMode(context);
    // Filter courses based on search query
    final filteredCourses = _searchQuery.isEmpty
        ? courses
        : courses.where((course) {
            final title = (course['title'] ?? '').toString().toLowerCase();
            final description = (course['description'] ?? '')
                .toString()
                .toLowerCase();
            final teacherName = (course['teacherName'] ?? '')
                .toString()
                .toLowerCase();
            final query = _searchQuery.toLowerCase();
            return title.contains(query) ||
                description.contains(query) ||
                teacherName.contains(query);
          }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search courses, instructors...',
                hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppTheme.getTextSecondary(context)),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
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
                  borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Results count when searching
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    '${filteredCourses.length} result${filteredCourses.length != 1 ? 's' : ''} found',
                    style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 13),
                  ),
                ],
              ),
            ),

          // Course grid or empty state
          Expanded(
            child: filteredCourses.isEmpty
                ? _searchQuery.isNotEmpty
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
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
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
                          instructorRating: course['teacherRating'] != null
                              ? (course['teacherRating'] as num).toDouble()
                              : null,
                          reviewCount: course['reviewCount'],
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Enroll in Course')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Image.network(
                    course['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      child: const Icon(Icons.image, size: 40),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 120,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                course['title'] ?? 'Untitled Course',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                course['description'] ?? 'No description',
                style: TextStyle(color: Colors.grey.shade600),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to enroll in this course?',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _enrollInCourse(course['courseUid']);
            },
            icon: const Icon(Icons.check),
            label: const Text('Enroll Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledCourses() {
    if (enrolledCourses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bookmark_outline,
        title: 'No enrolled courses',
        subtitle: 'Explore and enroll in courses to start learning',
        showExploreButton: true,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: enrolledCourses.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final course = enrolledCourses[index];
            final progress = courseProgress[course['courseUid']] ?? 0.0;

            return CourseCard(
              title: course['title'] ?? 'Untitled Course',
              description: course['description'],
              imageUrl: course['imageUrl'] ?? '',
              createdAt: course['createdAt'],
              isEnrolled: true,
              progress: progress,
              onTap: () => _openCourse(course),
            );
          },
        ),
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
                color: (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor).withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.getTextPrimary(context)),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            if (showExploreButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.explore),
                label: const Text('Explore Courses'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
