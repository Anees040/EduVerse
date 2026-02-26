import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin Activity screen - live real-time feed of all admin actions.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  String? _filterAction;

  static const _actionFilters = <String?>[
    null,
    'send_announcement',
    'update_setting',
    'update_settings',
    'delete_announcement',
    'delete_course',
    'suspend_user',
    'unsuspend_user',
    'verify_teacher',
    'reject_teacher',
    'resolve_moderation',
    'dismiss_moderation',
    'ticket_reply',
    'ticket_status_change',
  ];

  static const _actionLabels = <String?, String>{
    null: 'All',
    'send_announcement': 'Announcements',
    'update_setting': 'Setting Change',
    'update_settings': 'Settings Batch',
    'delete_announcement': 'Delete Announce',
    'delete_course': 'Course Deletion',
    'suspend_user': 'Suspend',
    'unsuspend_user': 'Unsuspend',
    'verify_teacher': 'Verify Teacher',
    'reject_teacher': 'Reject Teacher',
    'resolve_moderation': 'Resolve Mod',
    'dismiss_moderation': 'Dismiss Mod',
    'ticket_reply': 'Ticket Reply',
    'ticket_status_change': 'Ticket Status',
  };

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'send_announcement':
        return Icons.campaign;
      case 'activate_announcement':
        return Icons.toggle_on;
      case 'deactivate_announcement':
        return Icons.toggle_off;
      case 'delete_announcement':
        return Icons.delete;
      case 'update_setting':
      case 'update_settings':
        return Icons.settings;
      case 'bulk_suspend':
      case 'suspend_user':
        return Icons.block;
      case 'bulk_unsuspend':
      case 'unsuspend_user':
        return Icons.check_circle;
      case 'delete_course':
        return Icons.delete_forever;
      case 'verify_teacher':
        return Icons.verified;
      case 'reject_teacher':
        return Icons.cancel;
      case 'resolve_moderation':
        return Icons.gavel;
      case 'dismiss_moderation':
        return Icons.close;
      case 'ticket_reply':
        return Icons.reply;
      case 'ticket_status_change':
        return Icons.swap_horiz;
      default:
        return Icons.history;
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
      case 'bulk_suspend':
      case 'suspend_user':
        return Colors.red;
      case 'bulk_unsuspend':
      case 'unsuspend_user':
        return Colors.green;
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Admin Activity',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _actionFilters.map((filter) {
                final selected = _filterAction == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      _actionLabels[filter] ?? 'All',
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.white
                            : AppTheme.getTextSecondary(context),
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    selectedColor: accentColor,
                    backgroundColor:
                        isDark ? AppTheme.darkCard : Colors.grey.shade100,
                    side: BorderSide.none,
                    onSelected: (_) {
                      setState(() => _filterAction = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

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
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64,
                          color: AppTheme.getTextSecondary(context)
                              .withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text('No activity entries yet',
                          style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Admin actions will appear here in real-time',
                          style: TextStyle(
                              color: AppTheme.getTextSecondary(context)
                                  .withOpacity(0.6),
                              fontSize: 13)),
                    ],
                  ),
                );
              }

              final raw = snapshot.data!.snapshot.value as Map;
              final entries = <Map<String, dynamic>>[];

              raw.forEach((key, value) {
                if (value is Map) {
                  final entry = {
                    ...Map<String, dynamic>.from(value),
                    'id': key
                  };
                  if (_filterAction == null ||
                      entry['action'] == _filterAction) {
                    entries.add(entry);
                  }
                }
              });

              entries.sort((a, b) => ((b['timestamp'] as num?) ?? 0)
                  .compareTo((a['timestamp'] as num?) ?? 0));

              if (entries.isEmpty) {
                return Center(
                  child: Text('No matching activities',
                      style: TextStyle(
                          color: AppTheme.getTextSecondary(context))),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return _buildLogEntry(
                      entries[index], isDark, index == entries.length - 1);
                },
              );
            },
          ),
        ),
      ],
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

    final timeAgo = timestamp != null ? _getTimeAgo(timestamp.toInt()) : '';
    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
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
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
                ),
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
                        child: Text(
                          action.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: actionColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
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
