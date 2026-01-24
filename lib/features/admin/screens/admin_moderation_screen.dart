import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../providers/admin_provider.dart';

/// Admin Moderation Screen - Content moderation queue
/// Handles reported Q&A and Reviews
class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  @override
  void initState() {
    super.initState();
    // Load reported content if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      if (provider.state.reportedContent.isEmpty) {
        provider.loadFlaggedContent();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        final items = provider.state.reportedContent;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Content Moderation',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Review and moderate reported content',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatsCard(items.length, isDark),
                ],
              ),
              const SizedBox(height: 24),

              // Moderation Queue
              Expanded(
                child: items.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: () =>
                            provider.loadFlaggedContent(refresh: true),
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildModerationCard(item, provider, isDark);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.darkError : AppTheme.error).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppTheme.darkError : AppTheme.error).withOpacity(
            0.3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.report_rounded,
            color: isDark ? AppTheme.darkError : AppTheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            '$count Pending',
            style: TextStyle(
              color: isDark ? AppTheme.darkError : AppTheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: isDark ? AppTheme.darkSuccess : AppTheme.success,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Clear! 🎉',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No reported content to review',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
              fontSize: 16,
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
    final content =
        item['content'] ?? item['text'] ?? item['comment'] ?? 'No content';
    final reportReason = item['reportReason'] ?? 'Policy violation';
    final reportedBy = item['reportedBy'] ?? 'Unknown';
    final contentId = item['id'] ?? '';
    final parentId = item['courseId'] ?? item['teacherId'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkError : AppTheme.error).withOpacity(
                0.05,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type, isDark).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getTypeIcon(type),
                        size: 14,
                        color: _getTypeColor(type, isDark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: _getTypeColor(type, isDark),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported for:',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.textSecondary,
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
                Icon(
                  Icons.flag_rounded,
                  color: isDark ? AppTheme.darkError : AppTheme.error,
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
                Text(
                  'Reported Content:',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkBackground.withOpacity(0.5)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reported by: $reportedBy',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.textSecondary,
                        fontSize: 12,
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDismissDialog(
                      contentId,
                      type,
                      parentId,
                      provider,
                      isDark,
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Keep'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppTheme.darkSuccess
                          : AppTheme.success,
                      side: BorderSide(
                        color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDeleteDialog(
                      contentId,
                      type,
                      parentId,
                      provider,
                      isDark,
                    ),
                    icon: const Icon(Icons.delete_rounded),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.darkError
                          : AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'qa':
        return Icons.question_answer_rounded;
      case 'review':
        return Icons.star_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'qa':
        return isDark ? AppTheme.darkPrimary : AppTheme.primaryColor;
      case 'review':
        return isDark ? AppTheme.darkWarning : AppTheme.warning;
      default:
        return isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    }
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
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Dismiss Report',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'This will keep the content and dismiss the report. Are you sure?',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
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
                SnackBar(
                  content: const Text('Report dismissed'),
                  backgroundColor: isDark
                      ? AppTheme.darkSuccess
                      : AppTheme.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkSuccess : AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: isDark ? AppTheme.darkError : AppTheme.error,
            ),
            const SizedBox(width: 8),
            Text(
              'Delete Content',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete the content. This action cannot be undone.',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
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
                SnackBar(
                  content: const Text('Content deleted'),
                  backgroundColor: isDark ? AppTheme.darkError : AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkError : AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
