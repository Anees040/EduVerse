import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/services/teacher_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Screen for sending and viewing course announcements.
/// Teachers can broadcast messages to all enrolled students.
class TeacherAnnouncementsScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const TeacherAnnouncementsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<TeacherAnnouncementsScreen> createState() =>
      _TeacherAnnouncementsScreenState();
}

class _TeacherAnnouncementsScreenState
    extends State<TeacherAnnouncementsScreen> {
  final _service = TeacherFeatureService();
  final _messageController = TextEditingController();
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _selectedType = 'general';

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    final data = await _service.getCourseAnnouncements(widget.courseId);
    if (mounted) {
      setState(() {
        _announcements = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendAnnouncement() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);

    final success = await _service.sendCourseAnnouncement(
      courseId: widget.courseId,
      courseTitle: widget.courseTitle,
      message: message,
      announcementType: _selectedType,
    );

    if (mounted) {
      setState(() => _isSending = false);

      if (success) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement sent to all enrolled students!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAnnouncements();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send announcement'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              'Announcements',
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
      body: Column(
        children: [
          // Compose section
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
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
                    Icon(Icons.campaign, color: accentColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'New Announcement',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Type selector
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTypeChip('general', 'General', Icons.info_outline, accentColor, isDark),
                    _buildTypeChip('update', 'Update', Icons.update, Colors.blue, isDark),
                    _buildTypeChip('assignment', 'Assignment', Icons.assignment, Colors.orange, isDark),
                  ],
                ),
                const SizedBox(height: 12),

                // Message input
                TextField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Type your announcement message...',
                    hintStyle: TextStyle(
                      color: AppTheme.getTextSecondary(context).withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppTheme.darkBackground
                        : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                const SizedBox(height: 12),

                // Send button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendAnnouncement,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_isSending ? 'Sending...' : 'Send to All Students'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Announcements list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Previous Announcements',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_announcements.length} total',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _announcements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 48,
                              color: AppTheme.getTextSecondary(context),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No announcements yet',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAnnouncements,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _announcements.length,
                          itemBuilder: (context, index) {
                            return _buildAnnouncementCard(
                              _announcements[index],
                              isDark,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: color,
      backgroundColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.getTextPrimary(context),
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedType = value);
      },
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item, bool isDark) {
    final message = item['message'] ?? '';
    final type = item['type'] ?? 'general';
    final createdAt = item['createdAt'];

    IconData typeIcon;
    Color typeColor;
    switch (type) {
      case 'update':
        typeIcon = Icons.update;
        typeColor = Colors.blue;
        break;
      case 'assignment':
        typeIcon = Icons.assignment;
        typeColor = Colors.orange;
        break;
      default:
        typeIcon = Icons.campaign;
        typeColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: typeColor.withOpacity(0.12),
            child: Icon(typeIcon, color: typeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                if (createdAt != null && createdAt is int)
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(
                      DateTime.fromMillisecondsSinceEpoch(createdAt),
                    ),
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
