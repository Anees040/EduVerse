import 'package:flutter/material.dart';
import 'package:eduverse/services/assignment_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/student/student_assignment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Student Assignment List Screen
/// Shows all available assignments for a course with status indicators
class StudentAssignmentListScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const StudentAssignmentListScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudentAssignmentListScreen> createState() =>
      _StudentAssignmentListScreenState();
}

class _StudentAssignmentListScreenState
    extends State<StudentAssignmentListScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final String _studentId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<Map<String, dynamic>> _assignments = [];
  Map<String, Map<String, dynamic>?> _submissions = {};
  bool _isLoading = true;
  String _filter = 'all'; // all, pending, submitted, graded

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);

    // Get course assignments and filter only published ones
    final allAssignments = await _assignmentService.getCourseAssignments(
      widget.courseId,
    );
    final assignments = allAssignments
        .where((a) => a['isPublished'] == true)
        .toList();

    // Load submissions for each assignment
    final submissions = <String, Map<String, dynamic>?>{};
    for (final assignment in assignments) {
      final assignmentId = assignment['id'] as String?;
      if (assignmentId != null) {
        submissions[assignmentId] = await _assignmentService
            .getStudentSubmission(assignmentId, _studentId);
      }
    }

    setState(() {
      _assignments = assignments;
      _submissions = submissions;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredAssignments {
    if (_filter == 'all') return _assignments;

    return _assignments.where((a) {
      final submission = _submissions[a['id']];
      final status = submission?['status'];

      switch (_filter) {
        case 'pending':
          return submission == null;
        case 'submitted':
          return status == 'submitted' || status == 'late';
        case 'graded':
          return status == 'graded';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Assignments'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: isDark ? AppTheme.darkSurface : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('all', 'All', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Pending', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('submitted', 'Submitted', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('graded', 'Graded', isDark),
                ],
              ),
            ),
          ),

          // Assignment list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAssignments,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAssignments.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAssignments.length,
                      itemBuilder: (context, index) => _buildAssignmentCard(
                        _filteredAssignments[index],
                        isDark,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filter = value),
      backgroundColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
      selectedColor: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
          .withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected
            ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
            : AppTheme.getTextSecondary(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
      side: BorderSide(
        color: isSelected
            ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
            : Colors.transparent,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: AppTheme.getTextSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _filter == 'all'
                ? 'No Assignments Available'
                : 'No ${_filter.substring(0, 1).toUpperCase()}${_filter.substring(1)} Assignments',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for assignments',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment, bool isDark) {
    final assignmentId = assignment['id'] as String;
    final title = assignment['title'] ?? 'Untitled Assignment';
    final description = assignment['description'] ?? '';
    final totalPoints = assignment['totalPoints'] ?? 100;
    final dueDate = DateTime.tryParse(assignment['dueDate'] ?? '');

    final submission = _submissions[assignmentId];
    final status = submission?['status'];
    final grade = submission?['grade'];

    // Determine status
    final now = DateTime.now();
    final isPastDue = dueDate != null && now.isAfter(dueDate);
    final isSubmitted = status == 'submitted' || status == 'late';
    final isGraded = status == 'graded';
    final canSubmit = !isPastDue || assignment['allowLateSubmission'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGraded
              ? Colors.green.withOpacity(0.5)
              : isSubmitted
              ? Colors.blue.withOpacity(0.5)
              : isPastDue && !canSubmit
              ? Colors.red.withOpacity(0.5)
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
          onTap: () => _openAssignment(assignment),
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
                          isGraded,
                          isSubmitted,
                          isPastDue,
                          canSubmit,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(isGraded, isSubmitted, isPastDue),
                        color: _getStatusColor(
                          isGraded,
                          isSubmitted,
                          isPastDue,
                          canSubmit,
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
                              _buildInfoPill('$totalPoints points', isDark),
                              const SizedBox(width: 8),
                              if (assignment['allowLateSubmission'] == true)
                                _buildInfoPill('Late OK', isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    _buildStatusBadge(
                      isGraded,
                      isSubmitted,
                      isPastDue,
                      canSubmit,
                      grade,
                      totalPoints,
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

                // Due date and action
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isPastDue ? Icons.event_busy : Icons.event,
                            size: 16,
                            color: isPastDue && !isSubmitted && !isGraded
                                ? Colors.red
                                : AppTheme.getTextSecondary(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dueDate != null
                                ? 'Due: ${DateFormat('MMM d, h:mm a').format(dueDate)}'
                                : 'No due date',
                            style: TextStyle(
                              color: isPastDue && !isSubmitted && !isGraded
                                  ? Colors.red
                                  : AppTheme.getTextSecondary(context),
                              fontSize: 13,
                              fontWeight: isPastDue && !isSubmitted
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isSubmitted && !isGraded && canSubmit)
                      ElevatedButton.icon(
                        onPressed: () => _openAssignment(assignment),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Submit'),
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
                      )
                    else if (isSubmitted)
                      OutlinedButton.icon(
                        onPressed: () => _openAssignment(assignment),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      )
                    else if (isGraded)
                      OutlinedButton.icon(
                        onPressed: () => _openAssignment(assignment),
                        icon: const Icon(Icons.grade, size: 18),
                        label: const Text('Results'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
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
    bool isGraded,
    bool isSubmitted,
    bool isPastDue,
    bool canSubmit,
    dynamic grade,
    int totalPoints,
  ) {
    Color color;
    String text;
    IconData icon;

    if (isGraded) {
      color = Colors.green;
      text = '$grade/$totalPoints';
      icon = Icons.grade;
    } else if (isSubmitted) {
      color = Colors.blue;
      text = 'Submitted';
      icon = Icons.check_circle;
    } else if (isPastDue && !canSubmit) {
      color = Colors.red;
      text = 'Missing';
      icon = Icons.error;
    } else if (isPastDue && canSubmit) {
      color = Colors.orange;
      text = 'Late';
      icon = Icons.warning;
    } else {
      color = Colors.green;
      text = 'Open';
      icon = Icons.assignment;
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
    bool isGraded,
    bool isSubmitted,
    bool isPastDue,
    bool canSubmit,
  ) {
    if (isGraded) return Colors.green;
    if (isSubmitted) return Colors.blue;
    if (isPastDue && !canSubmit) return Colors.red;
    if (isPastDue && canSubmit) return Colors.orange;
    return AppTheme.primaryColor;
  }

  IconData _getStatusIcon(bool isGraded, bool isSubmitted, bool isPastDue) {
    if (isGraded) return Icons.grading;
    if (isSubmitted) return Icons.task_alt;
    if (isPastDue) return Icons.assignment_late;
    return Icons.assignment;
  }

  void _openAssignment(Map<String, dynamic> assignment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAssignmentScreen(
          assignmentId: assignment['id'],
          courseId: widget.courseId,
        ),
      ),
    ).then((_) => _loadAssignments());
  }
}
