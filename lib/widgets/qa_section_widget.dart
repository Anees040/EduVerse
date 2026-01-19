import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/services/qa_service.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:intl/intl.dart';

/// Q&A Section Widget - Can be used by both students and teachers
class QASectionWidget extends StatefulWidget {
  final String courseUid;
  final String? videoId;
  final String? videoTitle;
  final bool isTeacher;
  final String? teacherName;
  final String? courseName;
  final Duration Function()? getCurrentVideoPosition;
  final void Function(Duration)? onTimestampTap;

  const QASectionWidget({
    super.key,
    required this.courseUid,
    this.videoId,
    this.videoTitle,
    this.isTeacher = false,
    this.teacherName,
    this.courseName,
    this.getCurrentVideoPosition,
    this.onTimestampTap,
  });

  @override
  State<QASectionWidget> createState() => _QASectionWidgetState();
}

class _QASectionWidgetState extends State<QASectionWidget> {
  final QAService _qaService = QAService();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  String? _studentName;
  bool _isSubmitting = false;
  bool _showAllQuestions = true; // Default to showing all questions

  @override
  void initState() {
    super.initState();
    _loadStudentName();
  }

  Future<void> _loadStudentName() async {
    if (!widget.isTeacher) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userData = await UserService().getUser(uid: uid, role: 'student');
      if (mounted && userData != null) {
        setState(() {
          _studentName = userData['name'] ?? 'Student';
        });
      }
    }
  }

  Future<void> _submitQuestion() async {
    if (_questionController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Get current video position if available
      int? timestampSeconds;
      if (widget.getCurrentVideoPosition != null) {
        final position = widget.getCurrentVideoPosition!();
        timestampSeconds = position.inSeconds;
      }

      await _qaService.askQuestion(
        courseUid: widget.courseUid,
        videoId: widget.videoId ?? 'general',
        studentUid: uid,
        studentName: _studentName ?? 'Student',
        question: _questionController.text.trim(),
        videoTimestampSeconds: timestampSeconds,
        videoTitle: widget.videoTitle,
      );

      _questionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question submitted! 📝'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit question: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitAnswer(
    String questionId, {
    String? studentUid,
    String? courseName,
  }) async {
    if (_answerController.text.trim().isEmpty) return;

    try {
      final teacherUid = FirebaseAuth.instance.currentUser?.uid;

      await _qaService.answerQuestion(
        courseUid: widget.courseUid,
        questionId: questionId,
        answer: _answerController.text.trim(),
        teacherName: widget.teacherName ?? 'Instructor',
        studentUid: studentUid,
        courseName: courseName,
        teacherUid: teacherUid,
      );

      _answerController.clear();
      Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Answer posted! ✅'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post answer: $e')));
      }
    }
  }

  /// Delete a question
  Future<void> _deleteQuestion(String questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Text(
                'Delete Question',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this question? This action cannot be undone.',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _qaService.deleteQuestion(
          courseUid: widget.courseUid,
          questionId: questionId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Question deleted'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  /// Edit a question
  void _showEditQuestionDialog(Map<String, dynamic> question) {
    final editController = TextEditingController(text: question['question']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.edit,
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Edit Question',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: editController,
          maxLines: 4,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Edit your question...',
            hintStyle: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                try {
                  await _qaService.editQuestion(
                    courseUid: widget.courseUid,
                    questionId: question['questionId'],
                    newQuestion: editController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Question updated! ✏️'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Edit an answer (teacher only)
  void _showEditAnswerDialog(Map<String, dynamic> question) {
    final editController = TextEditingController(text: question['answer']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.edit,
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Edit Answer',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: editController,
          maxLines: 4,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Edit your answer...',
            hintStyle: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurfaceColor : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade300,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                try {
                  await _qaService.editAnswer(
                    courseUid: widget.courseUid,
                    questionId: question['questionId'],
                    newAnswer: editController.text.trim(),
                  );
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Answer updated! ✏️'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e')),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Delete an answer (teacher only)
  Future<void> _deleteAnswer(String questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Text(
                'Delete Answer',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this answer?',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _qaService.deleteAnswer(
          courseUid: widget.courseUid,
          questionId: questionId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Answer deleted'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  void _showAnswerDialog(Map<String, dynamic> question) {
    _answerController.clear();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardColor : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.question_answer,
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Answer Question',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurfaceColor
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: isDark
                      ? Border.all(
                          color: AppTheme.darkBorderColor.withOpacity(0.5),
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question['studentName'] ?? 'Student',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question['question'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _answerController,
                maxLines: 4,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your answer...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkSurfaceColor
                      : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorderColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorderColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _submitAnswer(
              question['questionId'],
              studentUid: question['studentUid'],
              courseName: widget.courseName,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
              foregroundColor: const Color(0xFFF0F8FF),
              elevation: 6,
              shadowColor:
                  (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.5),
            ),
            child: const Text('Post Answer'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  /// Format video timestamp as MM:SS or HH:MM:SS
  String _formatVideoTimestamp(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.forum,
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Q&A Discussion',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Toggle for showing all questions vs current video
                if (widget.videoId != null) ...[
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showAllQuestions = !_showAllQuestions),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _showAllQuestions
                            ? (isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor)
                            : (isDark
                                  ? AppTheme.darkSurfaceColor
                                  : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showAllQuestions
                                ? Icons.all_inclusive
                                : Icons.video_library,
                            size: 14,
                            color: _showAllQuestions
                                ? Colors.white
                                : (isDark
                                      ? AppTheme.darkTextSecondary
                                      : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showAllQuestions ? 'All' : 'Video',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _showAllQuestions
                                  ? Colors.white
                                  : (isDark
                                        ? AppTheme.darkTextSecondary
                                        : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                StreamBuilder<int>(
                  stream: _qaService.getUnansweredCountStream(widget.courseUid),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count == 0) return const SizedBox();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count unanswered',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Ask Question (Student only)
          if (!widget.isTeacher) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          if (_questionController.text.trim().isNotEmpty &&
                              !_isSubmitting) {
                            _submitQuestion();
                          }
                        }
                      },
                      child: TextField(
                        controller: _questionController,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask a question...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppTheme.darkSurfaceColor
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF2EC4B6), Color(0xFF22A094)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isDark ? null : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isDark
                                      ? AppTheme.darkAccent
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isSubmitting ? null : _submitQuestion,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // Questions List
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: (widget.videoId != null && !_showAllQuestions)
                ? _qaService.getVideoQuestionsStream(
                    widget.courseUid,
                    widget.videoId!,
                  )
                : _qaService.getQuestionsStream(widget.courseUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final questions = snapshot.data ?? [];

              if (questions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No questions yet',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        if (!widget.isTeacher)
                          Text(
                            'Be the first to ask!',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final q = questions[index];
                  return _buildQuestionTile(q, isDark);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(Map<String, dynamic> q, bool isDark) {
    final isAnswered = q['isAnswered'] == true;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isQuestionOwner = q['studentUid'] == currentUid;
    final wasEdited = q['editedAt'] != null;
    final answerWasEdited = q['answerEditedAt'] != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.grey.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                          .withOpacity(0.15),
                  child: Text(
                    (q['studentName'] ?? 'S')[0].toUpperCase(),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              q['studentName'] ?? 'Student',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${_formatTime(q['createdAt'])}',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          if (wasEdited) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(edited)',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextSecondary.withOpacity(
                                        0.7,
                                      )
                                    : Colors.grey.shade400,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Video title indicator (when showing all questions)
                      if (_showAllQuestions &&
                          q['videoTitle'] != null &&
                          q['videoTitle'].toString().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.purple.withOpacity(0.15)
                                : Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.video_library,
                                size: 12,
                                color: Colors.purple.shade600,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  q['videoTitle'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Question text
                      Text(
                        q['question'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),

                      // Video timestamp (if available)
                      if (q['videoTimestamp'] != null &&
                          q['videoTimestamp'] > 0) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            if (widget.onTimestampTap != null) {
                              widget.onTimestampTap!(
                                Duration(seconds: q['videoTimestamp']),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blue.withOpacity(0.15)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  size: 14,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatVideoTimestamp(q['videoTimestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                                if (q['videoTitle'] != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${q['videoTitle']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Question actions row
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Status badge
                          if (!isAnswered)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: AppTheme.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Awaiting answer',
                                    style: TextStyle(
                                      color: AppTheme.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Answered',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const Spacer(),

                          // Edit/Delete for question owner (student)
                          if (isQuestionOwner && !widget.isTeacher) ...[
                            _buildIconButton(
                              icon: Icons.edit_outlined,
                              tooltip: 'Edit',
                              onTap: () => _showEditQuestionDialog(q),
                              isDark: isDark,
                            ),
                            const SizedBox(width: 4),
                            _buildIconButton(
                              icon: Icons.delete_outline,
                              tooltip: 'Delete',
                              onTap: () => _deleteQuestion(q['questionId']),
                              isDark: isDark,
                              isDestructive: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Answer Section
            if (isAnswered) ...[
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(left: 48),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            AppTheme.success.withOpacity(0.08),
                            AppTheme.success.withOpacity(0.04),
                          ]
                        : [
                            AppTheme.success.withOpacity(0.08),
                            AppTheme.success.withOpacity(0.04),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: AppTheme.success,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                q['teacherName'] ?? 'Instructor',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${_formatTime(q['answeredAt'])}',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                              if (answerWasEdited) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                              .withOpacity(0.7)
                                        : Colors.grey.shade400,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Edit/Delete for teacher
                        if (widget.isTeacher) ...[
                          _buildIconButton(
                            icon: Icons.edit_outlined,
                            tooltip: 'Edit answer',
                            onTap: () => _showEditAnswerDialog(q),
                            isDark: isDark,
                            size: 18,
                          ),
                          const SizedBox(width: 2),
                          _buildIconButton(
                            icon: Icons.delete_outline,
                            tooltip: 'Delete answer',
                            onTap: () => _deleteAnswer(q['questionId']),
                            isDark: isDark,
                            isDestructive: true,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q['answer'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Answer Button (Teacher only)
            if (widget.isTeacher && !isAnswered) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? const LinearGradient(
                            colors: [Color(0xFF2EC4B6), Color(0xFF22A094)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isDark ? null : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showAnswerDialog(q),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.reply, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Reply',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    bool isDestructive = false,
    double size = 20,
  }) {
    final color = isDestructive
        ? Colors.red.shade400
        : (isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }
}
