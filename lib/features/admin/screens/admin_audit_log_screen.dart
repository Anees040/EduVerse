import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/features/admin/services/admin_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin screen showing all admin actions in a chronological audit trail.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final _service = AdminFeatureService();
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _filterAction;

  static const _actionFilters = [
    null,
    'send_announcement',
    'update_setting',
    'bulk_suspend',
    'bulk_unsuspend',
    'delete_announcement',
    'update_settings',
  ];

  static const _actionLabels = {
    null: 'All Actions',
    'send_announcement': 'Announcements',
    'update_setting': 'Settings',
    'bulk_suspend': 'Suspensions',
    'bulk_unsuspend': 'Unsuspensions',
    'delete_announcement': 'Deletions',
    'update_settings': 'Bulk Settings',
  };

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() => _isLoading = true);
    final data = await _service.getAuditLog(
      limit: 100,
      filterAction: _filterAction,
    );
    if (mounted) {
      setState(() {
        _entries = data;
        _isLoading = false;
      });
    }
  }

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
        return Icons.block;
      case 'bulk_unsuspend':
        return Icons.check_circle;
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
        return Colors.red;
      case 'update_setting':
      case 'update_settings':
        return Colors.purple;
      case 'bulk_suspend':
        return Colors.red;
      case 'bulk_unsuspend':
        return Colors.green;
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
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Activity Audit Log',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
              ),
              Text(
                '${_entries.length} entries',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Filter chips
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
                        fontSize: 12,
                        color: selected
                            ? Colors.white
                            : AppTheme.getTextSecondary(context),
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    selectedColor: accentColor,
                    backgroundColor: isDark
                        ? AppTheme.darkCard
                        : Colors.grey.shade100,
                    side: BorderSide.none,
                    onSelected: (_) {
                      setState(() => _filterAction = filter);
                      _loadLog();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Log entries
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: AppTheme.getTextSecondary(context)
                                .withOpacity(0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No audit entries yet',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLog,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          return _buildLogEntry(
                            _entries[index],
                            isDark,
                            index == _entries.length - 1,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(
    Map<String, dynamic> entry,
    bool isDark,
    bool isLast,
  ) {
    final action = entry['action'] as String? ?? '';
    final details = entry['details'] as String? ?? '';
    final timestamp = entry['timestamp'] as num?;
    final adminUid = entry['adminUid'] as String? ?? '';

    final time = timestamp != null
        ? DateFormat('MMM d, h:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()))
        : '';

    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);

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

          // Content
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
                      Text(
                        time,
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context)
                              .withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 14,
                    ),
                  ),
                  if (adminUid.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'By: ${adminUid.substring(0, adminUid.length > 8 ? 8 : adminUid.length)}...',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context)
                            .withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
