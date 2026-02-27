import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/services/teacher_feature_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/teacher/teacher_announcements_screen.dart';
import 'package:eduverse/views/teacher/teacher_revenue_dashboard.dart';
import 'package:eduverse/views/teacher/student_progress_report_screen.dart';

/// Course engagement overview — shows all teacher's courses with key metrics.
/// Access point for announcements, enrolled-student view, and revenue dashboard.
class TeacherCourseEngagementScreen extends StatefulWidget {
  const TeacherCourseEngagementScreen({super.key});

  @override
  State<TeacherCourseEngagementScreen> createState() =>
      _TeacherCourseEngagementScreenState();
}

class _TeacherCourseEngagementScreenState
    extends State<TeacherCourseEngagementScreen> {
  final _featureService = TeacherFeatureService();
  final _courseService = CourseService();

  List<Map<String, dynamic>> _courses = [];
  Map<String, Map<String, dynamic>> _engagement = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final courses = await _courseService.getTeacherCourses(teacherUid: uid);

      // Load engagement for each course in parallel
      final futures = <Future<MapEntry<String, Map<String, dynamic>>>>[];
      for (final course in courses) {
        final courseId = course['courseUid'] as String? ?? '';
        if (courseId.isNotEmpty) {
          futures.add(
            _featureService
                .getCourseEngagement(courseId)
                .then((data) => MapEntry(courseId, data)),
          );
        }
      }

      final results = await Future.wait(futures);
      final engagementMap = <String, Map<String, dynamic>>{};
      for (final entry in results) {
        engagementMap[entry.key] = entry.value;
      }

      if (mounted) {
        setState(() {
          _courses = courses;
          _engagement = engagementMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading engagement: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show enrolled students for a course in a bottom sheet
  Future<void> _showEnrolledStudents(String courseId, String title) async {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.getBackgroundColor(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.getTextSecondary(ctx).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Icon(Icons.people_rounded,
                            color: accentColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Enrolled Students',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.getTextPrimary(ctx),
                                  )),
                              Text(title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.getTextSecondary(ctx),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: AppTheme.getTextSecondary(ctx)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : Colors.grey.shade200,
                  ),
                  // Student list
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _featureService
                          .getEnrolledStudentsSummary(courseId),
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final students = snap.data ?? [];
                        if (students.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48,
                                    color: AppTheme.getTextSecondary(ctx)
                                        .withOpacity(0.3)),
                                const SizedBox(height: 8),
                                Text('No students enrolled yet',
                                    style: TextStyle(
                                      color: AppTheme.getTextSecondary(ctx),
                                    )),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount: students.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final s = students[i];
                            return _buildStudentTile(
                                s, courseId, title, isDark, accentColor);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentTile(Map<String, dynamic> student, String courseId,
      String courseTitle, bool isDark, Color accentColor) {
    final name = student['name'] as String? ?? 'Unknown';
    final email = student['email'] as String? ?? '';
    final completion = (student['completionPercent'] as num?)?.toInt() ?? 0;
    final avgQuiz = (student['avgQuizScore'] as num?)?.toDouble() ?? 0;
    final quizCount = (student['quizCount'] as num?)?.toInt() ?? 0;
    final watched = (student['watchedVideos'] as num?)?.toInt() ?? 0;
    final totalVids = (student['totalVideos'] as num?)?.toInt() ?? 0;
    final studentId = student['studentId'] as String? ?? '';

    Color progressColor;
    if (completion >= 75) {
      progressColor = Colors.green;
    } else if (completion >= 40) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // close bottom sheet
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentProgressReportScreen(
              studentId: studentId,
              studentName: name,
              courseId: courseId,
              courseTitle: courseTitle,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            // Avatar with progress ring
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: completion / 100,
                      strokeWidth: 3,
                      backgroundColor: progressColor.withOpacity(0.15),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: accentColor.withOpacity(0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(email,
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _miniChip(Icons.play_circle_outline, '$watched/$totalVids',
                          Colors.blue),
                      const SizedBox(width: 8),
                      if (quizCount > 0)
                        _miniChip(Icons.quiz_outlined,
                            '${avgQuiz.toStringAsFixed(0)}%', Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
            // Completion badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: progressColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$completion%',
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: AppTheme.getTextSecondary(context).withOpacity(0.4),
                size: 20),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.7)),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Course Engagement',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.attach_money, color: Colors.green.shade700),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TeacherRevenueDashboard(),
                ),
              );
            },
            tooltip: 'Revenue Dashboard',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(
                  child: Text(
                    'No courses yet',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      final courseId = course['courseUid'] as String? ?? '';
                      final eng = _engagement[courseId] ?? {};
                      return _buildCourseEngagementCard(
                        course,
                        eng,
                        isDark,
                        accentColor,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildCourseEngagementCard(
    Map<String, dynamic> course,
    Map<String, dynamic> engagement,
    bool isDark,
    Color accentColor,
  ) {
    final courseId = course['courseUid'] as String? ?? '';
    final title = course['title'] as String? ?? 'Untitled';
    final enrolled = (engagement['enrolledCount'] as num?)?.toInt() ?? 0;
    final reviews = (engagement['reviewCount'] as num?)?.toInt() ?? 0;
    final avgRating = engagement['avgRating'] as String? ?? '0.0';
    final videos = (engagement['videoCount'] as num?)?.toInt() ?? 0;
    final qaCount = (engagement['qaCount'] as num?)?.toInt() ?? 0;
    final isPublished = engagement['isPublished'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPublished
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPublished ? 'LIVE' : 'DRAFT',
                  style: TextStyle(
                    color: isPublished ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _buildMiniStat(
                  Icons.people, '$enrolled', 'Students', Colors.blue),
              _buildMiniStat(
                  Icons.star, avgRating, 'Rating', Colors.amber),
              _buildMiniStat(
                  Icons.play_circle, '$videos', 'Videos', Colors.red),
              _buildMiniStat(Icons.question_answer, '$qaCount', 'Q&A',
                  Colors.purple),
              _buildMiniStat(
                  Icons.rate_review, '$reviews', 'Reviews', Colors.teal),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons: Announce + Students
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherAnnouncementsScreen(
                          courseId: courseId,
                          courseTitle: title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.campaign, size: 16),
                  label:
                      const Text('Announce', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEnrolledStudents(courseId, title),
                  icon: const Icon(Icons.people_outline, size: 16),
                  label:
                      const Text('Students', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: BorderSide(color: Colors.blue.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
