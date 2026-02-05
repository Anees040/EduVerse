import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/services/quiz_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Quiz Management Screen for Teachers
/// Create, edit, manage quizzes for a course
class TeacherQuizManageScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String teacherId;

  const TeacherQuizManageScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
  });

  @override
  State<TeacherQuizManageScreen> createState() =>
      _TeacherQuizManageScreenState();
}

class _TeacherQuizManageScreenState extends State<TeacherQuizManageScreen> {
  final QuizService _quizService = QuizService();

  List<Map<String, dynamic>> _quizzes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() => _isLoading = true);
    final quizzes = await _quizService.getCourseQuizzes(widget.courseId);
    if (mounted) {
      setState(() {
        _quizzes = quizzes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quizzes'),
            Text(
              widget.courseTitle,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getTextSecondary(context),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quizzes.isEmpty
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              onRefresh: _loadQuizzes,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _quizzes.length,
                itemBuilder: (context, index) =>
                    _buildQuizCard(_quizzes[index], isDark),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createQuiz(context),
        backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Create Quiz'),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.quiz_outlined,
                size: 64,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Quizzes Yet',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create quizzes to test your students\' understanding',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _createQuiz(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(Map<String, dynamic> quiz, bool isDark) {
    final isPublished = quiz['isPublished'] == true;
    final questionsCount = (quiz['questions'] as List?)?.length ?? 0;
    final timeLimit = quiz['timeLimit'] as int? ?? 0;
    final passingScore = quiz['passingScore'] as int? ?? 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () => _editQuiz(quiz),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isPublished ? Colors.green : Colors.orange)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.quiz,
                      color: isPublished ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz['title'] ?? 'Untitled Quiz',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isPublished ? Colors.green : Colors.orange)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPublished ? 'Published' : 'Draft',
                                style: TextStyle(
                                  color: isPublished
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.getTextSecondary(context),
                    ),
                    onSelected: (value) => _handleQuizAction(quiz, value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: isPublished ? 'unpublish' : 'publish',
                        child: Row(
                          children: [
                            Icon(
                              isPublished
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(isPublished ? 'Unpublish' : 'Publish'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'stats',
                        child: Row(
                          children: [
                            Icon(Icons.analytics, size: 20),
                            SizedBox(width: 8),
                            Text('View Results'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (quiz['description']?.toString().isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Text(
                  quiz['description'],
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackground.withOpacity(0.5)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildStatItem(
                      Icons.help_outline,
                      '$questionsCount Questions',
                      isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      Icons.timer_outlined,
                      timeLimit > 0 ? '$timeLimit min' : 'No limit',
                      isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      Icons.check_circle_outline,
                      'Pass: $passingScore%',
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, bool isDark) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.getTextSecondary(context)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _createQuiz(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizEditorScreen(
          courseId: widget.courseId,
          teacherId: widget.teacherId,
          onSaved: _loadQuizzes,
        ),
      ),
    );
  }

  void _editQuiz(Map<String, dynamic> quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizEditorScreen(
          courseId: widget.courseId,
          teacherId: widget.teacherId,
          existingQuiz: quiz,
          onSaved: _loadQuizzes,
        ),
      ),
    );
  }

  void _handleQuizAction(Map<String, dynamic> quiz, String action) async {
    final quizId = quiz['quizId'] ?? quiz['id'];

    switch (action) {
      case 'publish':
      case 'unpublish':
        final success = await _quizService.toggleQuizPublished(
          quizId,
          action == 'publish',
        );
        if (success) {
          _loadQuizzes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  action == 'publish' ? 'Quiz published' : 'Quiz unpublished',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        break;
      case 'edit':
        _editQuiz(quiz);
        break;
      case 'stats':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizResultsScreen(
              quizId: quizId,
              quizTitle: quiz['title'] ?? 'Quiz',
            ),
          ),
        );
        break;
      case 'delete':
        _confirmDeleteQuiz(quiz);
        break;
    }
  }

  void _confirmDeleteQuiz(Map<String, dynamic> quiz) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Delete Quiz',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${quiz['title']}"? This will also delete all student attempts.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _quizService.deleteQuiz(
                quiz['quizId'] ?? quiz['id'],
              );
              if (success) {
                _loadQuizzes();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quiz deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Quiz Editor Screen - Create/Edit a quiz
class QuizEditorScreen extends StatefulWidget {
  final String courseId;
  final String teacherId;
  final Map<String, dynamic>? existingQuiz;
  final VoidCallback onSaved;

  const QuizEditorScreen({
    super.key,
    required this.courseId,
    required this.teacherId,
    this.existingQuiz,
    required this.onSaved,
  });

  @override
  State<QuizEditorScreen> createState() => _QuizEditorScreenState();
}

class _QuizEditorScreenState extends State<QuizEditorScreen> {
  final QuizService _quizService = QuizService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<QuizQuestion> _questions = [];
  int _timeLimit = 0;
  int _passingScore = 60;
  int _maxAttempts = 0;
  bool _shuffleQuestions = false;
  bool _shuffleOptions = false;
  bool _showResults = true;
  bool _isSaving = false;

  bool get _isEditing => widget.existingQuiz != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingQuiz();
    } else {
      // Add one empty question by default
      _questions.add(QuizQuestion());
    }
  }

  void _loadExistingQuiz() {
    final quiz = widget.existingQuiz!;
    _titleController.text = quiz['title'] ?? '';
    _descriptionController.text = quiz['description'] ?? '';
    _timeLimit = quiz['timeLimit'] ?? 0;
    _passingScore = quiz['passingScore'] ?? 60;
    _maxAttempts = quiz['maxAttempts'] ?? 0;
    _shuffleQuestions = quiz['shuffleQuestions'] ?? false;
    _shuffleOptions = quiz['shuffleOptions'] ?? false;
    _showResults = quiz['showResults'] ?? true;

    final questionsData = quiz['questions'] as List? ?? [];
    _questions = questionsData.map((q) {
      final qMap = Map<String, dynamic>.from(q as Map);
      return QuizQuestion(
        question: qMap['question'] ?? '',
        options:
            (qMap['options'] as List?)?.map((o) => o.toString()).toList() ??
            ['', '', '', ''],
        correctAnswer: qMap['correctAnswer'] ?? 0,
        explanation: qMap['explanation'],
      );
    }).toList();

    if (_questions.isEmpty) {
      _questions.add(QuizQuestion());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Quiz' : 'Create Quiz'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveQuiz,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info Card
            _buildSectionCard('Quiz Details', [
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Quiz Title *', Icons.title),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration(
                  'Description (optional)',
                  Icons.description,
                ),
                maxLines: 2,
              ),
            ], isDark),
            const SizedBox(height: 16),

            // Settings Card
            _buildSectionCard('Settings', [
              Row(
                children: [
                  Expanded(
                    child: _buildNumberSetting(
                      'Time Limit (min)',
                      _timeLimit,
                      (v) => setState(() => _timeLimit = v),
                      hint: '0 = No limit',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNumberSetting(
                      'Passing Score (%)',
                      _passingScore,
                      (v) => setState(() => _passingScore = v),
                      min: 1,
                      max: 100,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildNumberSetting(
                'Max Attempts',
                _maxAttempts,
                (v) => setState(() => _maxAttempts = v),
                hint: '0 = Unlimited',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: Text(
                  'Shuffle Questions',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                subtitle: Text(
                  'Randomize question order',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
                value: _shuffleQuestions,
                onChanged: (v) => setState(() => _shuffleQuestions = v),
                activeColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(
                  'Shuffle Options',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                subtitle: Text(
                  'Randomize answer options',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
                value: _shuffleOptions,
                onChanged: (v) => setState(() => _shuffleOptions = v),
                activeColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(
                  'Show Results',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                subtitle: Text(
                  'Show correct answers after submission',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
                value: _showResults,
                onChanged: (v) => setState(() => _showResults = v),
                activeColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
              ),
            ], isDark),
            const SizedBox(height: 16),

            // Questions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions (${_questions.length})',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _questions.add(QuizQuestion())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Questions List
            ...List.generate(
              _questions.length,
              (index) => _buildQuestionCard(index, isDark),
            ),

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            title,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final isDark = AppTheme.isDarkMode(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildNumberSetting(
    String label,
    int value,
    Function(int) onChanged, {
    String? hint,
    int min = 0,
    int max = 999,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 13,
          ),
        ),
        if (hint != null)
          Text(
            hint,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 11,
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 20,
            ),
            Container(
              width: 50,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toString(),
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index, bool isDark) {
    final question = _questions[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (_questions.length > 1)
                IconButton(
                  onPressed: () => setState(() => _questions.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete Question',
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: question.question,
            onChanged: (v) => question.question = v,
            decoration: _inputDecoration('Question *', Icons.help_outline),
            maxLines: 2,
            validator: (v) =>
                v?.isEmpty ?? true ? 'Question is required' : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Options (tap to mark correct)',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            4,
            (optIndex) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => question.correctAnswer = optIndex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: question.correctAnswer == optIndex
                            ? Colors.green
                            : (isDark
                                  ? AppTheme.darkElevated
                                  : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: question.correctAnswer == optIndex
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                String.fromCharCode(65 + optIndex),
                                style: TextStyle(
                                  color: AppTheme.getTextSecondary(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: question.options[optIndex],
                      onChanged: (v) => question.options[optIndex] = v,
                      decoration: InputDecoration(
                        hintText:
                            'Option ${String.fromCharCode(65 + optIndex)}',
                        filled: true,
                        fillColor: question.correctAnswer == optIndex
                            ? Colors.green.withOpacity(0.1)
                            : (isDark
                                  ? AppTheme.darkElevated
                                  : Colors.grey.shade50),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: question.correctAnswer == optIndex
                                ? Colors.green
                                : Colors.transparent,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: question.correctAnswer == optIndex
                                ? Colors.green
                                : Colors.transparent,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: question.explanation,
            onChanged: (v) => question.explanation = v,
            decoration: _inputDecoration(
              'Explanation (optional)',
              Icons.lightbulb_outline,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate questions
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.question.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Question ${i + 1} is empty')));
        return;
      }
      final filledOptions = q.options.where((o) => o.isNotEmpty).length;
      if (filledOptions < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1} needs at least 2 options')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final questionsData = _questions
        .map(
          (q) => {
            'question': q.question,
            'options': q.options,
            'correctAnswer': q.correctAnswer,
            'explanation': q.explanation,
          },
        )
        .toList();

    bool success;
    if (_isEditing) {
      success = await _quizService.updateQuiz(
        quizId: widget.existingQuiz!['quizId'] ?? widget.existingQuiz!['id'],
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        questions: questionsData,
        timeLimit: _timeLimit,
        passingScore: _passingScore,
        maxAttempts: _maxAttempts,
        shuffleQuestions: _shuffleQuestions,
        shuffleOptions: _shuffleOptions,
        showResults: _showResults,
      );
    } else {
      final quizId = await _quizService.createQuiz(
        courseId: widget.courseId,
        teacherId: widget.teacherId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        questions: questionsData,
        timeLimit: _timeLimit,
        passingScore: _passingScore,
        maxAttempts: _maxAttempts,
        shuffleQuestions: _shuffleQuestions,
        shuffleOptions: _shuffleOptions,
        showResults: _showResults,
      );
      success = quizId != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Quiz updated' : 'Quiz created'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save quiz'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Quiz Question Model
class QuizQuestion {
  String question;
  List<String> options;
  int correctAnswer;
  String? explanation;

  QuizQuestion({
    this.question = '',
    List<String>? options,
    this.correctAnswer = 0,
    this.explanation,
  }) : options = options ?? ['', '', '', ''];
}

/// Quiz Results Screen - View all student attempts (Teacher)
class QuizResultsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizResultsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final QuizService _quizService = QuizService();

  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _attempts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final stats = await _quizService.getQuizStatistics(widget.quizId);
    final attempts = await _quizService.getQuizAttempts(widget.quizId);

    if (mounted) {
      setState(() {
        _statistics = stats;
        _attempts = attempts.where((a) => a['status'] == 'completed').toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(widget.quizTitle),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Statistics Card
                  _buildStatisticsCard(isDark),
                  const SizedBox(height: 24),

                  // Attempts List
                  Text(
                    'Student Attempts (${_attempts.length})',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_attempts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 48,
                              color: AppTheme.getTextSecondary(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No attempts yet',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._attempts.map(
                      (attempt) => _buildAttemptCard(attempt, isDark),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.darkAccent.withOpacity(0.8), AppTheme.darkAccent]
              : [AppTheme.primaryColor.withOpacity(0.8), AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem2(
                'Attempts',
                _statistics['totalAttempts']?.toString() ?? '0',
              ),
              _buildStatItem2(
                'Students',
                _statistics['uniqueStudents']?.toString() ?? '0',
              ),
              _buildStatItem2(
                'Pass Rate',
                '${_statistics['passRate']?.toStringAsFixed(0) ?? '0'}%',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem2(
                'Average',
                '${_statistics['averageScore']?.toStringAsFixed(0) ?? '0'}%',
              ),
              _buildStatItem2(
                'Highest',
                '${_statistics['highestScore']?.toStringAsFixed(0) ?? '0'}%',
              ),
              _buildStatItem2(
                'Lowest',
                '${_statistics['lowestScore']?.toStringAsFixed(0) ?? '0'}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem2(String label, String value) {
    return Column(
      children: [
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

  Widget _buildAttemptCard(Map<String, dynamic> attempt, bool isDark) {
    final percentage = (attempt['percentage'] ?? 0.0).toDouble();
    final passed = attempt['passed'] == true;
    final timeTaken = attempt['timeTaken'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: passed
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          child: Icon(
            passed ? Icons.check : Icons.close,
            color: passed ? Colors.green : Colors.red,
          ),
        ),
        title: FutureBuilder(
          future: _resolveStudentName(attempt['studentId']),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? 'Loading...',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
        subtitle: Text(
          '${attempt['score']}/${attempt['totalQuestions']} • ${_formatDuration(timeTaken)}',
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 12,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: passed
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: passed ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<String> _resolveStudentName(String? studentId) async {
    if (studentId == null) return 'Unknown';

    try {
      final snap = await FirebaseDatabase.instance
          .ref()
          .child('student')
          .child(studentId)
          .child('name')
          .get();
      return snap.exists ? snap.value.toString() : 'Unknown Student';
    } catch (e) {
      return 'Unknown Student';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}m ${secs}s';
  }
}
