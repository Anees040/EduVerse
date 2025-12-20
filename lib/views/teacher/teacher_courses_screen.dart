import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/teacher/add_course_screen.dart';
import 'package:eduverse/views/teacher/teacher_course_manage_screen.dart';
import 'package:eduverse/widgets/course_card.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen>
    with AutomaticKeepAliveClientMixin {
  final CourseService _courseService = CourseService();
  final CacheService _cacheService = CacheService();
  bool isLoading = true;
  List<Map<String, dynamic>> courses = [];
  int uniqueStudentCount = 0;

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final teacherUid = FirebaseAuth.instance.currentUser!.uid;
    final cacheKeyCourses = 'teacher_all_courses_$teacherUid';
    final cacheKeyStudents = 'teacher_all_students_$teacherUid';

    // Check cache first
    final cachedCourses = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyCourses,
    );
    final cachedStudents = _cacheService.get<int>(cacheKeyStudents);

    if (cachedCourses != null && cachedStudents != null) {
      setState(() {
        courses = cachedCourses;
        uniqueStudentCount = cachedStudents;
        isLoading = false;
      });
      // Refresh in background
      _refreshCoursesInBackground(
        teacherUid,
        cacheKeyCourses,
        cacheKeyStudents,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        _courseService.getTeacherCourses(teacherUid: teacherUid),
        _courseService.getUniqueStudentCount(teacherUid: teacherUid),
      ]);

      final fetchedCourses = results[0] as List<Map<String, dynamic>>;
      final studentCount = results[1] as int;

      // Cache results
      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);

      setState(() {
        courses = fetchedCourses;
        uniqueStudentCount = studentCount;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
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

      _cacheService.set(cacheKeyCourses, fetchedCourses);
      _cacheService.set(cacheKeyStudents, studentCount);

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
      MaterialPageRoute(builder: (_) => const AddCourseScreen()),
    ).then((_) {
      // Clear cache to force reload
      _cacheService.clearPrefix('teacher_');
      _fetchCourses();
    });
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
      // Clear cache to force reload
      _cacheService.clearPrefix('teacher_');
      _fetchCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
            )
          : courses.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchCourses,
              color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
              child: _buildCoursesList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDark
            ? AppTheme.darkPrimaryLight
            : AppTheme.primaryColor,
        onPressed: _createNewCourse,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Course',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    return CustomScrollView(
      slivers: [
        // Stats header
        SliverToBoxAdapter(child: _buildStatsHeader()),

        // Section title
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Your Courses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
          ),
        ),

        // Courses grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final course = courses[index];
              return CourseCard(
                title: course['title'] ?? 'Untitled Course',
                description: course['description'],
                imageUrl: course['imageUrl'] ?? '',
                createdAt: course['createdAt'],
                isTeacherView: true,
                enrolledCount: course['enrolledCount'] ?? 0,
                videoCount: course['videoCount'] ?? 0,
                onTap: () => _openCourseManagement(course),
              );
            }, childCount: courses.length),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
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
