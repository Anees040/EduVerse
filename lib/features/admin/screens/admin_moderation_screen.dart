import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../providers/admin_provider.dart';

/// Admin Moderation Screen - Enhanced Content Moderation Queue
/// Features: Filters, sorting, name resolution, detailed actions, bulk operations
class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  // Filter and sort state
  String _selectedFilter = 'all'; // all, qa, review, comment, video
  String _selectedSort = 'newest'; // newest, oldest, priority
  String _searchQuery = '';
  
  // Name cache to avoid repeated lookups
  final Map<String, String> _nameCache = {};
  
  // Selected items for bulk operations
  final Set<String> _selectedItems = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      if (provider.state.reportedContent.isEmpty) {
        provider.loadFlaggedContent();
      }
    });
  }

  /// Resolve user ID to name
  Future<String> _resolveUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'Unknown User';
    
    // Check cache first
    if (_nameCache.containsKey(userId)) {
      return _nameCache[userId]!;
    }
    
    // Try to fetch from database
    try {
      // Check students
      final studentSnap = await _db.child('student').child(userId).child('name').get();
      if (studentSnap.exists && studentSnap.value != null) {
        final name = studentSnap.value.toString();
        _nameCache[userId] = name;
        return name;
      }
      
      // Check teachers
      final teacherSnap = await _db.child('teacher').child(userId).child('name').get();
      if (teacherSnap.exists && teacherSnap.value != null) {
        final name = teacherSnap.value.toString();
        _nameCache[userId] = name;
        return name;
      }
      
      // Fallback - return truncated ID
      final truncated = userId.length > 6 ? 'User ${userId.substring(0, 6)}...' : userId;
      _nameCache[userId] = truncated;
      return truncated;
    } catch (e) {
      return userId.length > 6 ? 'User ${userId.substring(0, 6)}...' : userId;
    }
  }

  /// Filter and sort items
  List<Map<String, dynamic>> _getFilteredItems(List<Map<String, dynamic>> items) {
    var filtered = items.where((item) {
      // Type filter
      if (_selectedFilter != 'all') {
        final type = (item['type'] ?? '').toString().toLowerCase();
        if (type != _selectedFilter.toLowerCase()) return false;
      }
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final content = (item['content'] ?? item['text'] ?? item['comment'] ?? '').toString().toLowerCase();
        final reason = (item['reportReason'] ?? '').toString().toLowerCase();
        if (!content.contains(_searchQuery.toLowerCase()) && 
            !reason.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    // Sort
    filtered.sort((a, b) {
      final aTime = a['reportedAt'] ?? a['createdAt'] ?? 0;
      final bTime = b['reportedAt'] ?? b['createdAt'] ?? 0;
      
      switch (_selectedSort) {
        case 'oldest':
          return (aTime as int).compareTo(bTime as int);
        case 'priority':
          // Priority based on report reason severity
          final aPriority = _getPriority(a['reportReason'] ?? '');
          final bPriority = _getPriority(b['reportReason'] ?? '');
          if (aPriority != bPriority) return bPriority.compareTo(aPriority);
          return (bTime as int).compareTo(aTime as int);
        default: // newest
          return (bTime as int).compareTo(aTime as int);
      }
    });
    
    return filtered;
  }
  
  int _getPriority(String reason) {
    final lowerReason = reason.toLowerCase();
    if (lowerReason.contains('spam') || lowerReason.contains('harassment')) return 3;
    if (lowerReason.contains('inappropriate') || lowerReason.contains('offensive')) return 2;
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
                // Header with stats
                _buildHeader(allItems.length, filteredItems.length, isDark),
                const SizedBox(height: 16),
                
                // Filters and Search
                _buildFiltersAndSearch(isDark),
                const SizedBox(height: 16),
                
                // Bulk actions bar (shown in selection mode)
                if (_isSelectionMode && _selectedItems.isNotEmpty)
                  _buildBulkActionsBar(provider, isDark),
                
                // Content list
                Expanded(
                  child: filteredItems.isEmpty
                      ? _buildEmptyState(isDark, allItems.isEmpty)
                      : RefreshIndicator(
                          onRefresh: () => provider.loadFlaggedContent(refresh: true),
                          child: ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return _buildModerationCard(item, provider, isDark);
                            },
                          ),
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
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
        // Stats badges
        Row(
          children: [
            _buildStatBadge(total, 'Total', Colors.orange, isDark),
            const SizedBox(width: 8),
            _buildStatBadge(filtered, 'Showing', isDark ? AppTheme.darkAccent : AppTheme.primaryColor, isDark),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatBadge(int count, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
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
          // Search bar
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search reported content...',
              hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
              prefixIcon: Icon(Icons.search, color: AppTheme.getTextSecondary(context)),
              filled: true,
              fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          const SizedBox(height: 12),
          
          // Filter chips and sort
          Row(
            children: [
              // Type filters
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', Icons.all_inclusive, isDark),
                      _buildFilterChip('Q&A', 'qa', Icons.question_answer, isDark),
                      _buildFilterChip('Reviews', 'review', Icons.star, isDark),
                      _buildFilterChip('Comments', 'comment', Icons.comment, isDark),
                      _buildFilterChip('Videos', 'video', Icons.video_library, isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Sort dropdown
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
                  icon: Icon(Icons.sort, color: AppTheme.getTextSecondary(context)),
                  items: [
                    DropdownMenuItem(value: 'newest', child: Text('Newest', style: TextStyle(color: AppTheme.getTextPrimary(context)))),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest', style: TextStyle(color: AppTheme.getTextPrimary(context)))),
                    DropdownMenuItem(value: 'priority', child: Text('Priority', style: TextStyle(color: AppTheme.getTextPrimary(context)))),
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
  
  Widget _buildFilterChip(String label, String value, IconData icon, bool isDark) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppTheme.getTextSecondary(context)),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1),
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
            onPressed: () => _bulkAction(provider, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Keep All'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _bulkAction(provider, false),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete All'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
  
  void _bulkAction(AdminProvider provider, bool approve) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          approve ? 'Keep All Selected?' : 'Delete All Selected?',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          'This action will affect ${_selectedItems.length} items.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Process bulk action
              for (final itemId in _selectedItems) {
                // Find item in provider
                final items = provider.state.reportedContent;
                final item = items.firstWhere(
                  (i) => i['id'] == itemId,
                  orElse: () => {},
                );
                if (item.isNotEmpty) {
                  provider.moderateContent(
                    contentId: itemId,
                    contentType: item['type'] ?? 'unknown',
                    approve: approve,
                    parentId: item['courseId'] ?? item['teacherId'],
                  );
                }
              }
              setState(() {
                _selectedItems.clear();
                _isSelectionMode = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(approve ? 'Items kept' : 'Items deleted'),
                  backgroundColor: approve ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            child: Text(approve ? 'Keep All' : 'Delete All'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool noReports) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (noReports ? Colors.green : Colors.orange).withOpacity(0.1),
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
            noReports ? 'All Clear! 🎉' : 'No Results',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noReports 
                ? 'No reported content to review'
                : 'Try adjusting your filters',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
            ),
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

  Widget _buildModerationCard(
    Map<String, dynamic> item,
    AdminProvider provider,
    bool isDark,
  ) {
    final type = item['type'] ?? 'unknown';
    final content = item['content'] ?? item['text'] ?? item['comment'] ?? 'No content';
    final reportReason = item['reportReason'] ?? 'Policy violation';
    final reportedBy = item['reportedBy'];
    final reportedUserId = item['reportedUserId'] ?? item['userId'] ?? item['authorId'];
    // Use originalId if available, otherwise use contentId or id
    final contentId = item['originalId'] ?? item['contentId'] ?? item['id'] ?? '';
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
                  _selectedItems.remove(contentId);
                } else {
                  _selectedItems.add(item['id']);
                }
              });
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type badge and selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkError : AppTheme.error).withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
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
                        activeColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                      ),
                    ),
                  _buildTypeBadge(type, isDark),
                  const SizedBox(width: 12),
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
                            color: isDark ? AppTheme.darkError : AppTheme.error,
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
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reported content
                  Text(
                    'Reported Content:',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBackground.withOpacity(0.5) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Reporter and Reported user info
                  Row(
                    children: [
                      Expanded(
                        child: _buildUserInfo(
                          'Reported by',
                          reportedBy,
                          Icons.flag,
                          Colors.orange,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildUserInfo(
                          'Content Author',
                          reportedUserId,
                          Icons.person,
                          Colors.blue,
                          isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  // View Details button
                  TextButton.icon(
                    onPressed: () => _showDetailedView(item, isDark),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.getTextSecondary(context),
                    ),
                  ),
                  // Keep button
                  OutlinedButton.icon(
                    onPressed: () => _showDismissDialog(contentId, type, parentId, provider, isDark),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Keep'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  // Warn user button
                  OutlinedButton.icon(
                    onPressed: () => _showWarnUserDialog(item, isDark),
                    icon: const Icon(Icons.warning, size: 18),
                    label: const Text('Warn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  // Delete button
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteDialog(contentId, type, parentId, provider, isDark),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  
  Widget _buildTypeBadge(String type, bool isDark) {
    final color = _getTypeColor(type, isDark);
    final icon = _getTypeIcon(type);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
  
  Widget _buildUserInfo(String label, String? userId, IconData icon, Color color, bool isDark) {
    return FutureBuilder<String>(
      future: _resolveUserName(userId),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'Loading...';
        
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
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
            ],
          ),
        );
      },
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
      return DateFormat('MMM d').format(date);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'qa':
        return Icons.question_answer;
      case 'review':
        return Icons.star;
      case 'comment':
        return Icons.comment;
      case 'video':
        return Icons.video_library;
      default:
        return Icons.article;
    }
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'qa':
        return Colors.purple;
      case 'review':
        return Colors.amber;
      case 'comment':
        return Colors.blue;
      case 'video':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  void _showDetailedView(Map<String, dynamic> item, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Report Details',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              
              _buildDetailRow('Type', item['type']?.toString().toUpperCase() ?? 'Unknown'),
              _buildDetailRow('Report Reason', item['reportReason'] ?? 'Not specified'),
              _buildDetailRow('Content', item['content'] ?? item['text'] ?? 'No content'),
              
              if (item['courseId'] != null)
                _buildDetailRow('Course ID', item['courseId']),
              if (item['teacherId'] != null)
                _buildDetailRow('Teacher ID', item['teacherId']),
                
              const SizedBox(height: 20),
              
              // Action buttons
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              
              ListTile(
                leading: const Icon(Icons.person_search, color: Colors.blue),
                title: const Text('View Reporter Profile'),
                onTap: () {
                  Navigator.pop(context);
                  _viewUserProfile(item['reportedBy'], isDark);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.purple),
                title: const Text('View Author Profile'),
                onTap: () {
                  Navigator.pop(context);
                  _viewUserProfile(item['reportedUserId'] ?? item['userId'], isDark);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Suspend Author'),
                onTap: () {
                  Navigator.pop(context);
                  _showSuspendUserDialog(item, isDark);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  void _viewUserProfile(String? userId, bool isDark) {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not available')),
      );
      return;
    }
    
    // Show user profile in a dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('User Profile', style: TextStyle(color: AppTheme.getTextPrimary(context))),
        content: FutureBuilder<String>(
          future: _resolveUserName(userId),
          builder: (context, snapshot) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${snapshot.data ?? 'Loading...'}', style: TextStyle(color: AppTheme.getTextPrimary(context))),
                const SizedBox(height: 8),
                Text('User ID: $userId', style: TextStyle(color: AppTheme.getTextSecondary(context), fontSize: 12)),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showWarnUserDialog(Map<String, dynamic> item, bool isDark) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Warn User', style: TextStyle(color: AppTheme.getTextPrimary(context))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send a warning to the content author about their behavior.',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Warning reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              final userId = item['reportedUserId'] ?? item['userId'] ?? item['authorId'];
              if (userId != null) {
                await _db.child('warnings').child(userId).push().set({
                  'reason': reasonController.text,
                  'contentType': item['type'],
                  'contentId': item['id'],
                  'warnedAt': ServerValue.timestamp,
                });
                
                // Also send notification
                await _db.child('notifications').child(userId).push().set({
                  'title': '⚠️ Content Warning',
                  'message': reasonController.text.isNotEmpty 
                      ? reasonController.text 
                      : 'Your content has been flagged for violating community guidelines.',
                  'type': 'warning',
                  'createdAt': ServerValue.timestamp,
                  'read': false,
                });
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Warning sent to user'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );
  }
  
  void _showSuspendUserDialog(Map<String, dynamic> item, bool isDark) {
    final userId = item['reportedUserId'] ?? item['userId'] ?? item['authorId'];
    
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not available')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Text('Suspend User', style: TextStyle(color: AppTheme.getTextPrimary(context))),
          ],
        ),
        content: Text(
          'This will suspend the user\'s account. They will not be able to access the platform until reinstated.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Try to suspend in both student and teacher nodes
              await _db.child('student').child(userId).update({'isSuspended': true});
              await _db.child('teacher').child(userId).update({'isSuspended': true});
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User suspended'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  void _showDismissDialog(
    String contentId,
    String contentType,
    String? parentId,
    AdminProvider provider,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Dismiss Report', style: TextStyle(color: AppTheme.getTextPrimary(context))),
        content: Text(
          'This will keep the content and dismiss the report. Are you sure?',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.moderateContent(
                contentId: contentId,
                contentType: contentType,
                approve: true,
                parentId: parentId,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report dismissed'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Keep Content'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    String contentId,
    String contentType,
    String? parentId,
    AdminProvider provider,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Content', style: TextStyle(color: AppTheme.getTextPrimary(context))),
          ],
        ),
        content: Text(
          'This will permanently delete the content. This action cannot be undone.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.getTextSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.moderateContent(
                contentId: contentId,
                contentType: contentType,
                approve: false,
                parentId: parentId,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Content deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
