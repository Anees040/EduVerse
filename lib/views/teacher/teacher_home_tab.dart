import 'package:firebase_auth/firebase_auth.dart';
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

class TeacherHomeTab extends StatefulWidget {
  final String uid;
  final String role;
  final VoidCallback? onSeeAllCourses;
  const TeacherHomeTab({
    super.key,
    required this.uid,
    required this.role,
    this.onSeeAllCourses,
  });

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab>
    with AutomaticKeepAliveClientMixin {
  final userService = UserService();
  final _cacheService = CacheService();
  List<Map<String, dynamic>> recentSubmissions = [];
  bool isLoading = true;
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
    final teacherUid = FirebaseAuth.instance.currentUser!.uid;
    final cacheKeyName = 'teacher_name_${widget.uid}';
    final cacheKeyCourses = 'teacher_courses_$teacherUid';
    final cacheKeyStudents = 'teacher_students_$teacherUid';

    // Check cache first
    final cachedName = _cacheService.get<String>(cacheKeyName);
    final cachedCourses = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyCourses,
    );
    final cachedStudents = _cacheService.get<int>(cacheKeyStudents);

    if (cachedName != null && cachedCourses != null && cachedStudents != null) {
      setState(() {
        userName = cachedName;
        courses = cachedCourses;
        uniqueStudentCount = cachedStudents;
        isLoading = false;
      });
      _startAutoScroll();
      // Refresh in background
      _refreshDataInBackground(
        teacherUid,
        cacheKeyName,
        cacheKeyCourses,
        cacheKeyStudents,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        userService.getUserName(role: widget.role, uid: widget.uid),
        CourseService().getTeacherCourses(teacherUid: teacherUid),
        CourseService().getUniqueStudentCount(teacherUid: teacherUid),
      ]);

      final name = results[0] as String? ?? "Teacher";
      final fetchedCourses = results[1] as List<Map<String, dynamic>>;
      final studentCount = results[2] as int;

      // Cache results
      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);

      if (mounted) {
        setState(() {
          userName = name;
          courses = fetchedCourses;
          uniqueStudentCount = studentCount;
          isLoading = false;
        });
        _startAutoScroll();
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
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
  ) async {
    try {
      final results = await Future.wait([
        userService.getUserName(role: widget.role, uid: widget.uid),
        CourseService().getTeacherCourses(teacherUid: teacherUid),
        CourseService().getUniqueStudentCount(teacherUid: teacherUid),
      ]);

      final name = results[0] as String? ?? "Teacher";
      final fetchedCourses = results[1] as List<Map<String, dynamic>>;
      final studentCount = results[2] as int;

      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);

      if (mounted) {
        setState(() {
          userName = name;
          courses = fetchedCourses;
          uniqueStudentCount = studentCount;
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
      MaterialPageRoute(
        builder: (context) => TeacherCourseManageScreen(
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

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
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
                  child: _buildStatCard(
                    "Total Courses",
                    courses.length.toString(),
                    Icons.book,
                    isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    "Total Students",
                    uniqueStudentCount.toString(),
                    Icons.people,
                    isDark ? AppTheme.darkAccent : AppTheme.accentColor,
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
                              final page = _pageController.page ?? _pageController.initialPage.toDouble();
                              final delta = page - index;
                              value = (delta).abs();
                              value = (1 - (value * 0.15)).clamp(0.85, 1.0) as double;
                              dx = (delta) * -30; // horizontal parallax
                            }
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: Transform.scale(scale: value, child: child),
                            );
                          },
                          child: InkWell(
                            onTap: () => _openCourseManagement(course),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 170,
                              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(18),
                                        ),
                                        child: (course['imageUrl'] as String? ?? '').isNotEmpty
                                            ? Image.network(
                                                course['imageUrl'] as String,
                                                height: 95,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  height: 95,
                                                  color: AppTheme.primaryColor.withOpacity(0.08),
                                                  child: const Icon(
                                                    Icons.image,
                                                    size: 40,
                                                    color: AppTheme.primaryColor,
                                                  ),
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
                                                        ? [AppTheme.darkAccent.withOpacity(0.3), AppTheme.darkAccent.withOpacity(0.1)]
                                                        : [AppTheme.primaryColor.withOpacity(0.15), AppTheme.primaryColor.withOpacity(0.05)],
                                                  ),
                                                ),
                                                child: const Icon(Icons.image, size: 40),
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
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            course['title'] as String? ?? 'Untitled Course',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: AppTheme.getTextPrimary(context),
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "${course['enrolledCount'] ?? 0} Students",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.getTextSecondary(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(
                                              DateTime.fromMillisecondsSinceEpoch(course['createdAt'] ?? 0).toLocal(),
                                            ),
                                            style: TextStyle(fontSize: 11, color: AppTheme.getTextSecondary(context)),
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
                  MaterialPageRoute(builder: (context) => const AIChatScreen(openNew: true)),
                );
              },
            ),

            const SizedBox(height: 24),

            // Announcements
            Text(
              "Announcements",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppTheme.warning.withOpacity(0.35)
                      : AppTheme.warning.withOpacity(0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? AppTheme.warning.withOpacity(0.06)
                        : AppTheme.warning.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign,
                      color: AppTheme.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Midterm Schedule Released",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Please upload question papers on time.",
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    // Use vibrant colors in dark mode
    final displayColor = isDark
        ? (color == AppTheme.primaryColor
              ? const Color(0xFF9B7DFF) // Vibrant purple for courses
              : const Color(0xFF4ECDC4)) // Vibrant teal for students
        : color;

    return Container(
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
    final displayColor = isDark
        ? const Color(0xFF4ECDC4)
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
