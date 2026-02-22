import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:eduverse/services/quiz_service.dart';
import 'package:eduverse/services/study_streak_service.dart';
import 'package:eduverse/services/learning_stats_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Student Quiz Taking Screen
/// Full quiz experience with timer, navigation, and results
class StudentQuizScreen extends StatefulWidget {
  final String quizId;
  final String courseId;

  const StudentQuizScreen({
    super.key,
    required this.quizId,
    required this.courseId,
  });

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen> {
  final QuizService _quizService = QuizService();

  Map<String, dynamic>? _quiz;
  List<Map<String, dynamic>> _questions = [];
  String? _attemptId;

  int _currentQuestionIndex = 0;
  final Map<int, int> _answers = {}; // questionIndex -> selectedOptionIndex

  Timer? _timer;
  int _remainingSeconds = 0;
  DateTime? _startTime;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isCompleted = false;
  Map<String, dynamic>? _results;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    final quiz = await _quizService.getQuiz(widget.quizId);

    if (quiz == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quiz not found')));
        Navigator.pop(context);
      }
      return;
    }

    // Check if can attempt
    final studentId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final canAttempt = await _quizService.canStudentAttemptQuiz(
      widget.quizId,
      studentId,
    );

    if (!canAttempt) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum attempts reached')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Start attempt
    final attemptId = await _quizService.startQuizAttempt(
      quizId: widget.quizId,
      studentId: studentId,
      courseId: widget.courseId,
    );

    if (attemptId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to start quiz')));
        Navigator.pop(context);
      }
      return;
    }

    // Process questions
    var questions = List<Map<String, dynamic>>.from(
      (quiz['questions'] as List?)?.map(
            (q) => Map<String, dynamic>.from(q as Map),
          ) ??
          [],
    );

    // Shuffle questions if enabled
    if (quiz['shuffleQuestions'] == true) {
      questions.shuffle(Random());
    }

    // Shuffle options if enabled
    if (quiz['shuffleOptions'] == true) {
      for (var question in questions) {
        final options = List<String>.from(question['options'] as List? ?? []);
        final correctAnswer = question['correctAnswer'] as int? ?? 0;
        final correctOption = options[correctAnswer];

        options.shuffle(Random());
        question['options'] = options;
        question['correctAnswer'] = options.indexOf(correctOption);
      }
    }

    setState(() {
      _quiz = quiz;
      _questions = questions;
      _attemptId = attemptId;
      _isLoading = false;
      _startTime = DateTime.now();
    });

    // Start timer if time limit
    final timeLimit = quiz['timeLimit'] as int? ?? 0;
    if (timeLimit > 0) {
      _remainingSeconds = timeLimit * 60;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          timer.cancel();
          _submitQuiz();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isCompleted) {
      return _buildResultsScreen(isDark);
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(_quiz?['title'] ?? 'Quiz'),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: AppTheme.getTextPrimary(context),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmExit(),
          ),
          actions: [
            if (_remainingSeconds > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _remainingSeconds <= 60
                      ? Colors.red.withOpacity(0.1)
                      : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _remainingSeconds <= 60
                        ? Colors.red
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: _remainingSeconds <= 60
                          ? Colors.red
                          : AppTheme.getTextPrimary(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        color: _remainingSeconds <= 60
                            ? Colors.red
                            : AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(isDark),

            // Question
            Expanded(child: _buildQuestion(isDark)),

            // Navigation
            _buildNavigation(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${_answers.length}/${_questions.length} answered',
                style: TextStyle(
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              backgroundColor: isDark
                  ? AppTheme.darkElevated
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(bool isDark) {
    if (_questions.isEmpty) {
      return const Center(child: Text('No questions available'));
    }

    final question = _questions[_currentQuestionIndex];
    final options = List<String>.from(question['options'] as List? ?? []);
    final selectedAnswer = _answers[_currentQuestionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Question ${_currentQuestionIndex + 1}',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  question['question'] ?? '',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Options
          ...List.generate(options.length, (index) {
            final isSelected = selectedAnswer == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () =>
                    setState(() => _answers[_currentQuestionIndex] = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                              .withOpacity(0.1)
                        : (isDark ? AppTheme.darkCard : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor)
                          : (isDark
                                ? AppTheme.darkBorder
                                : Colors.grey.shade200),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                              : (isDark
                                    ? AppTheme.darkElevated
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : Text(
                                  String.fromCharCode(65 + index),
                                  style: TextStyle(
                                    color: AppTheme.getTextSecondary(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          options[index],
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavigation(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Question navigator
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(min(_questions.length, 5), (index) {
                final qIndex = _getDisplayedQuestionIndex(index);
                final isAnswered = _answers.containsKey(qIndex);
                final isCurrent = qIndex == _currentQuestionIndex;

                return InkWell(
                  onTap: () => setState(() => _currentQuestionIndex = qIndex),
                  child: Container(
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${qIndex + 1}',
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : (isAnswered
                                  ? (isDark
                                        ? AppTheme.darkAccent
                                        : AppTheme.primaryColor)
                                  : AppTheme.getTextSecondary(context)),
                        fontWeight: isAnswered || isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Spacer(),

          // Previous button
          if (_currentQuestionIndex > 0)
            TextButton.icon(
              onPressed: () => setState(() => _currentQuestionIndex--),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Prev'),
            ),
          const SizedBox(width: 8),

          // Next/Submit button
          ElevatedButton(
            onPressed: _currentQuestionIndex < _questions.length - 1
                ? () => setState(() => _currentQuestionIndex++)
                : _submitQuiz,
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentQuestionIndex < _questions.length - 1
                  ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                  : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    _currentQuestionIndex < _questions.length - 1
                        ? 'Next'
                        : 'Submit',
                  ),
          ),
        ],
      ),
    );
  }

  int _getDisplayedQuestionIndex(int displayIndex) {
    // Show 5 questions around current question
    final total = _questions.length;
    if (total <= 5) return displayIndex;

    int start = _currentQuestionIndex - 2;
    if (start < 0) start = 0;
    if (start + 5 > total) start = total - 5;

    return start + displayIndex;
  }

  Widget _buildResultsScreen(bool isDark) {
    final passed = _results?['passed'] == true;
    final percentage = (_results?['percentage'] ?? 0.0).toDouble();
    final score = _results?['score'] ?? 0;
    final total = _results?['totalQuestions'] ?? 0;
    final passingScore = _results?['passingScore'] ?? 60;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Result icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: (passed ? Colors.green : Colors.orange).withOpacity(
                    0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  passed ? Icons.celebration : Icons.sentiment_neutral,
                  size: 80,
                  color: passed ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 24),

              // Result title
              Text(
                passed ? 'Congratulations! 🎉' : 'Keep Trying!',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                passed ? 'You passed the quiz!' : 'You can do better next time',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),

              // Score card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    // Percentage circle
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CircularProgressIndicator(
                              value: percentage / 100,
                              strokeWidth: 12,
                              backgroundColor: isDark
                                  ? AppTheme.darkElevated
                                  : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                passed ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: AppTheme.getTextPrimary(context),
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$score / $total',
                                style: TextStyle(
                                  color: AppTheme.getTextSecondary(context),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pass threshold
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: (passed ? Colors.green : Colors.orange)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        passed
                            ? '✓ Passed (min. $passingScore%)'
                            : '✗ Required: $passingScore%',
                        style: TextStyle(
                          color: passed ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Review answers button (if showResults enabled)
              if (_quiz?['showResults'] == true) ...[
                OutlinedButton.icon(
                  onPressed: () => _showAnswerReview(isDark),
                  icon: const Icon(Icons.fact_check),
                  label: const Text('Review Answers'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnswerReview(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          itemCount: _questions.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }

            final qIndex = index - 1;
            final question = _questions[qIndex];
            final selectedAnswer = _answers[qIndex];
            final correctAnswer = question['correctAnswer'] as int? ?? 0;
            final options = List<String>.from(
              question['options'] as List? ?? [],
            );
            final isCorrect = selectedAnswer == correctAnswer;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.5)
                      : Colors.red.withOpacity(0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isCorrect ? Icons.check : Icons.close,
                          size: 16,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Question ${qIndex + 1}',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question['question'] ?? '',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (selectedAnswer != null)
                    _buildAnswerRow(
                      'Your answer:',
                      options[selectedAnswer],
                      isCorrect ? Colors.green : Colors.red,
                    ),

                  if (!isCorrect && correctAnswer < options.length)
                    _buildAnswerRow(
                      'Correct answer:',
                      options[correctAnswer],
                      Colors.green,
                    ),

                  if (question['explanation']?.toString().isNotEmpty ??
                      false) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question['explanation'],
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnswerRow(String label, String answer, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              answer,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    return await _confirmExit() ?? false;
  }

  Future<bool?> _confirmExit() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Exit Quiz?',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: Text(
          'Your progress will be lost. Are you sure you want to exit?',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Quiz'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuiz() async {
    // Check for unanswered questions
    final unanswered = _questions.length - _answers.length;
    if (unanswered > 0) {
      final shouldSubmit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Unanswered Questions',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Text(
            'You have $unanswered unanswered question${unanswered > 1 ? 's' : ''}. Submit anyway?',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );

      if (shouldSubmit != true) return;
    }

    setState(() => _isSubmitting = true);
    _timer?.cancel();

    final timeTaken = _startTime != null
        ? DateTime.now().difference(_startTime!).inSeconds
        : 0;

    final results = await _quizService.submitQuizAttempt(
      attemptId: _attemptId!,
      quizId: widget.quizId,
      answers: _answers,
      timeTaken: timeTaken,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isCompleted = true;
        _results = results;
      });

      // Record study activity for streak & stats tracking
      StudyStreakService().recordStudyActivity();
      LearningStatsService().logStudySession(
        durationSeconds: timeTaken,
        activityType: 'quiz',
        courseId: widget.courseId,
      );
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
