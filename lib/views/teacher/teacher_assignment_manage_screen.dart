import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:intl/intl.dart';
import 'package:eduverse/services/assignment_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

/// Assignment Management Screen for Teachers
/// Create, edit, and manage assignments for a course
class TeacherAssignmentManageScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String teacherId;

  const TeacherAssignmentManageScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.teacherId,
  });

  @override
  State<TeacherAssignmentManageScreen> createState() =>
      _TeacherAssignmentManageScreenState();
}

class _TeacherAssignmentManageScreenState
    extends State<TeacherAssignmentManageScreen> {
  final AssignmentService _assignmentService = AssignmentService();

  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    final assignments = await _assignmentService.getCourseAssignments(
      widget.courseId,
    );
    if (mounted) {
      setState(() {
        _assignments = assignments;
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
            const Text('Assignments'),
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
          : _assignments.isEmpty
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              onRefresh: _loadAssignments,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assignments.length,
                itemBuilder: (context, index) =>
                    _buildAssignmentCard(_assignments[index], isDark),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAssignment(context),
        backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('Create Assignment'),
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
                Icons.assignment_outlined,
                size: 64,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Assignments Yet',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create assignments to assess your students',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _createAssignment(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Assignment'),
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

  Widget _buildAssignmentCard(Map<String, dynamic> assignment, bool isDark) {
    final isPublished = assignment['isPublished'] == true;
    final dueDate = assignment['dueDate'] as int? ?? 0;
    final totalPoints = assignment['totalPoints'] as int? ?? 100;
    final now = DateTime.now().millisecondsSinceEpoch;
    final isOverdue = now > dueDate && isPublished;
    final dueDateFormatted = DateFormat(
      'MMM d, y • h:mm a',
    ).format(DateTime.fromMillisecondsSinceEpoch(dueDate));

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
        onTap: () => _editAssignment(assignment),
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
                      color:
                          (isOverdue
                                  ? Colors.red
                                  : (isPublished
                                        ? Colors.green
                                        : Colors.orange))
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assignment,
                      color: isOverdue
                          ? Colors.red
                          : (isPublished ? Colors.green : Colors.orange),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignment['title'] ?? 'Untitled Assignment',
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
                            if (isOverdue) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Past Due',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
                    onSelected: (value) =>
                        _handleAssignmentAction(assignment, value),
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
                        value: 'submissions',
                        child: Row(
                          children: [
                            Icon(Icons.assignment_turned_in, size: 20),
                            SizedBox(width: 8),
                            Text('View Submissions'),
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
              if (assignment['description']?.toString().isNotEmpty ??
                  false) ...[
                const SizedBox(height: 12),
                Text(
                  assignment['description'],
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
                      Icons.calendar_today,
                      dueDateFormatted,
                      isOverdue ? Colors.red : null,
                      isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      Icons.star_outline,
                      '$totalPoints pts',
                      null,
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

  Widget _buildStatItem(IconData icon, String text, Color? color, bool isDark) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? AppTheme.getTextSecondary(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? AppTheme.getTextSecondary(context),
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _createAssignment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentEditorScreen(
          courseId: widget.courseId,
          teacherId: widget.teacherId,
          onSaved: _loadAssignments,
        ),
      ),
    );
  }

  void _editAssignment(Map<String, dynamic> assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssignmentEditorScreen(
          courseId: widget.courseId,
          teacherId: widget.teacherId,
          existingAssignment: assignment,
          onSaved: _loadAssignments,
        ),
      ),
    );
  }

  void _handleAssignmentAction(
    Map<String, dynamic> assignment,
    String action,
  ) async {
    final assignmentId = assignment['assignmentId'] ?? assignment['id'];

    switch (action) {
      case 'publish':
      case 'unpublish':
        final success = await _assignmentService.toggleAssignmentPublished(
          assignmentId,
          action == 'publish',
        );
        if (success) {
          _loadAssignments();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  action == 'publish'
                      ? 'Assignment published'
                      : 'Assignment unpublished',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        break;
      case 'edit':
        _editAssignment(assignment);
        break;
      case 'submissions':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AssignmentSubmissionsScreen(
              assignmentId: assignmentId,
              assignmentTitle: assignment['title'] ?? 'Assignment',
              totalPoints: assignment['totalPoints'] ?? 100,
            ),
          ),
        );
        break;
      case 'delete':
        _confirmDeleteAssignment(assignment);
        break;
    }
  }

  void _confirmDeleteAssignment(Map<String, dynamic> assignment) {
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
              'Delete Assignment',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${assignment['title']}"? This will also delete all student submissions.',
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
              final success = await _assignmentService.deleteAssignment(
                assignment['assignmentId'] ?? assignment['id'],
              );
              if (success) {
                _loadAssignments();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Assignment deleted'),
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

/// Assignment Editor Screen - Create/Edit an assignment
class AssignmentEditorScreen extends StatefulWidget {
  final String courseId;
  final String teacherId;
  final Map<String, dynamic>? existingAssignment;
  final VoidCallback onSaved;

  const AssignmentEditorScreen({
    super.key,
    required this.courseId,
    required this.teacherId,
    this.existingAssignment,
    required this.onSaved,
  });

  @override
  State<AssignmentEditorScreen> createState() => _AssignmentEditorScreenState();
}

class _AssignmentEditorScreenState extends State<AssignmentEditorScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dueTime = const TimeOfDay(hour: 23, minute: 59);
  int _totalPoints = 100;
  int _maxFileSize = 10;
  bool _allowLateSubmission = true;
  int _latePenaltyPercent = 10;
  List<Map<String, dynamic>> _attachments = [];
  List<String> _allowedFileTypes = ['pdf', 'doc', 'docx', 'image'];

  bool _isSaving = false;
  bool _isUploading = false;

  bool get _isEditing => widget.existingAssignment != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExistingAssignment();
    }
  }

  void _loadExistingAssignment() {
    final assignment = widget.existingAssignment!;
    _titleController.text = assignment['title'] ?? '';
    _descriptionController.text = assignment['description'] ?? '';
    _instructionsController.text = assignment['instructions'] ?? '';

    final dueDateMs =
        assignment['dueDate'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final dueDateTime = DateTime.fromMillisecondsSinceEpoch(dueDateMs);
    _dueDate = dueDateTime;
    _dueTime = TimeOfDay.fromDateTime(dueDateTime);

    _totalPoints = assignment['totalPoints'] ?? 100;
    _maxFileSize = assignment['maxFileSize'] ?? 10;
    _allowLateSubmission = assignment['allowLateSubmission'] ?? true;
    _latePenaltyPercent = assignment['latePenaltyPercent'] ?? 10;
    _attachments = List<Map<String, dynamic>>.from(
      assignment['attachments'] ?? [],
    );
    _allowedFileTypes = List<String>.from(
      assignment['allowedFileTypes'] ?? ['pdf', 'doc', 'docx', 'image'],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Assignment' : 'Create Assignment',
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.primaryColor,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppTheme.primaryColor,
        ),
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
              onPressed: _saveAssignment,
              icon: Icon(
                Icons.save,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              label: Text(
                'Save',
                style: TextStyle(
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info Card
            _buildSectionCard('Assignment Details', [
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Title *', Icons.title),
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
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsController,
                decoration: _inputDecoration(
                  'Instructions (optional)',
                  Icons.list_alt,
                ),
                maxLines: 5,
              ),
            ], isDark),
            const SizedBox(height: 16),

            // Due Date & Points
            _buildSectionCard('Deadline & Grading', [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDueDate,
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          'Due Date *',
                          Icons.calendar_today,
                        ),
                        child: Text(
                          DateFormat('MMM d, y').format(_dueDate),
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectDueTime,
                      child: InputDecorator(
                        decoration: _inputDecoration(
                          'Due Time *',
                          Icons.access_time,
                        ),
                        child: Text(
                          _dueTime.format(context),
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberSetting(
                      'Total Points',
                      _totalPoints,
                      (v) => setState(() => _totalPoints = v),
                      min: 1,
                      max: 1000,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberSetting(
                      'Max File Size (MB)',
                      _maxFileSize,
                      (v) => setState(() => _maxFileSize = v),
                      min: 1,
                      max: 50,
                    ),
                  ),
                ],
              ),
            ], isDark),
            const SizedBox(height: 16),

            // Late Submission Settings
            _buildSectionCard('Late Submission', [
              SwitchListTile(
                title: Text(
                  'Allow Late Submission',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                subtitle: Text(
                  'Students can submit after the due date',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
                value: _allowLateSubmission,
                onChanged: (v) => setState(() => _allowLateSubmission = v),
                activeColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
              ),
              if (_allowLateSubmission)
                _buildNumberSetting(
                  'Late Penalty (%)',
                  _latePenaltyPercent,
                  (v) => setState(() => _latePenaltyPercent = v),
                  hint: 'Points deducted per day late',
                  max: 100,
                ),
            ], isDark),
            const SizedBox(height: 16),

            // File Types
            _buildSectionCard('Allowed File Types', [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFileTypeChip('PDF', 'pdf', isDark),
                  _buildFileTypeChip('Word', 'doc', isDark),
                  _buildFileTypeChip('Word (docx)', 'docx', isDark),
                  _buildFileTypeChip('Images', 'image', isDark),
                  _buildFileTypeChip('Text', 'txt', isDark),
                  _buildFileTypeChip('Excel', 'xlsx', isDark),
                ],
              ),
            ], isDark),
            const SizedBox(height: 16),

            // Attachments
            _buildSectionCard('Attachments', [
              if (_attachments.isNotEmpty) ...[
                ...List.generate(_attachments.length, (index) {
                  final attachment = _attachments[index];
                  return ListTile(
                    leading: Icon(
                      _getFileIcon(attachment['type'] ?? ''),
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                    title: Text(
                      attachment['name'] ?? 'File',
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () =>
                          setState(() => _attachments.removeAt(index)),
                    ),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const Divider(),
              ],
              _isUploading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _addAttachment,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Add Attachment'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
            ], isDark),

            const SizedBox(height: 80),
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

  Widget _buildFileTypeChip(String label, String type, bool isDark) {
    final isSelected = _allowedFileTypes.contains(type);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _allowedFileTypes.add(type);
          } else {
            _allowedFileTypes.remove(type);
          }
        });
      },
      backgroundColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
      selectedColor: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
          .withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected
            ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
            : AppTheme.getTextPrimary(context),
      ),
      checkmarkColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  Future<void> _selectDueTime() async {
    final time = await showTimePicker(context: context, initialTime: _dueTime);
    if (time != null) {
      setState(() => _dueTime = time);
    }
  }

  Future<void> _addAttachment() async {
    try {
      // Show options dialog
      final type = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Attachment',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.image, color: AppTheme.primaryColor),
                title: Text(
                  'Image',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () => Navigator.pop(ctx, 'image'),
              ),
              ListTile(
                leading: Icon(
                  Icons.insert_drive_file,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  'Document (PDF, Word, etc.)',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                onTap: () => Navigator.pop(ctx, 'document'),
              ),
            ],
          ),
        ),
      );

      if (type == null) return;

      setState(() => _isUploading = true);

      if (type == 'image') {
        // Use image picker for images
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);

        if (pickedFile != null) {
          final url = await uploadToCloudinaryFromXFile(pickedFile);

          if (url != null && mounted) {
            final fileSize = kIsWeb ? 0 : await File(pickedFile.path).length();
            setState(() {
              _attachments.add({
                'name': pickedFile.name,
                'url': url,
                'type': 'image',
                'size': fileSize,
              });
            });
          }
        }
      } else {
        // Use file picker for documents
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'txt',
            'xlsx',
            'xls',
            'ppt',
            'pptx',
          ],
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;

          if (file.path != null) {
            // Upload the file
            final xFile = XFile(file.path!);
            final url = await uploadToCloudinaryFromXFile(xFile);

            if (url != null && mounted) {
              setState(() {
                _attachments.add({
                  'name': file.name,
                  'url': url,
                  'type': file.extension ?? 'file',
                  'size': file.size,
                });
              });
            }
          } else if (file.bytes != null) {
            // Web platform - upload from bytes
            final url = await uploadToCloudinaryFromBytes(
              file.bytes!,
              file.name,
            );

            if (url != null && mounted) {
              setState(() {
                _attachments.add({
                  'name': file.name,
                  'url': url,
                  'type': file.extension ?? 'file',
                  'size': file.size,
                });
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error adding attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding attachment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final dueDateTimestamp = DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    ).millisecondsSinceEpoch;

    bool success;
    if (_isEditing) {
      success = await _assignmentService.updateAssignment(
        assignmentId:
            widget.existingAssignment!['assignmentId'] ??
            widget.existingAssignment!['id'],
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        instructions: _instructionsController.text.trim(),
        dueDate: dueDateTimestamp,
        totalPoints: _totalPoints,
        attachments: _attachments,
        allowedFileTypes: _allowedFileTypes,
        maxFileSize: _maxFileSize,
        allowLateSubmission: _allowLateSubmission,
        latePenaltyPercent: _latePenaltyPercent,
      );
    } else {
      final assignmentId = await _assignmentService.createAssignment(
        courseId: widget.courseId,
        teacherId: widget.teacherId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        instructions: _instructionsController.text.trim(),
        dueDate: dueDateTimestamp,
        totalPoints: _totalPoints,
        attachments: _attachments,
        allowedFileTypes: _allowedFileTypes,
        maxFileSize: _maxFileSize,
        allowLateSubmission: _allowLateSubmission,
        latePenaltyPercent: _latePenaltyPercent,
      );
      success = assignmentId != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Assignment updated' : 'Assignment created',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save assignment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Assignment Submissions Screen - View and grade submissions (Teacher)
class AssignmentSubmissionsScreen extends StatefulWidget {
  final String assignmentId;
  final String assignmentTitle;
  final int totalPoints;

  const AssignmentSubmissionsScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.totalPoints,
  });

  @override
  State<AssignmentSubmissionsScreen> createState() =>
      _AssignmentSubmissionsScreenState();
}

class _AssignmentSubmissionsScreenState
    extends State<AssignmentSubmissionsScreen> {
  final AssignmentService _assignmentService = AssignmentService();

  Map<String, dynamic> _statistics = {};
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final stats = await _assignmentService.getAssignmentStatistics(
      widget.assignmentId,
    );
    final submissions = await _assignmentService.getAssignmentSubmissions(
      widget.assignmentId,
    );

    if (mounted) {
      setState(() {
        _statistics = stats;
        _submissions = submissions;
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
        title: Text(widget.assignmentTitle),
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

                  // Submissions List
                  Text(
                    'Submissions (${_submissions.length})',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_submissions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: AppTheme.getTextSecondary(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No submissions yet',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._submissions.map(
                      (submission) => _buildSubmissionCard(submission, isDark),
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
                'Submitted',
                _statistics['totalSubmissions']?.toString() ?? '0',
              ),
              _buildStatItem2(
                'Graded',
                _statistics['gradedCount']?.toString() ?? '0',
              ),
              _buildStatItem2(
                'Pending',
                _statistics['pendingCount']?.toString() ?? '0',
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
                '${_statistics['averageGrade']?.toStringAsFixed(0) ?? '0'}/${widget.totalPoints}',
              ),
              _buildStatItem2(
                'Highest',
                '${_statistics['highestGrade']?.toString() ?? '0'}/${widget.totalPoints}',
              ),
              _buildStatItem2(
                'Late',
                _statistics['lateCount']?.toString() ?? '0',
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
            fontSize: 20,
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

  Widget _buildSubmissionCard(Map<String, dynamic> submission, bool isDark) {
    final status = submission['status'] ?? 'submitted';
    final isLate = submission['isLate'] == true;
    final grade = submission['grade'];
    final isGraded = status == 'graded';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'graded':
        statusColor = Colors.green;
        statusText = 'Graded';
        break;
      case 'returned':
        statusColor = Colors.orange;
        statusText = 'Returned';
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'Pending Review';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () => _openGradeDialog(submission),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                            .withOpacity(0.1),
                    child: Text(
                      (submission['studentName'] ?? 'S')[0].toUpperCase(),
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission['studentName'] ?? 'Unknown Student',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isLate) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Late',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isGraded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$grade/${widget.totalPoints}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _openGradeDialog(submission),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Grade'),
                    ),
                ],
              ),
              if (submission['textResponse']?.toString().isNotEmpty ??
                  false) ...[
                const SizedBox(height: 12),
                Text(
                  submission['textResponse'],
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (submission['feedback']?.toString().isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.feedback_outlined,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          submission['feedback'],
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openGradeDialog(Map<String, dynamic> submission) {
    final isDark = AppTheme.isDarkMode(context);
    final gradeController = TextEditingController(
      text: submission['grade']?.toString() ?? '',
    );
    final feedbackController = TextEditingController(
      text: submission['feedback'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Grade Submission',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              submission['studentName'] ?? 'Unknown Student',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: gradeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Grade (out of ${widget.totalPoints})',
                filled: true,
                fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Feedback (optional)',
                filled: true,
                fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _assignmentService.returnSubmission(
                submissionId: submission['submissionId'] ?? submission['id'],
                teacherId: '', // TODO: Get from auth
                feedback: feedbackController.text.trim(),
              );
              if (success) _loadData();
            },
            child: const Text(
              'Return for Revision',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final grade = int.tryParse(gradeController.text);
              if (grade == null || grade < 0 || grade > widget.totalPoints) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enter a valid grade (0-${widget.totalPoints})',
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(ctx);
              final success = await _assignmentService.gradeSubmission(
                submissionId: submission['submissionId'] ?? submission['id'],
                grade: grade,
                teacherId: '', // TODO: Get from auth
                feedback: feedbackController.text.trim(),
              );
              if (success) {
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Submission graded'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Submit Grade'),
          ),
        ],
      ),
    );
  }
}
