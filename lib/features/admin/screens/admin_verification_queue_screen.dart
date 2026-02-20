import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../services/admin_service.dart';

/// Admin Verification Queue Screen - Review pending teacher applications
class AdminVerificationQueueScreen extends StatefulWidget {
  const AdminVerificationQueueScreen({super.key});

  @override
  State<AdminVerificationQueueScreen> createState() =>
      _AdminVerificationQueueScreenState();
}

class _AdminVerificationQueueScreenState
    extends State<AdminVerificationQueueScreen> {
  List<Map<String, dynamic>> _pendingTeachers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingTeachers();
  }

  Future<void> _loadPendingTeachers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all teachers and filter client-side to avoid Firebase index requirement
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('teacher')
          .get();

      final List<Map<String, dynamic>> teachers = [];
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final teacherData = Map<String, dynamic>.from(value as Map);
          // Only include teachers with 'pending' status
          if (teacherData['status'] == 'pending') {
            teachers.add({'uid': key, ...teacherData});
          }
        });
      }

      // Sort by creation date (newest first)
      teachers.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      if (!mounted) return;
      setState(() {
        _pendingTeachers = teachers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(isNarrow ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - responsive layout
            if (isNarrow)
              // Stack header elements vertically on narrow screens
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Queue',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review pending teacher applications',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pending_actions_rounded,
                              color: AppTheme.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_pendingTeachers.length} Pending',
                              style: TextStyle(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Refresh button
                      IconButton(
                        onPressed: _loadPendingTeachers,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'Refresh',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              )
            else
              // Original wide layout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Queue',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review and verify pending teacher applications',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pending_actions_rounded,
                              color: AppTheme.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_pendingTeachers.length} Pending',
                              style: TextStyle(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Refresh button
                      IconButton(
                        onPressed: _loadPendingTeachers,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                        ),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ],
              ),
            SizedBox(height: isNarrow ? 16 : 24),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(isDark)
                  : _error != null
                  ? _buildErrorState(isDark)
                  : _pendingTeachers.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildApplicationsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading pending applications...',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: isDark ? AppTheme.darkError : AppTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load applications',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadPendingTeachers,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkPrimary
                  : AppTheme.primaryColor,
              foregroundColor: Colors.white,
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
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 48,
              color: isDark ? AppTheme.darkSuccess : AppTheme.success,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All caught up!',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending teacher applications to review',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList(bool isDark) {
    return ListView.builder(
      itemCount: _pendingTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _pendingTeachers[index];
        return _buildApplicationCard(teacher, isDark);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> teacher, bool isDark) {
    final name = teacher['name'] ?? 'Unknown';
    final email = teacher['email'] ?? '';
    final headline = teacher['headline'] ?? '';
    final expertise = teacher['expertise'] ?? '';
    final experience = teacher['yearsOfExperience'] ?? '';
    final profilePicture = teacher['profilePicture'];
    final createdAt = teacher['createdAt'];
    final credentials = teacher['credentialDocuments'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with photo and basic info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 32,
                  backgroundColor: isDark
                      ? AppTheme.darkBorder
                      : Colors.grey.shade200,
                  backgroundImage: profilePicture != null
                      ? NetworkImage(profilePicture)
                      : null,
                  child: profilePicture == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        headline.isNotEmpty ? headline : email,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            icon: Icons.category_outlined,
                            label: expertise,
                            isDark: isDark,
                          ),
                          _buildInfoChip(
                            icon: Icons.timer_outlined,
                            label: '$experience years exp.',
                            isDark: isDark,
                          ),
                          _buildInfoChip(
                            icon: Icons.email_outlined,
                            label: email,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Timestamp
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),

          // Bio and details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  teacher['bio'] ?? 'No bio provided',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Credentials section
                Row(
                  children: [
                    Text(
                      'Credentials',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.darkInfo : AppTheme.info)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${credentials.length} files',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkInfo : AppTheme.info,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Certifications
                if (teacher['certifications'] != null) ...[
                  Text(
                    'Certifications: ${teacher['certifications']}',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],

                // Education
                if (teacher['education'] != null) ...[
                  Text(
                    'Education: ${teacher['education']}',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Links
                if (teacher['linkedIn']?.isNotEmpty == true ||
                    teacher['portfolio']?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (teacher['linkedIn']?.isNotEmpty == true)
                        _buildLinkButton(
                          icon: Icons.link_rounded,
                          label: 'LinkedIn',
                          url: teacher['linkedIn'],
                          isDark: isDark,
                        ),
                      if (teacher['linkedIn']?.isNotEmpty == true &&
                          teacher['portfolio']?.isNotEmpty == true)
                        const SizedBox(width: 8),
                      if (teacher['portfolio']?.isNotEmpty == true)
                        _buildLinkButton(
                          icon: Icons.language_rounded,
                          label: 'Portfolio',
                          url: teacher['portfolio'],
                          isDark: isDark,
                        ),
                    ],
                  ),
                ],

                // Document links
                if (credentials.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(credentials.length, (index) {
                      return _buildDocumentChip(
                        index: index,
                        url: credentials[index].toString(),
                        isDark: isDark,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(teacher),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppTheme.darkError
                          : AppTheme.error,
                      side: BorderSide(
                        color: isDark ? AppTheme.darkError : AppTheme.error,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveTeacher(teacher),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.darkSuccess
                          : AppTheme.success,
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
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton({
    required IconData icon,
    required String label,
    required String url,
    required bool isDark,
  }) {
    return TextButton.icon(
      onPressed: () => _showDocumentViewer(url),
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDocumentChip({
    required int index,
    required String url,
    required bool isDark,
  }) {
    return ActionChip(
      avatar: Icon(
        Icons.description_outlined,
        size: 16,
        color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
      ),
      label: Text('Document ${index + 1}'),
      onPressed: () => _showDocumentViewer(url),
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        fontSize: 12,
      ),
    );
  }

  /// Show document/image in a responsive dialog viewer
  void _showDocumentViewer(String url) {
    final isDark = AppTheme.isDarkMode(context);
    final screenSize = MediaQuery.of(context).size;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenSize.width > 600 ? screenSize.width * 0.15 : 16,
          vertical: 24,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: screenSize.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.image_rounded,
                      color: isDark
                          ? AppTheme.darkPrimary
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Document Viewer',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    // Copy URL button
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('URL copied to clipboard'),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.copy_rounded,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                        size: 20,
                      ),
                      tooltip: 'Copy URL',
                    ),
                    // Close button
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              // Image content
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _approveTeacher(Map<String, dynamic> teacher) async {
    final uid = teacher['uid'];
    final name = teacher['name'];

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = AppTheme.isDarkMode(context);
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Approve Teacher',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve $name as a teacher?',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'They will receive an email and be able to log in.',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkSuccess
                              : AppTheme.success,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
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
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkSuccess
                    : AppTheme.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Update teacher status in Firebase
      await FirebaseDatabase.instance.ref().child('teacher').child(uid).update({
        'status': 'active',
        'isVerified': true,
        'verifiedAt': ServerValue.timestamp,
      });

      // Send approval email
      try {
        final adminService = AdminService();
        await adminService.sendVerificationEmail(
          email: teacher['email'] ?? '',
          name: name,
          isApproved: true,
        );
      } catch (e) {
        debugPrint('Failed to send approval email: $e');
      }

      // Refresh list
      await _loadPendingTeachers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name has been approved as a teacher'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(Map<String, dynamic> teacher) async {
    final uid = teacher['uid'];
    final name = teacher['name'];
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = AppTheme.isDarkMode(context);
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Reject Application',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejecting $name\'s application:',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkBackground
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
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
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a rejection reason'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkError : AppTheme.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final reason = reasonController.text.trim();

    try {
      // Update teacher status
      await FirebaseDatabase.instance.ref().child('teacher').child(uid).update({
        'status': 'rejected',
        'rejectedAt': ServerValue.timestamp,
        'rejectionReason': reason,
      });

      // Send rejection email
      try {
        final adminService = AdminService();
        await adminService.sendVerificationEmail(
          email: teacher['email'] ?? '',
          name: name,
          isApproved: false,
          reason: reason,
        );
      } catch (e) {
        debugPrint('Failed to send rejection email: $e');
      }

      // Refresh list
      await _loadPendingTeachers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name\'s application has been rejected'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}
