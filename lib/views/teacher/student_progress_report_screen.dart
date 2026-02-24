import 'package:flutter/material.dart';
import 'package:eduverse/services/teacher_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Detailed student progress report for a specific course.
/// Shows video completion, quiz scores, and assignment stats.
class StudentProgressReportScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String courseId;
  final String courseTitle;

  const StudentProgressReportScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<StudentProgressReportScreen> createState() =>
      _StudentProgressReportScreenState();
}

class _StudentProgressReportScreenState
    extends State<StudentProgressReportScreen> {
  final _service = TeacherFeatureService();
  Map<String, dynamic> _data = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    final data = await _service.getStudentProgress(
      studentId: widget.studentId,
      courseId: widget.courseId,
    );
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Progress',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.courseTitle,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Info Card
                  _buildStudentCard(isDark, accentColor),
                  const SizedBox(height: 16),

                  // Completion Progress
                  _buildCompletionCard(isDark, accentColor),
                  const SizedBox(height: 16),

                  // Quiz Performance
                  _buildQuizCard(isDark),
                  const SizedBox(height: 16),

                  // Assignments
                  _buildAssignmentCard(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStudentCard(bool isDark, Color accentColor) {
    final name = _data['studentName'] ?? widget.studentName;
    final email = _data['studentEmail'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: accentColor.withOpacity(0.12),
            child: Text(
              (name as String).isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (email.toString().isNotEmpty)
                  Text(
                    email.toString(),
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(bool isDark, Color accentColor) {
    final totalVideos = (_data['totalVideos'] as num?)?.toInt() ?? 0;
    final watchedVideos = (_data['watchedVideos'] as num?)?.toInt() ?? 0;
    final completionPct = (_data['completionPercent'] as num?)?.toInt() ?? 0;
    final pctVal = completionPct / 100.0;

    Color progressColor;
    if (completionPct >= 80) {
      progressColor = Colors.green;
    } else if (completionPct >= 40) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Icon(Icons.play_circle_outline, color: accentColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'Video Completion',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: pctVal.clamp(0, 1).toDouble(),
                        strokeWidth: 8,
                        backgroundColor:
                            isDark ? Colors.white12 : Colors.grey.shade200,
                        color: progressColor,
                      ),
                    ),
                    Text(
                      '$completionPct%',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$watchedVideos of $totalVideos videos watched',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completionPct >= 80
                          ? 'Excellent progress! 🎉'
                          : completionPct >= 40
                              ? 'Making progress 💪'
                              : 'Needs encouragement 📚',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(bool isDark) {
    final quizResults =
        (_data['quizResults'] as List<dynamic>?) ?? [];
    final avgScore = _data['avgQuizScore'] as String? ?? '0.0';

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              const Icon(Icons.quiz_outlined, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Text(
                'Quiz Performance',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avg: $avgScore%',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (quizResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No quizzes attempted yet',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 14,
                ),
              ),
            )
          else
            ...quizResults.take(10).map((quiz) {
              final q = quiz as Map<String, dynamic>;
              final score =
                  (q['scorePercent'] as num?)?.toDouble() ?? 0;
              final quizId = q['quizId'] ?? 'Quiz';

              Color scoreColor;
              if (score >= 80) {
                scoreColor = Colors.green;
              } else if (score >= 50) {
                scoreColor = Colors.orange;
              } else {
                scoreColor = Colors.red;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        quizId.toString().length > 25
                            ? '${quizId.toString().substring(0, 25)}...'
                            : quizId.toString(),
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(bool isDark) {
    final submitted = (_data['assignmentsSubmitted'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_turned_in, color: Colors.green, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assignments Submitted',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$submitted total submissions',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$submitted',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
