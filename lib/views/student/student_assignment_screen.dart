import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eduverse/services/assignment_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Student Assignment View and Submission Screen
/// Allows students to view assignment details, submit files, and view grades
class StudentAssignmentScreen extends StatefulWidget {
  final String assignmentId;
  final String courseId;

  const StudentAssignmentScreen({
    super.key,
    required this.assignmentId,
    required this.courseId,
  });

  @override
  State<StudentAssignmentScreen> createState() =>
      _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState extends State<StudentAssignmentScreen> {
  final AssignmentService _assignmentService = AssignmentService();
  final TextEditingController _commentController = TextEditingController();

  Map<String, dynamic>? _assignment;
  Map<String, dynamic>? _submission;
  final List<Map<String, dynamic>> _selectedFiles = [];

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final assignment = await _assignmentService.getAssignment(
      widget.assignmentId,
    );
    final studentId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final submission = await _assignmentService.getStudentSubmission(
      widget.assignmentId,
      studentId,
    );

    setState(() {
      _assignment = assignment;
      _submission = submission;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Assignment'),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: AppTheme.getTextPrimary(context),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_assignment == null) {
      return Scaffold(
        backgroundColor: AppTheme.getBackgroundColor(context),
        appBar: AppBar(
          title: const Text('Assignment'),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: AppTheme.getTextPrimary(context),
          elevation: 0,
        ),
        body: const Center(child: Text('Assignment not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(_assignment!['title'] ?? 'Assignment'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
        actions: [
          if (_submission != null && _submission!['status'] == 'graded')
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.grade, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${_submission!['grade']}/${_assignment!['totalPoints']}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusBanner(isDark),
              _buildAssignmentDetails(isDark),
              if (_assignment!['attachments'] != null &&
                  (_assignment!['attachments'] as List).isNotEmpty)
                _buildAttachments(isDark),
              if (_submission != null)
                _buildSubmissionSection(isDark)
              else
                _buildSubmitSection(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    final dueDate = DateTime.tryParse(_assignment!['dueDate'] ?? '');
    final now = DateTime.now();
    final isPastDue = dueDate != null && now.isAfter(dueDate);
    final status = _submission?['status'];

    Color bannerColor;
    IconData bannerIcon;
    String bannerText;

    if (status == 'graded') {
      bannerColor = Colors.green;
      bannerIcon = Icons.check_circle;
      final grade = _submission!['grade'];
      final total = _assignment!['totalPoints'];
      bannerText = 'Graded: $grade/$total points';
    } else if (status == 'submitted' || status == 'late') {
      bannerColor = Colors.blue;
      bannerIcon = Icons.hourglass_empty;
      bannerText = 'Submitted - Awaiting grade';
    } else if (status == 'returned') {
      bannerColor = Colors.orange;
      bannerIcon = Icons.refresh;
      bannerText = 'Returned for revision';
    } else if (isPastDue) {
      if (_assignment!['allowLateSubmission'] == true) {
        bannerColor = Colors.orange;
        bannerIcon = Icons.warning;
        bannerText = 'Past due - Late submission allowed';
      } else {
        bannerColor = Colors.red;
        bannerIcon = Icons.block;
        bannerText = 'Past due - No longer accepting submissions';
      }
    } else {
      final timeLeft = dueDate?.difference(now);
      if (timeLeft != null && timeLeft.inHours < 24) {
        bannerColor = Colors.orange;
        bannerIcon = Icons.timer;
        bannerText = 'Due in ${_formatTimeLeft(timeLeft)}';
      } else {
        bannerColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
        bannerIcon = Icons.assignment;
        bannerText = 'Open for submission';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: bannerColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerText,
                  style: TextStyle(
                    color: bannerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (dueDate != null && status != 'graded')
                  Text(
                    'Due: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(dueDate)}',
                    style: TextStyle(
                      color: bannerColor.withOpacity(0.8),
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

  Widget _buildAssignmentDetails(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment,
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _assignment!['title'] ?? '',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppTheme.darkAccent
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_assignment!['totalPoints'] ?? 0} points',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_assignment!['description']?.toString().isNotEmpty ?? false) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _assignment!['description'],
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],

          if (_assignment!['instructions']?.toString().isNotEmpty ?? false) ...[
            const SizedBox(height: 20),
            Text(
              'Instructions',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark ? AppTheme.darkAccent : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _assignment!['instructions'],
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.getTextPrimary(context)
                            : Colors.blue.shade900,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Additional info
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildInfoChip(
                Icons.file_present,
                'Max files: ${_assignment!['maxFiles'] ?? 5}',
                isDark,
              ),
              _buildInfoChip(
                Icons.extension,
                'Types: ${(_assignment!['allowedFileTypes'] as List?)?.join(', ') ?? 'Any'}',
                isDark,
              ),
              if (_assignment!['allowLateSubmission'] == true)
                _buildInfoChip(
                  Icons.timer_off,
                  'Late: -${_assignment!['latePenalty'] ?? 0}%',
                  isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.getTextSecondary(context)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(bool isDark) {
    final attachments = List<Map<String, dynamic>>.from(
      (_assignment!['attachments'] as List?)?.map(
            (a) => Map<String, dynamic>.from(a as Map),
          ) ??
          [],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Attachments',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...attachments.map(
            (attachment) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(attachment['type'] ?? ''),
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment['name'] ?? 'Attachment',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (attachment['size'] != null)
                          Text(
                            _formatFileSize(attachment['size'] as int),
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.blue),
                    onPressed: () => _downloadFile(attachment['url']),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionSection(bool isDark) {
    final status = _submission!['status'];
    final submittedAt = DateTime.tryParse(_submission!['submittedAt'] ?? '');
    final files = List<Map<String, dynamic>>.from(
      (_submission!['files'] as List?)?.map(
            (f) => Map<String, dynamic>.from(f as Map),
          ) ??
          [],
    );

    return Container(
      margin: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(
                status == 'graded' ? Icons.grading : Icons.upload_file,
                color: status == 'graded' ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                status == 'graded' ? 'Your Grade' : 'Your Submission',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (status == 'graded') ...[
            const SizedBox(height: 20),
            // Grade display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        '${_submission!['grade']}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'out of ${_assignment!['totalPoints']}',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value:
                              (_submission!['grade'] ?? 0) /
                              (_assignment!['totalPoints'] ?? 100),
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.green,
                          ),
                        ),
                        Text(
                          '${((_submission!['grade'] ?? 0) / (_assignment!['totalPoints'] ?? 100) * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Feedback
            if (_submission!['feedback']?.toString().isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              Text(
                'Teacher Feedback',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _submission!['feedback'],
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),

          // Submitted files
          Text(
            'Submitted Files',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...files.map(
            (file) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getFileIcon(file['type'] ?? ''),
                    size: 18,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file['name'] ?? '',
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Submitted: ${submittedAt != null ? DateFormat('MMM d, yyyy \'at\' h:mm a').format(submittedAt) : 'N/A'}',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),

          // Resubmit option if returned
          if (status == 'returned') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() {
                  _submission = null;
                  _selectedFiles.clear();
                }),
                icon: const Icon(Icons.edit),
                label: const Text('Resubmit Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitSection(bool isDark) {
    final dueDate = DateTime.tryParse(_assignment!['dueDate'] ?? '');
    final isPastDue = dueDate != null && DateTime.now().isAfter(dueDate);
    final canSubmit = !isPastDue || _assignment!['allowLateSubmission'] == true;

    if (!canSubmit) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'This assignment is past due and is no longer accepting submissions.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(
                Icons.upload_file,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Submit Your Work',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (isPastDue) ...[
            const SizedBox(height: 12),
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
                      'Late submission: ${_assignment!['latePenalty'] ?? 0}% penalty will be applied',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // File upload area
          InkWell(
            onTap: _isUploading ? null : _pickFiles,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  if (_isUploading)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _isUploading ? 'Uploading...' : 'Click to upload files',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max ${_assignment!['maxFiles'] ?? 5} files',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected files list
          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Selected Files (${_selectedFiles.length})',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._selectedFiles.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(file['type'] ?? ''),
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file['name'] ?? '',
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(file['size'] as int? ?? 0),
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.red,
                      ),
                      onPressed: () =>
                          setState(() => _selectedFiles.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Comment field
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
            decoration: InputDecoration(
              labelText: 'Add a comment (optional)',
              labelStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
            ),
          ),

          // Submit button
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedFiles.isEmpty || _isSubmitting
                  ? null
                  : _submitAssignment,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Assignment',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final maxFiles = _assignment!['maxFiles'] ?? 5;

    if (_selectedFiles.length >= maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $maxFiles files allowed')),
      );
      return;
    }

    // Use ImagePicker to pick files (images and documents)
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final uploadUrl = await uploadToCloudinaryFromXFile(pickedFile);
      final fileSize = await File(pickedFile.path).length();

      if (uploadUrl != null) {
        setState(() {
          _selectedFiles.add({
            'name': pickedFile.name,
            'url': uploadUrl,
            'type': pickedFile.path.split('.').last,
            'size': fileSize,
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
      }
    }

    setState(() => _isUploading = false);
  }

  Future<void> _submitAssignment() async {
    if (_selectedFiles.isEmpty) return;

    setState(() => _isSubmitting = true);

    final studentId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final result = await _assignmentService.submitAssignment(
      assignmentId: widget.assignmentId,
      studentId: studentId,
      courseId: widget.courseId,
      submittedFiles: _selectedFiles,
      textResponse: _commentController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit assignment')),
      );
    }
  }

  void _downloadFile(String? url) {
    if (url == null) return;
    // Open URL in browser for download
    // You can use url_launcher package for this
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Opening file...')));
  }

  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTimeLeft(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays} days';
    if (duration.inHours > 0) return '${duration.inHours} hours';
    return '${duration.inMinutes} minutes';
  }
}
