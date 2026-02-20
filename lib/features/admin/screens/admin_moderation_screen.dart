import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../providers/admin_provider.dart';

/// Admin Moderation Screen - Enhanced Content Moderation Queue
/// Features: 3-dot menu actions, resolved/pending tabs, name resolution,
/// warn reporter, view user profiles, clean UI
class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Filter and sort state
  String _selectedFilter = 'all';
  String _selectedSort = 'newest';
  String _searchQuery = '';

  // Name cache to avoid repeated lookups
  final Map<String, String> _nameCache = {};
  // Role cache
  final Map<String, String> _roleCache = {};

  // Tabs: Pending vs Resolved
  late TabController _tabController;

  // Resolved items (kept/dismissed reports)
  List<Map<String, dynamic>> _resolvedItems = [];

  // Resolved tab filters
  String _resolvedActionFilter = 'all'; // all, kept, warned, deleted
  DateTime? _resolvedDateFrom;
  DateTime? _resolvedDateTo;

  // Bulk selection
  final Set<String> _selectedItems = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      if (provider.state.reportedContent.isEmpty) {
        provider.loadFlaggedContent();
      }
      _loadResolvedItems();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load resolved/checked moderation items
  Future<void> _loadResolvedItems() async {
    try {
      final snap = await _db.child('moderation_resolved').get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final items = <Map<String, dynamic>>[];
        for (var entry in data.entries) {
          items.add({
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          });
        }
        items.sort((a, b) {
          final aTime = a['resolvedAt'] ?? a['createdAt'] ?? 0;
          final bTime = b['resolvedAt'] ?? b['createdAt'] ?? 0;
          return (bTime as int).compareTo(aTime as int);
        });
        if (mounted) setState(() => _resolvedItems = items);
      }
    } catch (e) {
      debugPrint('Error loading resolved items: $e');
    }
  }

  /// Resolve user ID to name
  Future<String> _resolveUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'Unknown User';

    if (_nameCache.containsKey(userId)) {
      return _nameCache[userId]!;
    }

    try {
      // Check students
      final studentSnap = await _db
          .child('student')
          .child(userId)
          .child('name')
          .get();
      if (studentSnap.exists && studentSnap.value != null) {
        final name = studentSnap.value.toString();
        _nameCache[userId] = name;
        _roleCache[userId] = 'student';
        return name;
      }

      // Check teachers
      final teacherSnap = await _db
          .child('teacher')
          .child(userId)
          .child('name')
          .get();
      if (teacherSnap.exists && teacherSnap.value != null) {
        final name = teacherSnap.value.toString();
        _nameCache[userId] = name;
        _roleCache[userId] = 'teacher';
        return name;
      }

      final truncated = userId.length > 8
          ? 'User ${userId.substring(0, 8)}...'
          : userId;
      _nameCache[userId] = truncated;
      return truncated;
    } catch (e) {
      return userId.length > 8 ? 'User ${userId.substring(0, 8)}...' : userId;
    }
  }

  /// Resolve user role
  Future<String> _resolveUserRole(String? userId) async {
    if (userId == null || userId.isEmpty) return 'unknown';
    if (_roleCache.containsKey(userId)) return _roleCache[userId]!;
    await _resolveUserName(userId); // populates role cache too
    return _roleCache[userId] ?? 'unknown';
  }

  /// Filter and sort items
  List<Map<String, dynamic>> _getFilteredItems(
    List<Map<String, dynamic>> items,
  ) {
    var filtered = items.where((item) {
      if (_selectedFilter != 'all') {
        final type = (item['type'] ?? '').toString().toLowerCase();
        if (type != _selectedFilter.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final content =
            (item['content'] ?? item['text'] ?? item['comment'] ?? '')
                .toString()
                .toLowerCase();
        final reason = (item['reportReason'] ?? '').toString().toLowerCase();
        final authorName = (item['contentAuthorName'] ?? '')
            .toString()
            .toLowerCase();
        final reporterName = (item['reporterName'] ?? '')
            .toString()
            .toLowerCase();
        if (!content.contains(_searchQuery.toLowerCase()) &&
            !reason.contains(_searchQuery.toLowerCase()) &&
            !authorName.contains(_searchQuery.toLowerCase()) &&
            !reporterName.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aTime = a['reportedAt'] ?? a['createdAt'] ?? 0;
      final bTime = b['reportedAt'] ?? b['createdAt'] ?? 0;

      switch (_selectedSort) {
        case 'oldest':
          return (aTime as int).compareTo(bTime as int);
        case 'priority':
          final aPriority = _getPriority(a['reportReason'] ?? '');
          final bPriority = _getPriority(b['reportReason'] ?? '');
          if (aPriority != bPriority) return bPriority.compareTo(aPriority);
          return (bTime as int).compareTo(aTime as int);
        default:
          return (bTime as int).compareTo(aTime as int);
      }
    });

    return filtered;
  }

  int _getPriority(String reason) {
    final lr = reason.toLowerCase();
    if (lr.contains('spam') || lr.contains('harassment')) return 3;
    if (lr.contains('inappropriate') || lr.contains('offensive')) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        final allItems = provider.state.reportedContent;
        final filteredItems = _getFilteredItems(allItems);

        return Scaffold(
          backgroundColor: AppTheme.getBackgroundColor(context),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(allItems.length, filteredItems.length, isDark),
                const SizedBox(height: 16),
                _buildFiltersAndSearch(isDark),
                const SizedBox(height: 12),
                // Tabs: Pending / Resolved
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: isDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.getTextSecondary(context),
                    indicatorColor: isDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pending_actions, size: 18),
                            const SizedBox(width: 6),
                            const Text('Pending'),
                            if (allItems.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${allItems.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 18),
                            const SizedBox(width: 6),
                            const Text('Resolved'),
                            if (_resolvedItems.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_resolvedItems.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_isSelectionMode && _selectedItems.isNotEmpty)
                  _buildBulkActionsBar(provider, isDark),
                // Tab views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Pending tab
                      filteredItems.isEmpty
                          ? _buildEmptyState(isDark, allItems.isEmpty)
                          : RefreshIndicator(
                              onRefresh: () =>
                                  provider.loadFlaggedContent(refresh: true),
                              child: ListView.builder(
                                itemCount: filteredItems.length,
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  return _buildModerationCard(
                                    item,
                                    provider,
                                    isDark,
                                  );
                                },
                              ),
                            ),
                      // Resolved tab
                      _buildResolvedTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: allItems.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) _selectedItems.clear();
                    });
                  },
                  backgroundColor: _isSelectionMode
                      ? Colors.grey
                      : (isDark ? AppTheme.darkAccent : AppTheme.primaryColor),
                  icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
                  label: Text(_isSelectionMode ? 'Cancel' : 'Bulk Select'),
                )
              : null,
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────
  // UI Building Widgets
  // ───────────────────────────────────────────────────────────────

  Widget _buildHeader(int total, int filtered, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Content Moderation',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review and moderate reported content',
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildStatBadge(total, 'Pending', Colors.orange, isDark),
            const SizedBox(width: 8),
            _buildStatBadge(
              filtered,
              'Showing',
              isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBadge(int count, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFiltersAndSearch(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search content, reason, or user name...',
              hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
              prefixIcon: Icon(
                Icons.search,
                color: AppTheme.getTextSecondary(context),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'All',
                        'all',
                        Icons.all_inclusive,
                        isDark,
                      ),
                      _buildFilterChip(
                        'Q&A',
                        'qa',
                        Icons.question_answer,
                        isDark,
                      ),
                      _buildFilterChip('Reviews', 'review', Icons.star, isDark),
                      _buildFilterChip(
                        'Comments',
                        'comment',
                        Icons.comment,
                        isDark,
                      ),
                      _buildFilterChip(
                        'Videos',
                        'video',
                        Icons.video_library,
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedSort,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                  icon: Icon(
                    Icons.sort,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'newest',
                      child: Text(
                        'Newest',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'oldest',
                      child: Text(
                        'Oldest',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'priority',
                      child: Text(
                        'Priority',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedSort = value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : AppTheme.getTextSecondary(context),
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedFilter = value),
        backgroundColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
        selectedColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.getTextPrimary(context),
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildBulkActionsBar(AdminProvider provider, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedItems.length} selected',
            style: TextStyle(
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _bulkAction(provider, 'keep'),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Keep All'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _bulkAction(provider, 'delete'),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete All'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool noReports, {String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (noReports ? Colors.green : Colors.orange).withValues(
                alpha: 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              noReports ? Icons.check_circle : Icons.filter_list,
              size: 64,
              color: noReports ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message ?? (noReports ? 'All Clear!' : 'No Results'),
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noReports
                ? 'No reported content to review'
                : 'Try adjusting your filters',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
          if (!noReports)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _selectedFilter = 'all';
                  _searchQuery = '';
                }),
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Resolved Tab with Filters
  // ───────────────────────────────────────────────────────────────

  /// Filter resolved items based on action type and date range
  List<Map<String, dynamic>> _getFilteredResolvedItems() {
    return _resolvedItems.where((item) {
      // Action type filter
      if (_resolvedActionFilter != 'all') {
        final action = (item['action'] ?? 'kept').toString();
        if (action != _resolvedActionFilter) return false;
      }
      // Date range filter
      final resolvedAt = item['resolvedAt'] ?? item['createdAt'] ?? 0;
      if (resolvedAt is int && resolvedAt > 0) {
        final date = DateTime.fromMillisecondsSinceEpoch(resolvedAt);
        if (_resolvedDateFrom != null && date.isBefore(_resolvedDateFrom!)) {
          return false;
        }
        if (_resolvedDateTo != null &&
            date.isAfter(
              _resolvedDateTo!
                  .add(const Duration(days: 1))
                  .subtract(const Duration(seconds: 1)),
            )) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildResolvedTab(bool isDark) {
    final filteredResolved = _getFilteredResolvedItems();

    return Column(
      children: [
        // Resolved filters bar
        _buildResolvedFilters(isDark),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: filteredResolved.isEmpty
              ? _buildEmptyState(
                  isDark,
                  _resolvedItems.isEmpty,
                  message: _resolvedItems.isEmpty
                      ? 'No resolved reports yet'
                      : 'No results match your filters',
                )
              : RefreshIndicator(
                  onRefresh: () async => await _loadResolvedItems(),
                  child: ListView.builder(
                    itemCount: filteredResolved.length,
                    itemBuilder: (context, index) {
                      final item = filteredResolved[index];
                      return _buildResolvedCard(item, isDark);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildResolvedFilters(bool isDark) {
    final hasDateFilter = _resolvedDateFrom != null || _resolvedDateTo != null;
    final hasAnyFilter = _resolvedActionFilter != 'all' || hasDateFilter;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Action type filter chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildResolvedFilterChip(
                        'All',
                        'all',
                        Icons.all_inclusive,
                        null,
                        isDark,
                      ),
                      _buildResolvedFilterChip(
                        'Kept',
                        'kept',
                        Icons.check_circle,
                        Colors.green,
                        isDark,
                      ),
                      _buildResolvedFilterChip(
                        'Warned',
                        'warned',
                        Icons.warning,
                        Colors.orange,
                        isDark,
                      ),
                      _buildResolvedFilterChip(
                        'Deleted',
                        'deleted',
                        Icons.delete,
                        Colors.red,
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date range picker
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showDateRangePicker(isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasDateFilter
                        ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                              .withOpacity(0.1)
                        : (isDark
                              ? AppTheme.darkElevated
                              : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasDateFilter
                          ? (isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 16,
                        color: hasDateFilter
                            ? (isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor)
                            : AppTheme.getTextSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasDateFilter ? _formatDateRange() : 'Date',
                        style: TextStyle(
                          color: hasDateFilter
                              ? (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                              : AppTheme.getTextSecondary(context),
                          fontSize: 12,
                          fontWeight: hasDateFilter
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Show active filter summary + clear button
          if (hasAnyFilter) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 14,
                  color: AppTheme.getTextSecondary(context),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_getFilteredResolvedItems().length} of ${_resolvedItems.length} items',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() {
                    _resolvedActionFilter = 'all';
                    _resolvedDateFrom = null;
                    _resolvedDateTo = null;
                  }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Clear Filters',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResolvedFilterChip(
    String label,
    String value,
    IconData icon,
    Color? color,
    bool isDark,
  ) {
    final isSelected = _resolvedActionFilter == value;
    final chipColor =
        color ?? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : chipColor),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => setState(() => _resolvedActionFilter = value),
        backgroundColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
        selectedColor: chipColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.getTextPrimary(context),
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showDateRangePicker(bool isDark) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _resolvedDateFrom != null
          ? DateTimeRange(
              start: _resolvedDateFrom!,
              end: _resolvedDateTo ?? now,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primaryColor,
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _resolvedDateFrom = picked.start;
        _resolvedDateTo = picked.end;
      });
    }
  }

  String _formatDateRange() {
    final df = DateFormat('MMM d');
    if (_resolvedDateFrom != null && _resolvedDateTo != null) {
      return '${df.format(_resolvedDateFrom!)} - ${df.format(_resolvedDateTo!)}';
    } else if (_resolvedDateFrom != null) {
      return 'From ${df.format(_resolvedDateFrom!)}';
    } else if (_resolvedDateTo != null) {
      return 'To ${df.format(_resolvedDateTo!)}';
    }
    return 'Date';
  }

  // ───────────────────────────────────────────────────────────────
  // Moderation Card (Pending)
  // ───────────────────────────────────────────────────────────────

  Widget _buildModerationCard(
    Map<String, dynamic> item,
    AdminProvider provider,
    bool isDark,
  ) {
    final type = item['type'] ?? 'unknown';
    final content =
        item['content'] ?? item['text'] ?? item['comment'] ?? 'No content';
    final reportReason = item['reportReason'] ?? 'Policy violation';
    final reportedBy = item['reportedBy'];
    final reportedUserId =
        item['reportedUserId'] ?? item['userId'] ?? item['authorId'];
    final contentId =
        item['originalId'] ?? item['contentId'] ?? item['id'] ?? '';
    final parentId = item['courseId'] ?? item['teacherId'];
    final reportedAt = item['reportedAt'] ?? item['createdAt'];
    final isSelected = _selectedItems.contains(item['id']);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedItems.add(item['id']);
          });
        }
      },
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedItems.remove(item['id']);
                } else {
                  _selectedItems.add(item['id']);
                }
              });
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getPriorityColor(reportReason).withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedItems.add(item['id']);
                            } else {
                              _selectedItems.remove(item['id']);
                            }
                          });
                        },
                        activeColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                  _buildTypeBadge(type, isDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reported for:',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          reportReason,
                          style: TextStyle(
                            color: _getPriorityColor(reportReason),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reportedAt != null && reportedAt is int)
                    Text(
                      _formatTime(reportedAt),
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(width: 4),
                  // 3-dot menu replaces the action buttons
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.getTextSecondary(context),
                    ),
                    onSelected: (action) => _handleModerationAction(
                      action,
                      item,
                      contentId,
                      type,
                      parentId,
                      provider,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    itemBuilder: (context) => [
                      _buildPopupItem(
                        'keep',
                        'Keep Content',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      _buildPopupItem(
                        'warn_author',
                        'Warn Author',
                        Icons.warning_amber_rounded,
                        Colors.orange,
                      ),
                      _buildPopupItem(
                        'warn_reporter',
                        'Warn Reporter',
                        Icons.report_gmailerrorred,
                        Colors.deepOrange,
                      ),
                      const PopupMenuDivider(),
                      _buildPopupItem(
                        'view_reporter',
                        'View Reporter Profile',
                        Icons.person_search,
                        Colors.blue,
                      ),
                      _buildPopupItem(
                        'view_author',
                        'View Author Profile',
                        Icons.person,
                        Colors.purple,
                      ),
                      const PopupMenuDivider(),
                      _buildPopupItem(
                        'suspend_author',
                        'Suspend Author',
                        Icons.block,
                        Colors.red.shade700,
                      ),
                      _buildPopupItem(
                        'delete',
                        'Delete Content',
                        Icons.delete_forever,
                        Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content preview
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackground.withValues(alpha: 0.5)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  content.toString(),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Reporter & Author info row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildUserChip(
                      'Reported by',
                      reportedBy,
                      Icons.flag_outlined,
                      Colors.orange,
                      isDark,
                      onTap: () => _viewUserProfile(reportedBy, isDark),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildUserChip(
                      'Content Author',
                      reportedUserId,
                      Icons.person_outline,
                      Colors.blue,
                      isDark,
                      onTap: () => _viewUserProfile(reportedUserId, isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Resolved Card
  // ───────────────────────────────────────────────────────────────

  Widget _buildResolvedCard(Map<String, dynamic> item, bool isDark) {
    final action = item['action'] ?? 'kept';
    final content = item['content'] ?? item['text'] ?? 'No content';
    final reportReason = item['reportReason'] ?? 'Policy violation';
    final resolvedAt = item['resolvedAt'];
    final type = item['type'] ?? 'unknown';
    final reportedBy = item['reportedBy'];
    final reportedUserId = item['reportedUserId'];

    Color actionColor;
    IconData actionIcon;
    String actionLabel;
    switch (action) {
      case 'deleted':
        actionColor = Colors.red;
        actionIcon = Icons.delete;
        actionLabel = 'Deleted';
        break;
      case 'warned':
        actionColor = Colors.orange;
        actionIcon = Icons.warning;
        actionLabel = 'Warned';
        break;
      default:
        actionColor = Colors.green;
        actionIcon = Icons.check_circle;
        actionLabel = 'Kept';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with action badge - type - time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(actionIcon, color: actionColor, size: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    actionLabel,
                    style: TextStyle(
                      color: actionColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildTypeBadge(type, isDark),
                const Spacer(),
                if (resolvedAt != null && resolvedAt is int)
                  Text(
                    _formatTime(resolvedAt),
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Content + reason
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason: $reportReason',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  content.toString(),
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Reporter & Author row
          if (reportedBy != null || reportedUserId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Row(
                children: [
                  if (reportedBy != null) ...[
                    Icon(
                      Icons.flag_outlined,
                      size: 12,
                      color: AppTheme.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    FutureBuilder<String>(
                      future: _resolveUserName(reportedBy),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? '...',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ],
                  if (reportedBy != null && reportedUserId != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  if (reportedUserId != null) ...[
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: AppTheme.getTextSecondary(context),
                    ),
                    const SizedBox(width: 4),
                    FutureBuilder<String>(
                      future: _resolveUserName(reportedUserId),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? '...',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Helper Widgets
  // ───────────────────────────────────────────────────────────────

  Widget _buildTypeBadge(String type, bool isDark) {
    final color = _getTypeColor(type, isDark);
    final icon = _getTypeIcon(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            type.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserChip(
    String label,
    String? userId,
    IconData icon,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return FutureBuilder<String>(
      future: _resolveUserName(userId),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'Loading...';

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        name,
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppTheme.getTextSecondary(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Color _getPriorityColor(String reason) {
    final lr = reason.toLowerCase();
    if (lr.contains('spam') || lr.contains('harassment')) return Colors.red;
    if (lr.contains('inappropriate') || lr.contains('offensive')) {
      return Colors.orange;
    }
    return Colors.amber.shade700;
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'qa':
        return Colors.purple;
      case 'review':
      case 'course_review':
        return Colors.amber;
      case 'comment':
        return Colors.blue;
      case 'video':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'qa':
        return Icons.question_answer;
      case 'review':
      case 'course_review':
        return Icons.star;
      case 'comment':
        return Icons.comment;
      case 'video':
        return Icons.video_library;
      default:
        return Icons.article;
    }
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
      return DateFormat('MMM d').format(date);
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Action Handlers
  // ───────────────────────────────────────────────────────────────

  void _handleModerationAction(
    String action,
    Map<String, dynamic> item,
    String contentId,
    String type,
    String? parentId,
    AdminProvider provider,
  ) {
    final isDark = AppTheme.isDarkMode(context);
    switch (action) {
      case 'keep':
        _keepContent(item, contentId, type, parentId, provider);
        break;
      case 'warn_author':
        _showWarnDialog(
          item,
          item['reportedUserId'] ?? item['userId'] ?? item['authorId'],
          'Content Author',
          isDark,
        );
        break;
      case 'warn_reporter':
        _showWarnDialog(item, item['reportedBy'], 'Reporter', isDark);
        break;
      case 'view_reporter':
        _viewUserProfile(item['reportedBy'], isDark);
        break;
      case 'view_author':
        _viewUserProfile(
          item['reportedUserId'] ?? item['userId'] ?? item['authorId'],
          isDark,
        );
        break;
      case 'suspend_author':
        _showSuspendUserDialog(item, isDark);
        break;
      case 'delete':
        _deleteContent(item, contentId, type, parentId, provider);
        break;
    }
  }

  /// Keep content: dismiss report, move to resolved
  void _keepContent(
    Map<String, dynamic> item,
    String contentId,
    String type,
    String? parentId,
    AdminProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Text(
              'Dismiss Report',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: Text(
          'Keep this content and mark the report as reviewed. The content will remain visible.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              // Move to resolved
              await _moveToResolved(item, 'kept');
              // Approve in provider (clears flags, removes from pending)
              provider.moderateContent(
                contentId: contentId,
                contentType: type,
                approve: true,
                parentId: parentId,
              );
              // Also clear from moderation queue
              await _removeFromModerationQueue(item['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report dismissed - content kept'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Keep Content'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  /// Delete content: permanently remove from DB and move report to resolved
  void _deleteContent(
    Map<String, dynamic> item,
    String contentId,
    String type,
    String? parentId,
    AdminProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete Content',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete the content. The author and other users will no longer see it. This cannot be undone.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              // Move to resolved
              await _moveToResolved(item, 'deleted');
              // Delete content via provider
              provider.moderateContent(
                contentId: contentId,
                contentType: type,
                approve: false,
                parentId: parentId,
              );
              // Also clear from moderation queue
              await _removeFromModerationQueue(item['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Content deleted permanently'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  /// Show warn dialog for any user (author or reporter)
  void _showWarnDialog(
    Map<String, dynamic> item,
    String? userId,
    String userLabel,
    bool isDark,
  ) {
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User ID not available')));
      return;
    }

    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Warn $userLabel',
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _resolveUserName(userId),
              builder: (context, snapshot) {
                return Text(
                  'Send a warning to: ${snapshot.data ?? 'Loading...'}',
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Warning reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: isDark
                    ? AppTheme.darkElevated
                    : Colors.grey.shade100,
              ),
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);

              final warningMessage = reasonController.text.isNotEmpty
                  ? reasonController.text
                  : 'Your activity has been flagged for violating community guidelines. Please review our policies.';

              // Save warning
              await _db.child('warnings').child(userId).push().set({
                'reason': warningMessage,
                'contentType': item['type'],
                'contentId': item['id'],
                'warnedAt': ServerValue.timestamp,
                'warnedUser': userLabel,
              });

              // Send notification to the warned user
              await _db.child('notifications').child(userId).push().set({
                'title': 'Warning: Community Guidelines',
                'message': warningMessage,
                'type': 'warning',
                'createdAt': ServerValue.timestamp,
                'isRead': false,
              });

              // Increment warning count on user profile
              final role = await _resolveUserRole(userId);
              if (role != 'unknown') {
                final countSnap = await _db
                    .child(role)
                    .child(userId)
                    .child('warningCount')
                    .get();
                final current = (countSnap.value ?? 0) as int;
                await _db.child(role).child(userId).update({
                  'warningCount': current + 1,
                });
              }

              // If warning author, also move item to resolved
              if (userLabel == 'Content Author') {
                await _moveToResolved(item, 'warned');
                // Remove from pending list visually
                final provider = Provider.of<AdminProvider>(
                  context,
                  listen: false,
                );
                provider.moderateContent(
                  contentId:
                      item['originalId'] ??
                      item['contentId'] ??
                      item['id'] ??
                      '',
                  contentType: item['type'] ?? 'unknown',
                  approve: true,
                  parentId: item['courseId'] ?? item['teacherId'],
                );
                await _removeFromModerationQueue(item['id']);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Warning sent to $userLabel'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send Warning'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  /// View user profile in a detailed dialog
  void _viewUserProfile(String? userId, bool isDark) {
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User ID not available')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );

    _fetchUserProfile(userId).then((profileData) {
      if (!mounted) return;
      Navigator.pop(context); // close loading

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                              .withValues(alpha: 0.15),
                      backgroundImage: profileData['photoUrl'] != null
                          ? NetworkImage(profileData['photoUrl'])
                          : null,
                      child: profileData['photoUrl'] == null
                          ? Text(
                              (profileData['name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profileData['name'] ?? 'Unknown User',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (profileData['headline'] != null)
                      Text(
                        profileData['headline'],
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: profileData['role'] == 'teacher'
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (profileData['role'] ?? 'user').toUpperCase(),
                        style: TextStyle(
                          color: profileData['role'] == 'teacher'
                              ? Colors.blue
                              : Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Profile details
                    _buildProfileRow(
                      'Email',
                      profileData['email'] ?? '-',
                      isDark,
                    ),
                    if (profileData['isSuspended'] == true)
                      _buildProfileRow(
                        'Status',
                        'SUSPENDED',
                        isDark,
                        valueColor: Colors.red,
                      ),
                    if (profileData['isVerified'] == true)
                      _buildProfileRow(
                        'Verified',
                        'Yes',
                        isDark,
                        valueColor: Colors.green,
                      ),
                    if (profileData['bio'] != null &&
                        profileData['bio'].toString().isNotEmpty)
                      _buildProfileRow('Bio', profileData['bio'], isDark),
                    if (profileData['subject'] != null)
                      _buildProfileRow(
                        'Subject',
                        profileData['subject'],
                        isDark,
                      ),
                    if (profileData['experience'] != null)
                      _buildProfileRow(
                        'Experience',
                        '${profileData['experience']} years',
                        isDark,
                      ),
                    _buildProfileRow(
                      'Warning Count',
                      '${profileData['warningCount'] ?? 0}',
                      isDark,
                      valueColor: (profileData['warningCount'] ?? 0) > 0
                          ? Colors.orange
                          : null,
                    ),
                    _buildProfileRow(
                      'Joined',
                      profileData['createdAt'] != null
                          ? DateFormat('MMM dd, yyyy').format(
                              DateTime.fromMillisecondsSinceEpoch(
                                profileData['createdAt'],
                              ),
                            )
                          : 'Unknown',
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildProfileRow(
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.getTextPrimary(context),
                fontSize: 13,
                fontWeight: valueColor != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fetch full user profile from database
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    try {
      // Try student first
      final studentSnap = await _db.child('student').child(userId).get();
      if (studentSnap.exists && studentSnap.value != null) {
        final data = Map<String, dynamic>.from(studentSnap.value as Map);
        data['role'] = 'student';
        return data;
      }
      // Try teacher
      final teacherSnap = await _db.child('teacher').child(userId).get();
      if (teacherSnap.exists && teacherSnap.value != null) {
        final data = Map<String, dynamic>.from(teacherSnap.value as Map);
        data['role'] = 'teacher';
        return data;
      }
      return {'name': 'Unknown User', 'role': 'unknown'};
    } catch (e) {
      return {'name': 'Error loading profile', 'role': 'unknown'};
    }
  }

  /// Suspend user dialog
  void _showSuspendUserDialog(Map<String, dynamic> item, bool isDark) {
    final userId = item['reportedUserId'] ?? item['userId'] ?? item['authorId'];

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User ID not available')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Suspend User',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: FutureBuilder<String>(
          future: _resolveUserName(userId),
          builder: (context, snapshot) {
            return Text(
              'Suspend "${snapshot.data ?? 'user'}"? They will not be able to access the platform until reinstated.',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.child('student').child(userId).update({
                'isSuspended': true,
              });
              await _db.child('teacher').child(userId).update({
                'isSuspended': true,
              });
              // Send notification
              await _db.child('notifications').child(userId).push().set({
                'title': 'Account Suspended',
                'message':
                    'Your account has been suspended for violating community guidelines. Contact support for more information.',
                'type': 'account_update',
                'createdAt': ServerValue.timestamp,
                'isRead': false,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User suspended'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Suspend'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Database Helpers
  // ───────────────────────────────────────────────────────────────

  /// Move item to resolved collection
  Future<void> _moveToResolved(Map<String, dynamic> item, String action) async {
    try {
      await _db.child('moderation_resolved').push().set({
        'originalId': item['id'],
        'type': item['type'] ?? 'unknown',
        'content': item['content'] ?? item['text'] ?? item['comment'] ?? '',
        'reportReason': item['reportReason'] ?? 'Policy violation',
        'reportedBy': item['reportedBy'],
        'reportedUserId':
            item['reportedUserId'] ?? item['userId'] ?? item['authorId'],
        'courseId': item['courseId'],
        'teacherId': item['teacherId'],
        'action': action,
        'resolvedAt': ServerValue.timestamp,
        'createdAt': item['reportedAt'] ?? item['createdAt'],
      });
      await _loadResolvedItems();
    } catch (e) {
      debugPrint('Error moving to resolved: $e');
    }
  }

  /// Remove item from moderation queue and flagged_content
  Future<void> _removeFromModerationQueue(String? itemId) async {
    if (itemId == null) return;
    try {
      await _db.child('moderation').child(itemId).remove();
      await _db.child('flagged_content').child(itemId).remove();
      await _db.child('content_reports').child(itemId).remove();
    } catch (e) {
      debugPrint('Error removing from moderation queue: $e');
    }
  }

  /// Bulk action handler
  void _bulkAction(AdminProvider provider, String action) {
    final isKeep = action == 'keep';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isKeep ? 'Keep All Selected?' : 'Delete All Selected?',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          'This action will affect ${_selectedItems.length} items.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final itemId in _selectedItems) {
                final items = provider.state.reportedContent;
                final item = items.firstWhere(
                  (i) => i['id'] == itemId,
                  orElse: () => {},
                );
                if (item.isNotEmpty) {
                  await _moveToResolved(item, isKeep ? 'kept' : 'deleted');
                  provider.moderateContent(
                    contentId:
                        item['originalId'] ?? item['contentId'] ?? itemId,
                    contentType: item['type'] ?? 'unknown',
                    approve: isKeep,
                    parentId: item['courseId'] ?? item['teacherId'],
                  );
                  await _removeFromModerationQueue(itemId);
                }
              }
              setState(() {
                _selectedItems.clear();
                _isSelectionMode = false;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isKeep ? 'Items kept' : 'Items deleted'),
                    backgroundColor: isKeep ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isKeep ? Colors.green : Colors.red,
            ),
            child: Text(isKeep ? 'Keep All' : 'Delete All'),
          ),
        ],
      ),
    );
  }
}
