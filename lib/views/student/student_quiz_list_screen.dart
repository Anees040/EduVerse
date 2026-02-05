import 'package:flutter/material.dart';
import 'package:eduverse/services/quiz_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/student/student_quiz_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Student Quiz List Screen
/// Shows all available quizzes for a course with status indicators
class StudentQuizListScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const StudentQuizListScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudentQuizListScreen> createState() => _StudentQuizListScreenState();
}

class _StudentQuizListScreenState extends State<StudentQuizListScreen> {
  final QuizService _quizService = QuizService();
  final String _studentId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<Map<String, dynamic>> _quizzes = [];
  Map<String, Map<String, dynamic>?> _bestAttempts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);

    // Get course quizzes and filter only published ones
    final allQuizzes = await _quizService.getCourseQuizzes(widget.courseId);
    final quizzes = allQuizzes.where((q) => q['isPublished'] == true).toList();

    // Load best attempts for each quiz
    final attempts = <String, Map<String, dynamic>?>{};
    for (final quiz in quizzes) {
      final quizId = quiz['id'] as String?;
      if (quizId != null) {
        attempts[quizId] = await _quizService.getStudentBestAttempt(
          quizId,
          _studentId,
        );
      }
    }

    setState(() {
      _quizzes = quizzes;
      _bestAttempts = attempts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Quizzes'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuizzes,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _quizzes.isEmpty
            ? _buildEmptyState(isDark)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _quizzes.length,
                itemBuilder: (context, index) =>
                    _buildQuizCard(_quizzes[index], isDark),
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 80,
            color: AppTheme.getTextSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Quizzes Available',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for quizzes',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz, bool isDark) {
    final quizId = quiz['id'] as String;
    final title = quiz['title'] ?? 'Untitled Quiz';
    final description = quiz['description'] ?? '';
    final questions = quiz['questions'] as List? ?? [];
    final timeLimit = quiz['timeLimit'] as int? ?? 0;
    final passingScore = quiz['passingScore'] ?? 60;
    final maxAttempts = quiz['maxAttempts'] as int? ?? 1;
    final startDate = DateTime.tryParse(quiz['startDate'] ?? '');
    final endDate = DateTime.tryParse(quiz['endDate'] ?? '');

    final bestAttempt = _bestAttempts[quizId];
    final hasPassed = bestAttempt?['passed'] == true;
    final bestScore = bestAttempt?['percentage']?.toDouble();
    final attemptCount = bestAttempt?['attemptNumber'] ?? 0;

    // Determine status
    final now = DateTime.now();
    final isNotStarted = startDate != null && now.isBefore(startDate);
    final isExpired = endDate != null && now.isAfter(endDate);
    final canAttempt =
        !isNotStarted &&
        !isExpired &&
        (attemptCount < maxAttempts || maxAttempts == -1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPassed
              ? Colors.green.withOpacity(0.5)
              : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canAttempt ? () => _startQuiz(quiz) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          hasPassed,
                          isNotStarted,
                          isExpired,
                          canAttempt,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(hasPassed, isNotStarted, isExpired),
                        color: _getStatusColor(
                          hasPassed,
                          isNotStarted,
                          isExpired,
                          canAttempt,
                        ),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildInfoPill(
                                '${questions.length} Questions',
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              if (timeLimit > 0)
                                _buildInfoPill('$timeLimit min', isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    _buildStatusBadge(
                      hasPassed,
                      isNotStarted,
                      isExpired,
                      canAttempt,
                      attemptCount,
                      maxAttempts,
                    ),
                  ],
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 16),

                // Progress / Score section
                if (bestAttempt != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (hasPassed ? Colors.green : Colors.orange)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasPassed ? Icons.emoji_events : Icons.trending_up,
                          color: hasPassed ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Best Score: ${bestScore?.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: hasPassed ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$attemptCount/${maxAttempts == -1 ? '∞' : maxAttempts} attempts',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Date range and action
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (startDate != null && isNotStarted)
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Starts: ${DateFormat('MMM d, h:mm a').format(startDate)}',
                                  style: TextStyle(
                                    color: AppTheme.getTextSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          if (endDate != null && !isExpired && !isNotStarted)
                            Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 14,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Due: ${DateFormat('MMM d, h:mm a').format(endDate)}',
                                  style: TextStyle(
                                    color: AppTheme.getTextSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 14,
                                color: AppTheme.getTextSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pass: $passingScore%',
                                style: TextStyle(
                                  color: AppTheme.getTextSecondary(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canAttempt)
                      ElevatedButton.icon(
                        onPressed: () => _startQuiz(quiz),
                        icon: Icon(
                          bestAttempt == null
                              ? Icons.play_arrow
                              : Icons.refresh,
                          size: 18,
                        ),
                        label: Text(
                          bestAttempt == null ? 'Start Quiz' : 'Retry',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.getTextSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    bool hasPassed,
    bool isNotStarted,
    bool isExpired,
    bool canAttempt,
    int attemptCount,
    int maxAttempts,
  ) {
    Color color;
    String text;
    IconData icon;

    if (hasPassed) {
      color = Colors.green;
      text = 'Passed';
      icon = Icons.check_circle;
    } else if (isNotStarted) {
      color = Colors.blue;
      text = 'Upcoming';
      icon = Icons.schedule;
    } else if (isExpired) {
      color = Colors.grey;
      text = 'Expired';
      icon = Icons.event_busy;
    } else if (attemptCount >= maxAttempts && maxAttempts != -1) {
      color = Colors.orange;
      text = 'Max Attempts';
      icon = Icons.block;
    } else {
      color = Colors.green;
      text = 'Available';
      icon = Icons.play_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(
    bool hasPassed,
    bool isNotStarted,
    bool isExpired,
    bool canAttempt,
  ) {
    if (hasPassed) return Colors.green;
    if (isNotStarted) return Colors.blue;
    if (isExpired) return Colors.grey;
    if (canAttempt) return AppTheme.primaryColor;
    return Colors.orange;
  }

  IconData _getStatusIcon(bool hasPassed, bool isNotStarted, bool isExpired) {
    if (hasPassed) return Icons.emoji_events;
    if (isNotStarted) return Icons.schedule;
    if (isExpired) return Icons.event_busy;
    return Icons.quiz;
  }

  Future<void> _startQuiz(Map<String, dynamic> quiz) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AppTheme.isDarkMode(context);
        final timeLimit = quiz['timeLimit'] as int? ?? 0;
        final questions = quiz['questions'] as List? ?? [];

        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Start Quiz?',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quiz['title'] ?? '',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDialogInfo(
                Icons.help_outline,
                '${questions.length} questions',
              ),
              if (timeLimit > 0)
                _buildDialogInfo(Icons.timer, '$timeLimit minutes time limit'),
              _buildDialogInfo(
                Icons.trending_up,
                'Pass: ${quiz['passingScore'] ?? 60}%',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Once started, you must complete the quiz.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StudentQuizScreen(quizId: quiz['id'], courseId: widget.courseId),
        ),
      );

      // Refresh quiz list after completion
      _loadQuizzes();
    }
  }

  Widget _buildDialogInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.getTextSecondary(context)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: AppTheme.getTextPrimary(context))),
        ],
      ),
    );
  }
}
