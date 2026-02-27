import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Professional Admin Activity Dashboard — real-time audit log with
/// summary statistics, category breakdown, search, date range, and
/// responsive timeline view.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Filters
  String _selectedCategory = 'all';
  String _searchQuery = '';
  String _dateRange = 'all'; // all, today, week, month
  final TextEditingController _searchController = TextEditingController();

  // Category definitions
  static const _categories = <String, _CategoryDef>{
    'all': _CategoryDef('All Activity', Icons.list_rounded, Colors.blueGrey),
    'announcements':
        _CategoryDef('Announcements', Icons.campaign_rounded, Colors.blue),
    'settings':
        _CategoryDef('Settings', Icons.settings_rounded, Colors.purple),
    'courses': _CategoryDef('Courses', Icons.school_rounded, Colors.indigo),
    'users': _CategoryDef('Users', Icons.people_rounded, Colors.teal),
    'moderation':
        _CategoryDef('Moderation', Icons.shield_rounded, Colors.deepOrange),
    'support':
        _CategoryDef('Support', Icons.support_agent_rounded, Colors.cyan),
  };

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(Map<String, dynamic> entry) {
    final action = entry['action'] as String? ?? '';
    final details = (entry['details'] as String? ?? '').toLowerCase();
    final timestamp = (entry['timestamp'] as num?)?.toInt() ?? 0;

    // Category filter
    if (_selectedCategory != 'all') {
      final category = _actionCategoryMap[action];
      if (category != _selectedCategory) return false;
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      if (!details.contains(q) &&
          !action.toLowerCase().contains(q) &&
          !(_getActionLabel(action).toLowerCase().contains(q))) {
        return false;
      }
    }

    // Date range filter
    if (_dateRange != 'all' && timestamp > 0) {
      final now = DateTime.now();
      final entryDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      switch (_dateRange) {
        case 'today':
          final todayStart = DateTime(now.year, now.month, now.day);
          if (entryDate.isBefore(todayStart)) return false;
          break;
        case 'week':
          final weekStart = now.subtract(const Duration(days: 7));
          if (entryDate.isBefore(weekStart)) return false;
          break;
        case 'month':
          final monthStart = DateTime(now.year, now.month - 1, now.day);
          if (entryDate.isBefore(monthStart)) return false;
          break;
      }
    }

    return true;
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
    final cat = _actionCategoryMap[action];
    return _categories[cat]?.color ?? Colors.blueGrey;
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'send_announcement':
        return 'Announcement Sent';
      case 'activate_announcement':
        return 'Announcement Activated';
      case 'deactivate_announcement':
        return 'Announcement Deactivated';
      case 'delete_announcement':
        return 'Announcement Deleted';
      case 'update_setting':
        return 'Setting Changed';
      case 'update_settings':
        return 'Settings Updated';
      case 'publish_course':
        return 'Course Published';
      case 'unpublish_course':
        return 'Course Unpublished';
      case 'flag_course':
        return 'Course Flagged';
      case 'delete_course':
        return 'Course Deleted';
      case 'contact_teacher':
        return 'Teacher Contacted';
      case 'suspend_user':
        return 'User Suspended';
      case 'unsuspend_user':
        return 'User Unsuspended';
      case 'bulk_suspend':
        return 'Bulk Suspend';
      case 'bulk_unsuspend':
        return 'Bulk Unsuspend';
      case 'verify_teacher':
        return 'Teacher Verified';
      case 'reject_teacher':
        return 'Teacher Rejected';
      case 'resolve_moderation':
        return 'Moderation Resolved';
      case 'dismiss_moderation':
        return 'Report Dismissed';
      case 'ticket_reply':
        return 'Ticket Reply';
      case 'ticket_status_change':
        return 'Ticket Status Changed';
      default:
        return action
            .split('_')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
            .join(' ');
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return StreamBuilder<DatabaseEvent>(
      stream: _db
          .child('admin_audit_log')
          .orderByChild('timestamp')
          .limitToLast(200)
          .onValue,
      builder: (context, snapshot) {
        // Parse all entries once
        final allEntries = <Map<String, dynamic>>[];
        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final raw = snapshot.data!.snapshot.value as Map;
          raw.forEach((key, value) {
            if (value is Map) {
              allEntries.add({
                ...Map<String, dynamic>.from(value),
                'id': key,
              });
            }
          });
          allEntries.sort((a, b) => ((b['timestamp'] as num?) ?? 0)
              .compareTo((a['timestamp'] as num?) ?? 0));
        }

        // Compute stats from all entries
        final stats = _computeStats(allEntries);

        // Filter entries for display
        final filtered =
            allEntries.where((e) => _matchesFilter(e)).toList();

        return CustomScrollView(
          slivers: [
            // ─── Header ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppTheme.darkAccent, Colors.deepPurple]
                              : [AppTheme.primaryColor, Colors.deepPurple],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Activity',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextPrimary(context))),
                          Text('Real-time audit log',
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      AppTheme.getTextSecondary(context))),
                        ],
                      ),
                    ),
                    _buildLiveBadge(),
                  ],
                ),
              ),
            ),

            // ─── Summary Stats Row ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildSummaryRow(stats, isDark),
              ),
            ),

            // ─── Category Breakdown ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildCategoryBreakdown(stats, isDark),
              ),
            ),

            // ─── Search + Date Filter ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildSearchAndDateFilter(isDark),
              ),
            ),

            // ─── Activity Count ───
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} activit${filtered.length == 1 ? 'y' : 'ies'}',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_selectedCategory != 'all' ||
                        _searchQuery.isNotEmpty ||
                        _dateRange != 'all') ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'all';
                            _searchQuery = '';
                            _dateRange = 'all';
                            _searchController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Clear filters',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── Activity Timeline ───
            if (snapshot.connectionState == ConnectionState.waiting &&
                allEntries.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(isDark))
            else
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = filtered[index];
                      final isLast = index == filtered.length - 1;
                      // Date separator
                      final showDateHeader =
                          _shouldShowDateHeader(filtered, index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader)
                            _buildDateHeader(entry, isDark),
                          _buildLogEntry(entry, isDark, isLast),
                        ],
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  // ─── Summary Row ───
  Widget _buildSummaryRow(Map<String, dynamic> stats, bool isDark) {
    final today = stats['today'] as int;
    final thisWeek = stats['week'] as int;
    final total = stats['total'] as int;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Today',
            '$today',
            Icons.today_rounded,
            Colors.blue,
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'This Week',
            '$thisWeek',
            Icons.date_range_rounded,
            Colors.green,
            isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Total',
            '$total',
            Icons.analytics_rounded,
            Colors.purple,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 10,
              )),
        ],
      ),
    );
  }

  // ─── Category Breakdown ───
  Widget _buildCategoryBreakdown(Map<String, dynamic> stats, bool isDark) {
    final catCounts = stats['categoryCounts'] as Map<String, int>;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.entries.map((e) {
          final key = e.key;
          final def = e.value;
          final count = key == 'all'
              ? (stats['total'] as int)
              : (catCounts[key] ?? 0);
          final isSelected = _selectedCategory == key;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? def.color.withOpacity(0.15)
                      : isDark
                          ? AppTheme.darkCard
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? def.color.withOpacity(0.5)
                        : isDark
                            ? AppTheme.darkBorderColor
                            : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(def.icon,
                        size: 14,
                        color: isSelected
                            ? def.color
                            : AppTheme.getTextSecondary(context)),
                    const SizedBox(width: 6),
                    Text(
                      def.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? def.color
                            : AppTheme.getTextPrimary(context),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? def.color.withOpacity(0.2)
                            : AppTheme.getTextSecondary(context)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? def.color
                              : AppTheme.getTextSecondary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Search + Date Filter ───
  Widget _buildSearchAndDateFilter(bool isDark) {
    return Column(
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search activities...',
            hintStyle: TextStyle(
              color: AppTheme.getTextSecondary(context).withOpacity(0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(Icons.search,
                size: 20,
                color: AppTheme.getTextSecondary(context).withOpacity(0.5)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close,
                        size: 18,
                        color: AppTheme.getTextSecondary(context)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? AppTheme.darkCard : Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark
                      ? AppTheme.darkBorderColor
                      : Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Date chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDateChip('All Time', 'all', isDark),
              const SizedBox(width: 6),
              _buildDateChip('Today', 'today', isDark),
              const SizedBox(width: 6),
              _buildDateChip('This Week', 'week', isDark),
              const SizedBox(width: 6),
              _buildDateChip('This Month', 'month', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(String label, String value, bool isDark) {
    final isSelected = _dateRange == value;
    final accent = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return GestureDetector(
      onTap: () => setState(() => _dateRange = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withOpacity(0.12)
              : isDark
                  ? AppTheme.darkCard
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: accent.withOpacity(0.4))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? accent : AppTheme.getTextSecondary(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─── Date Headers ───
  bool _shouldShowDateHeader(List<Map<String, dynamic>> entries, int index) {
    if (index == 0) return true;
    final curr = (entries[index]['timestamp'] as num?)?.toInt() ?? 0;
    final prev = (entries[index - 1]['timestamp'] as num?)?.toInt() ?? 0;
    if (curr == 0 || prev == 0) return false;
    final currDate = DateTime.fromMillisecondsSinceEpoch(curr);
    final prevDate = DateTime.fromMillisecondsSinceEpoch(prev);
    return currDate.day != prevDate.day ||
        currDate.month != prevDate.month ||
        currDate.year != prevDate.year;
  }

  Widget _buildDateHeader(Map<String, dynamic> entry, bool isDark) {
    final timestamp = (entry['timestamp'] as num?)?.toInt() ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      label = 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.5,
              )),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Log Entry ───
  Widget _buildLogEntry(
      Map<String, dynamic> entry, bool isDark, bool isLast) {
    final action = entry['action'] as String? ?? '';
    final details = entry['details'] as String? ?? '';
    final timestamp = (entry['timestamp'] as num?)?.toInt() ?? 0;

    final time = timestamp > 0
        ? DateFormat('h:mm a').format(
            DateTime.fromMillisecondsSinceEpoch(timestamp))
        : '';
    final timeAgo = timestamp > 0 ? _getTimeAgo(timestamp) : '';
    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);
    final actionLabel = _getActionLabel(action);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline column
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(actionIcon, color: actionColor, size: 16),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: isDark
                            ? AppTheme.darkBorderColor
                            : Colors.grey.shade200,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Content card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkBorderColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action label + time
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: actionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                color: actionColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: time,
                          child: Text(timeAgo,
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context)
                                    .withOpacity(0.6),
                                fontSize: 11,
                              )),
                        ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(details,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 13,
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ───
  Widget _buildEmptyState(bool isDark) {
    final hasFilters = _selectedCategory != 'all' ||
        _searchQuery.isNotEmpty ||
        _dateRange != 'all';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters
                  ? Icons.filter_list_off_rounded
                  : Icons.history_rounded,
              size: 56,
              color:
                  AppTheme.getTextSecondary(context).withOpacity(0.25),
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'No matching activities'
                  : 'No activity yet',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFilters
                  ? 'Try adjusting your filters'
                  : 'Admin actions will appear here in real-time',
              style: TextStyle(
                color:
                    AppTheme.getTextSecondary(context).withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'all';
                    _searchQuery = '';
                    _dateRange = 'all';
                    _searchController.clear();
                  });
                },
                child: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Live Badge ───
  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text('Live',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  // ─── Stats Computation ───
  Map<String, dynamic> _computeStats(List<Map<String, dynamic>> entries) {
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final weekStart =
        now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

    int todayCount = 0;
    int weekCount = 0;
    final catCounts = <String, int>{};

    for (final entry in entries) {
      final ts = (entry['timestamp'] as num?)?.toInt() ?? 0;
      final action = entry['action'] as String? ?? '';
      final cat = _actionCategoryMap[action] ?? 'other';

      catCounts[cat] = (catCounts[cat] ?? 0) + 1;

      if (ts >= todayStart) todayCount++;
      if (ts >= weekStart) weekCount++;
    }

    return {
      'today': todayCount,
      'week': weekCount,
      'total': entries.length,
      'categoryCounts': catCounts,
    };
  }
}

/// Category definition helper
class _CategoryDef {
  final String label;
  final IconData icon;
  final Color color;

  const _CategoryDef(this.label, this.icon, this.color);
}
