import 'package:flutter/material.dart';
import 'package:eduverse/services/course_notes_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Bottom sheet for managing course notes. Can be opened from the
/// course detail screen.
class CourseNotesSheet extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String? currentVideoId;
  final String? currentVideoTitle;

  const CourseNotesSheet({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.currentVideoId,
    this.currentVideoTitle,
  });

  /// Show the notes bottom sheet.
  static void show(
    BuildContext context, {
    required String courseId,
    required String courseTitle,
    String? currentVideoId,
    String? currentVideoTitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CourseNotesSheet(
        courseId: courseId,
        courseTitle: courseTitle,
        currentVideoId: currentVideoId,
        currentVideoTitle: currentVideoTitle,
      ),
    );
  }

  @override
  State<CourseNotesSheet> createState() => _CourseNotesSheetState();
}

class _CourseNotesSheetState extends State<CourseNotesSheet> {
  final _notesService = CourseNotesService();
  final _contentController = TextEditingController();

  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _editingNoteId;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final notes = await _notesService.getCourseNotes(widget.courseId);
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNote() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSaving = true);

    bool success;
    if (_editingNoteId != null) {
      success = await _notesService.updateNote(
        courseId: widget.courseId,
        noteId: _editingNoteId!,
        content: content,
      );
    } else {
      final id = await _notesService.saveNote(
        courseId: widget.courseId,
        content: content,
        videoId: widget.currentVideoId,
        title: widget.currentVideoTitle,
      );
      success = id != null;
    }

    if (success) {
      _contentController.clear();
      _editingNoteId = null;
      await _loadNotes();
    }

    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _deleteNote(String noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _notesService.deleteNote(courseId: widget.courseId, noteId: noteId);
      _loadNotes();
    }
  }

  void _startEditing(Map<String, dynamic> note) {
    setState(() {
      _editingNoteId = note['noteId'] as String;
      _contentController.text = note['content'] as String? ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notes — ${widget.courseTitle}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_notes.length} notes',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
          ),

          // Notes list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 48,
                          color: AppTheme.getTextSecondary(
                            context,
                          ).withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No notes yet.\nStart taking notes while learning!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildNoteCard(_notes[index], isDark);
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _editingNoteId != null
                          ? 'Edit your note...'
                          : 'Write a note...',
                      hintStyle: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkCard : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_editingNoteId != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _editingNoteId = null;
                        _contentController.clear();
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                IconButton(
                  onPressed: _isSaving ? null : _saveNote,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _editingNoteId != null
                              ? Icons.check_circle
                              : Icons.send_rounded,
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, bool isDark) {
    final content = note['content'] as String? ?? '';
    final videoTitle = note['title'] as String? ?? '';
    final updatedAt = note['updatedAt'] as int?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (videoTitle.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.videocam_outlined,
                  size: 14,
                  color: AppTheme.getTextSecondary(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    videoTitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getTextPrimary(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (updatedAt != null)
                Text(
                  _formatTime(updatedAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.getTextSecondary(context).withOpacity(0.7),
                  ),
                ),
              const Spacer(),
              InkWell(
                onTap: () => _startEditing(note),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _deleteNote(note['noteId'] as String? ?? ''),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
