import 'package:flutter/material.dart';
import 'package:eduverse/services/course_notes_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:intl/intl.dart';

/// Full-screen course notes manager.
/// Students can create, edit, search, pin and organize personal notes
/// linked to specific videos within a course.
class StudentNotesScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String? currentVideoId;
  final String? currentVideoTitle;

  const StudentNotesScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.currentVideoId,
    this.currentVideoTitle,
  });

  @override
  State<StudentNotesScreen> createState() => _StudentNotesScreenState();
}

class _StudentNotesScreenState extends State<StudentNotesScreen> {
  final _notesService = CourseNotesService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'all'; // all, pinned, video

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await _notesService.getCourseNotes(widget.courseId);
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredNotes {
    var list = _notes;

    // Filter
    if (_filter == 'pinned') {
      list = list.where((n) => n['pinned'] == true).toList();
    } else if (_filter == 'video' && widget.currentVideoId != null) {
      list = list
          .where((n) => n['videoId'] == widget.currentVideoId)
          .toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((n) {
        final title = (n['title'] as String? ?? '').toLowerCase();
        final content = (n['content'] as String? ?? '').toLowerCase();
        return title.contains(q) || content.contains(q);
      }).toList();
    }

    // Sort: pinned first, then by updatedAt
    list.sort((a, b) {
      final aPinned = a['pinned'] == true ? 0 : 1;
      final bPinned = b['pinned'] == true ? 0 : 1;
      if (aPinned != bPinned) return aPinned.compareTo(bPinned);
      final aTime = (a['updatedAt'] ?? a['createdAt'] ?? 0) as num;
      final bTime = (b['updatedAt'] ?? b['createdAt'] ?? 0) as num;
      return bTime.compareTo(aTime);
    });

    return list;
  }

  Future<void> _openNoteEditor({Map<String, dynamic>? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _NoteEditorScreen(
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          currentVideoId: widget.currentVideoId,
          currentVideoTitle: widget.currentVideoTitle,
          existingNote: existing,
        ),
      ),
    );
    if (result == true) _loadNotes();
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    final noteId = note['noteId'] as String? ?? '';
    final isPinned = note['pinned'] == true;
    await _notesService.updateNote(
      courseId: widget.courseId,
      noteId: noteId,
      content: note['content'] as String? ?? '',
      title: note['title'] as String?,
      pinned: !isPinned,
    );
    _loadNotes();
  }

  Future<void> _deleteNote(String noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This note will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accent = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
    final notes = _filteredNotes;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Notes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(widget.courseTitle,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getTextSecondary(context),
                    fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        onPressed: () => _openNoteEditor(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar & filters
          Container(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: TextStyle(
                      color: AppTheme.getTextPrimary(context), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    hintStyle: TextStyle(
                        color: AppTheme.getTextSecondary(context)
                            .withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search,
                        size: 20,
                        color: AppTheme.getTextSecondary(context)
                            .withOpacity(0.5)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close,
                                size: 18,
                                color: AppTheme.getTextSecondary(context)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            })
                        : null,
                    filled: true,
                    fillColor:
                        isDark ? AppTheme.darkCard : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', isDark, accent),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                          'Pinned', 'pinned', isDark, accent),
                      if (widget.currentVideoId != null) ...[
                        const SizedBox(width: 6),
                        _buildFilterChip(
                            'This Video', 'video', isDark, accent),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Notes count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  '${notes.length} note${notes.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Notes list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                    ? _buildEmptyState(isDark, accent)
                    : RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: notes.length,
                          itemBuilder: (_, i) =>
                              _buildNoteCard(notes[i], isDark, accent),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String value, bool isDark, Color accent) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withOpacity(0.12)
              : isDark
                  ? AppTheme.darkCard
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border:
              selected ? Border.all(color: accent.withOpacity(0.4)) : null,
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? accent : AppTheme.getTextSecondary(context),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color accent) {
    final hasFilters = _searchQuery.isNotEmpty || _filter != 'all';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                hasFilters
                    ? Icons.search_off_rounded
                    : Icons.note_add_outlined,
                size: 64,
                color: AppTheme.getTextSecondary(context).withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No matching notes' : 'No notes yet',
              style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try a different search or filter'
                  : 'Take notes while watching lectures to study later',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context), fontSize: 14),
            ),
            if (!hasFilters) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openNoteEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create First Note'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(
      Map<String, dynamic> note, bool isDark, Color accent) {
    final title = note['title'] as String? ?? '';
    final content = note['content'] as String? ?? '';
    final videoTitle = note['videoTitle'] ?? note['title'] as String? ?? '';
    final videoId = note['videoId'] as String? ?? '';
    final isPinned = note['pinned'] == true;
    final noteId = note['noteId'] as String? ?? '';
    final updatedAt = note['updatedAt'] ?? note['createdAt'];
    final label = note['label'] as String? ?? '';

    final labelColor = _getLabelColor(label);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openNoteEditor(existing: note),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPinned
                    ? accent.withOpacity(0.4)
                    : isDark
                        ? AppTheme.darkBorderColor
                        : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: pin icon, label, time, actions
                Row(
                  children: [
                    if (isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child:
                            Icon(Icons.push_pin, size: 14, color: accent),
                      ),
                    if (label.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: labelColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 9,
                                color: labelColor,
                                fontWeight: FontWeight.bold)),
                      ),
                    if (videoId.isNotEmpty) ...[
                      Icon(Icons.videocam_outlined,
                          size: 12,
                          color: AppTheme.getTextSecondary(context)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          videoTitle.isNotEmpty ? videoTitle : 'Video note',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.getTextSecondary(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (updatedAt != null && updatedAt is num)
                      Text(_formatTime(updatedAt.toInt()),
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.getTextSecondary(context)
                                  .withOpacity(0.6))),
                  ],
                ),
                // Title
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.getTextPrimary(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                // Content preview
                const SizedBox(height: 6),
                Text(content,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.getTextPrimary(context),
                        height: 1.5),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
                // Actions row
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionIcon(
                      isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      isPinned ? accent : null,
                      () => _togglePin(note),
                      'Pin',
                    ),
                    const SizedBox(width: 12),
                    _actionIcon(
                      Icons.edit_outlined,
                      null,
                      () => _openNoteEditor(existing: note),
                      'Edit',
                    ),
                    const SizedBox(width: 12),
                    _actionIcon(
                      Icons.delete_outline,
                      Colors.red.withOpacity(0.7),
                      () => _deleteNote(noteId),
                      'Delete',
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

  Widget _actionIcon(
      IconData icon, Color? color, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon,
              size: 18,
              color:
                  color ?? AppTheme.getTextSecondary(context).withOpacity(0.5)),
        ),
      ),
    );
  }

  Color _getLabelColor(String label) {
    switch (label) {
      case 'important':
        return Colors.red;
      case 'review':
        return Colors.orange;
      case 'concept':
        return Colors.blue;
      case 'formula':
        return Colors.purple;
      case 'example':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}

// ─── Note Editor Screen ───
class _NoteEditorScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final String? currentVideoId;
  final String? currentVideoTitle;
  final Map<String, dynamic>? existingNote;

  const _NoteEditorScreen({
    required this.courseId,
    required this.courseTitle,
    this.currentVideoId,
    this.currentVideoTitle,
    this.existingNote,
  });

  @override
  State<_NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<_NoteEditorScreen> {
  final _notesService = CourseNotesService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSaving = false;
  bool _linkToVideo = false;
  String _label = '';
  bool get _isEditing => widget.existingNote != null;

  static const _labels = [
    {'key': '', 'text': 'None', 'color': Colors.grey},
    {'key': 'important', 'text': 'Important', 'color': Colors.red},
    {'key': 'review', 'text': 'Review', 'color': Colors.orange},
    {'key': 'concept', 'text': 'Concept', 'color': Colors.blue},
    {'key': 'formula', 'text': 'Formula', 'color': Colors.purple},
    {'key': 'example', 'text': 'Example', 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final note = widget.existingNote!;
      _titleController.text = note['title'] as String? ?? '';
      _contentController.text = note['content'] as String? ?? '';
      _label = note['label'] as String? ?? '';
      _linkToVideo = (note['videoId'] as String? ?? '').isNotEmpty;
    } else {
      _linkToVideo = widget.currentVideoId != null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note content cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final videoId = _linkToVideo ? widget.currentVideoId : null;
    final videoTitle = _linkToVideo ? widget.currentVideoTitle : null;

    bool success;
    if (_isEditing) {
      success = await _notesService.updateNote(
        courseId: widget.courseId,
        noteId: widget.existingNote!['noteId'] as String,
        content: content,
        title: title.isNotEmpty ? title : null,
        label: _label,
      );
    } else {
      final id = await _notesService.saveNote(
        courseId: widget.courseId,
        content: content,
        videoId: videoId,
        title: title.isNotEmpty ? title : videoTitle,
        label: _label,
      );
      success = id != null;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save note'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accent = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
        title: Text(_isEditing ? 'Edit Note' : 'New Note',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: Icon(Icons.check, color: accent),
              label: Text('Save',
                  style:
                      TextStyle(color: accent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Title
          TextField(
            controller: _titleController,
            style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.w600,
                fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Note title (optional)',
              hintStyle: TextStyle(
                  color:
                      AppTheme.getTextSecondary(context).withOpacity(0.4),
                  fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
          ),
          Divider(
              color: isDark
                  ? AppTheme.darkBorderColor
                  : Colors.grey.shade200),
          const SizedBox(height: 4),

          // Label chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _labels.map((l) {
                final key = l['key'] as String;
                final text = l['text'] as String;
                final color = l['color'] as Color;
                final selected = _label == key;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _label = key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withOpacity(0.15)
                            : isDark
                                ? AppTheme.darkCard
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: color.withOpacity(0.5))
                            : null,
                      ),
                      child: Text(text,
                          style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? color
                                  : AppTheme.getTextSecondary(context),
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Link to video toggle
          if (widget.currentVideoId != null) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Link to current video',
                  style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 14)),
              subtitle: Text(widget.currentVideoTitle ?? '',
                  style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              value: _linkToVideo,
              onChanged: (v) => setState(() => _linkToVideo = v),
              activeColor: accent,
            ),
          ],

          const SizedBox(height: 8),

          // Content
          Container(
            constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.4),
            child: TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 12,
              style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 15,
                  height: 1.6),
              decoration: InputDecoration(
                hintText: 'Write your notes here...\n\n'
                    '• Key concepts\n'
                    '• Important formulas\n'
                    '• Questions to review',
                hintStyle: TextStyle(
                    color:
                        AppTheme.getTextSecondary(context).withOpacity(0.35),
                    height: 1.6),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
