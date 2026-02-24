import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/services/teacher_feature_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/teacher/teacher_announcements_screen.dart';
import 'package:eduverse/views/teacher/teacher_revenue_dashboard.dart';

/// Course engagement overview — shows all teacher's courses with key metrics.
/// Access point for announcements, duplication, and revenue dashboard.
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
            _featureService.getCourseEngagement(courseId).then(
                  (data) => MapEntry(courseId, data),
                ),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _duplicateCourse(String courseId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Duplicate Course?',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          'This will create a copy of "$title" with all videos and quizzes. The copy will be in draft mode.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.isDarkMode(context)
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
            ),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final newId = await _featureService.duplicateCourse(courseId);

    if (newId != null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Course duplicated successfully! Check your courses.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData(); // Refresh
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to duplicate course'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              _buildMiniStat(Icons.people, '$enrolled', 'Students', Colors.blue),
              _buildMiniStat(Icons.star, avgRating, 'Rating', Colors.amber),
              _buildMiniStat(Icons.play_circle, '$videos', 'Videos', Colors.red),
              _buildMiniStat(Icons.question_answer, '$qaCount', 'Q&A', Colors.purple),
              _buildMiniStat(Icons.rate_review, '$reviews', 'Reviews', Colors.teal),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
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
                  label: const Text('Announce', style: TextStyle(fontSize: 12)),
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
                  onPressed: () => _duplicateCourse(courseId, title),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Duplicate', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.withOpacity(0.4)),
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

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
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
