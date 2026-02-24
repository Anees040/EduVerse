import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/features/admin/services/admin_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin screen to send and manage platform-wide announcements.
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _service = AdminFeatureService();
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    final data = await _service.getPlatformAnnouncements();
    if (mounted) {
      setState(() {
        _announcements = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _showComposeDialog() async {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String priority = 'normal';
    String audience = 'all';

    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = AppTheme.isDarkMode(ctx);
            return AlertDialog(
              backgroundColor: AppTheme.getCardColor(ctx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'New Announcement',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(ctx),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: AppTheme.getTextPrimary(ctx)),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: TextStyle(
                          color: AppTheme.getTextSecondary(ctx),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 4,
                      style: TextStyle(color: AppTheme.getTextPrimary(ctx)),
                      decoration: InputDecoration(
                        labelText: 'Message',
                        labelStyle: TextStyle(
                          color: AppTheme.getTextSecondary(ctx),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Priority',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(ctx),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['normal', 'important', 'urgent'].map((p) {
                        final selected = priority == p;
                        final color = p == 'urgent'
                            ? Colors.red
                            : p == 'important'
                                ? Colors.orange
                                : Colors.blue;
                        return ChoiceChip(
                          label: Text(p[0].toUpperCase() + p.substring(1)),
                          selected: selected,
                          selectedColor: color.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: selected ? color : AppTheme.getTextSecondary(ctx),
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: selected ? color : Colors.transparent,
                          ),
                          onSelected: (_) =>
                              setDialogState(() => priority = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Target Audience',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(ctx),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['all', 'students', 'teachers'].map((a) {
                        final selected = audience == a;
                        return ChoiceChip(
                          label: Text(a[0].toUpperCase() + a.substring(1)),
                          selected: selected,
                          selectedColor: (isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor)
                              .withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: selected
                                ? (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                : AppTheme.getTextSecondary(ctx),
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) =>
                              setDialogState(() => audience = a),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.getTextSecondary(ctx)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty ||
                        messageCtrl.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (sent == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final success = await _service.sendPlatformAnnouncement(
        title: titleCtrl.text.trim(),
        message: messageCtrl.text.trim(),
        priority: priority,
        targetAudience: audience,
      );
      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Announcement sent!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAnnouncements();
      } else {
        scaffoldMessenger.showSnackBar(
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

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Icon(Icons.campaign_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Platform Announcements',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showComposeDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _announcements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 64,
                            color: AppTheme.getTextSecondary(context)
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No announcements yet',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "New" to send your first announcement',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context)
                                  .withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAnnouncements,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: _announcements.length,
                        itemBuilder: (context, index) {
                          return _buildAnnouncementCard(
                              _announcements[index], isDark, accentColor);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(
    Map<String, dynamic> announcement,
    bool isDark,
    Color accentColor,
  ) {
    final title = announcement['title'] as String? ?? '';
    final message = announcement['message'] as String? ?? '';
    final priority = announcement['priority'] as String? ?? 'normal';
    final audience = announcement['targetAudience'] as String? ?? 'all';
    final isActive = announcement['isActive'] as bool? ?? true;
    final sentAt = announcement['sentAt'] as num?;
    final id = announcement['id'] as String? ?? '';

    final time = sentAt != null
        ? DateFormat('MMM d, yyyy h:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(sentAt.toInt()))
        : 'Unknown';

    final priorityColor = priority == 'urgent'
        ? Colors.red
        : priority == 'important'
            ? Colors.orange
            : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? priorityColor.withOpacity(0.3)
              : (isDark ? AppTheme.darkBorderColor : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  audience.toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              if (!isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'INACTIVE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppTheme.getTextSecondary(context),
                  size: 18,
                ),
                onSelected: (action) async {
                  if (action == 'toggle') {
                    await _service.toggleAnnouncementActive(id, !isActive);
                    _loadAnnouncements();
                  } else if (action == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.getCardColor(context),
                        title: Text(
                          'Delete Announcement?',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        content: Text(
                          'This cannot be undone.',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.deleteAnnouncement(id);
                      _loadAnnouncements();
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(isActive ? 'Deactivate' : 'Activate'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            title,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),

          // Message
          Text(
            message,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 14,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Timestamp
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: AppTheme.getTextSecondary(context).withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Text(
                time,
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context).withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
