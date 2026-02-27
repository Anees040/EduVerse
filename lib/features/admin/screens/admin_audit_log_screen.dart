import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin Activity screen - live real-time feed of all admin actions
/// with wrapped filter chips and meaningful setting descriptions.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  String? _filterAction;

  // Grouped categories instead of individual actions
  static const _filterCategories = <Map<String, dynamic>>[
    {'value': null, 'label': 'All', 'icon': Icons.list_rounded},
    {
      'value': 'announcements',
      'label': 'Announcements',
      'icon': Icons.campaign_rounded
    },
    {
      'value': 'settings',
      'label': 'Settings',
      'icon': Icons.settings_rounded
    },
    {'value': 'courses', 'label': 'Courses', 'icon': Icons.school_rounded},
    {'value': 'users', 'label': 'Users', 'icon': Icons.people_rounded},
    {
      'value': 'moderation',
      'label': 'Moderation',
      'icon': Icons.shield_rounded
    },
    {
      'value': 'support',
      'label': 'Support',
      'icon': Icons.support_agent_rounded
    },
  ];

  // Map individual actions to categories
  static const _actionCategoryMap = <String, String>{
    'send_announcement': 'announcements',
    'activate_announcement': 'announcements',
    'deactivate_announcement': 'announcements',
    'delete_announcement': 'announcements',
    'update_setting': 'settings',
    'update_settings': 'settings',
    'publish_course': 'courses',
    'unpublish_course': 'courses',
    'flag_course': 'courses',
    'delete_course': 'courses',
    'contact_teacher': 'courses',
    'suspend_user': 'users',
    'unsuspend_user': 'users',
    'bulk_suspend': 'users',
    'bulk_unsuspend': 'users',
    'verify_teacher': 'users',
    'reject_teacher': 'users',
    'resolve_moderation': 'moderation',
    'dismiss_moderation': 'moderation',
    'ticket_reply': 'support',
    'ticket_status_change': 'support',
  };

  bool _matchesFilter(String action) {
    if (_filterAction == null) return true;
    final category = _actionCategoryMap[action];
    return category == _filterAction;
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'send_announcement':
        return Icons.campaign_rounded;
      case 'activate_announcement':
        return Icons.toggle_on_rounded;
      case 'deactivate_announcement':
        return Icons.toggle_off_rounded;
      case 'delete_announcement':
        return Icons.delete_rounded;
      case 'update_setting':
      case 'update_settings':
        return Icons.settings_rounded;
      case 'suspend_user':
      case 'bulk_suspend':
        return Icons.block_rounded;
      case 'unsuspend_user':
      case 'bulk_unsuspend':
        return Icons.check_circle_rounded;
      case 'delete_course':
        return Icons.delete_forever_rounded;
      case 'publish_course':
        return Icons.publish_rounded;
      case 'unpublish_course':
        return Icons.unpublished_rounded;
      case 'flag_course':
        return Icons.flag_rounded;
      case 'contact_teacher':
        return Icons.email_rounded;
      case 'verify_teacher':
        return Icons.verified_rounded;
      case 'reject_teacher':
        return Icons.cancel_rounded;
      case 'resolve_moderation':
        return Icons.gavel_rounded;
      case 'dismiss_moderation':
        return Icons.close_rounded;
      case 'ticket_reply':
        return Icons.reply_rounded;
      case 'ticket_status_change':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'send_announcement':
        return Colors.blue;
      case 'activate_announcement':
        return Colors.green;
      case 'deactivate_announcement':
        return Colors.grey;
      case 'delete_announcement':
      case 'delete_course':
        return Colors.red;
      case 'update_setting':
      case 'update_settings':
        return Colors.purple;
      case 'suspend_user':
      case 'bulk_suspend':
        return Colors.red;
      case 'unsuspend_user':
      case 'bulk_unsuspend':
        return Colors.green;
      case 'publish_course':
        return Colors.green;
      case 'unpublish_course':
        return Colors.orange;
      case 'flag_course':
        return Colors.amber;
      case 'contact_teacher':
        return Colors.blue;
      case 'verify_teacher':
        return Colors.teal;
      case 'reject_teacher':
        return Colors.deepOrange;
      case 'resolve_moderation':
        return Colors.indigo;
      case 'dismiss_moderation':
        return Colors.brown;
      case 'ticket_reply':
        return Colors.cyan;
      case 'ticket_status_change':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  /// Pretty-print the action label
  String _getActionLabel(String action) {
    switch (action) {
      case 'send_announcement':
        return 'ANNOUNCEMENT';
      case 'activate_announcement':
        return 'ACTIVATE ANNOUNCEMENT';
      case 'deactivate_announcement':
        return 'DEACTIVATE ANNOUNCEMENT';
      case 'delete_announcement':
        return 'DELETE ANNOUNCEMENT';
      case 'update_setting':
        return 'SETTING CHANGED';
      case 'update_settings':
        return 'SETTINGS UPDATED';
      case 'publish_course':
        return 'PUBLISH COURSE';
      case 'unpublish_course':
        return 'UNPUBLISH COURSE';
      case 'flag_course':
        return 'FLAG COURSE';
      case 'delete_course':
        return 'DELETE COURSE';
      case 'contact_teacher':
        return 'CONTACT TEACHER';
      case 'suspend_user':
        return 'SUSPEND USER';
      case 'unsuspend_user':
        return 'UNSUSPEND USER';
      case 'bulk_suspend':
        return 'BULK SUSPEND';
      case 'bulk_unsuspend':
        return 'BULK UNSUSPEND';
      case 'verify_teacher':
        return 'VERIFY TEACHER';
      case 'reject_teacher':
        return 'REJECT TEACHER';
      case 'resolve_moderation':
        return 'RESOLVE MODERATION';
      case 'dismiss_moderation':
        return 'DISMISS MODERATION';
      case 'ticket_reply':
        return 'TICKET REPLY';
      case 'ticket_status_change':
        return 'TICKET STATUS';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Admin Activity',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('Live',
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Wrapped filter chips (not horizontal scroll)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _filterCategories.map((cat) {
              final catVal = cat['value'] as String?;
              final selected = _filterAction == catVal;
              return FilterChip(
                avatar: Icon(cat['icon'] as IconData,
                    size: 14,
                    color: selected
                        ? Colors.white
                        : AppTheme.getTextSecondary(context)),
                label: Text(cat['label'] as String,
                    style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.white
                            : AppTheme.getTextPrimary(context),
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal)),
                selected: selected,
                selectedColor: accentColor,
                backgroundColor:
                    isDark ? AppTheme.darkCard : Colors.grey.shade100,
                side: BorderSide.none,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                onSelected: (_) => setState(() => _filterAction = catVal),
              );
            }).toList(),
          ),
        ),

        // Activity list
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: _db
                .child('admin_audit_log')
                .orderByChild('timestamp')
                .limitToLast(100)
                .onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData ||
                  snapshot.data?.snapshot.value == null) {
                return _buildEmptyState(isDark);
              }

              final raw = snapshot.data!.snapshot.value as Map;
              final entries = <Map<String, dynamic>>[];

              raw.forEach((key, value) {
                if (value is Map) {
                  final entry = {
                    ...Map<String, dynamic>.from(value),
                    'id': key,
                  };
                  final action = entry['action'] as String? ?? '';
                  if (_matchesFilter(action)) {
                    entries.add(entry);
                  }
                }
              });

              entries.sort((a, b) => ((b['timestamp'] as num?) ?? 0)
                  .compareTo((a['timestamp'] as num?) ?? 0));

              if (entries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_off_rounded,
                          size: 48,
                          color: AppTheme.getTextSecondary(context)
                              .withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('No matching activities',
                          style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () =>
                            setState(() => _filterAction = null),
                        child: const Text('Show all'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: entries.length,
                itemBuilder: (context, index) => _buildLogEntry(
                    entries[index], isDark, index == entries.length - 1),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              size: 64,
              color: AppTheme.getTextSecondary(context).withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No activity entries yet',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context), fontSize: 16)),
          const SizedBox(height: 4),
          Text('Admin actions will appear here in real-time',
              style: TextStyle(
                  color:
                      AppTheme.getTextSecondary(context).withOpacity(0.6),
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildLogEntry(
      Map<String, dynamic> entry, bool isDark, bool isLast) {
    final action = entry['action'] as String? ?? '';
    final details = entry['details'] as String? ?? '';
    final timestamp = entry['timestamp'] as num?;

    final time = timestamp != null
        ? DateFormat('MMM d, h:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()))
        : '';

    final timeAgo =
        timestamp != null ? _getTimeAgo(timestamp.toInt()) : '';
    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);
    final actionLabel = _getActionLabel(action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: Icon(actionIcon, color: actionColor, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: actionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(actionLabel,
                            style: TextStyle(
                                color: actionColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: time,
                        child: Text(timeAgo,
                            style: TextStyle(
                                color: AppTheme.getTextSecondary(context)
                                    .withOpacity(0.6),
                                fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(details,
                      style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(int timestampMs) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}
