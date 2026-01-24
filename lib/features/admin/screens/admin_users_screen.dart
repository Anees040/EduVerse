import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_data_table.dart';

/// Admin Users Screen - User Management with pagination
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load users if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      if (provider.state.users.isEmpty) {
        provider.loadUsers(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'User Management',
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
                'Manage all teachers and students on the platform',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Search and Filters
              _buildFiltersSection(provider, isDark),
              const SizedBox(height: 20),

              // User Table
              Expanded(
                child: AdminDataTable(
                  data: provider.state.users,
                  isLoading: provider.state.isLoading,
                  hasMore: provider.state.hasMoreUsers,
                  onLoadMore: () => provider.loadUsers(),
                  emptyMessage: 'No users found',
                  columns: [
                    AdminTableColumn(
                      title: 'USER',
                      field: 'name',
                      flex: 2,
                      builder: (user) => _buildUserCell(user, isDark),
                    ),
                    AdminTableColumn(title: 'EMAIL', field: 'email', flex: 2),
                    AdminTableColumn(
                      title: 'ROLE',
                      field: 'role',
                      flex: 1,
                      builder: (user) => _buildRoleChip(user, isDark),
                    ),
                    AdminTableColumn(
                      title: 'STATUS',
                      field: 'status',
                      flex: 1,
                      builder: (user) => _buildStatusChip(user, isDark),
                    ),
                  ],
                  actionsBuilder: (user) =>
                      _buildActions(user, provider, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFiltersSection(AdminProvider provider, bool isDark) {
    final currentFilter = provider.state.userRoleFilter ?? 'all';
    final hasSearchText = _searchController.text.isNotEmpty;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (query) {
                      setState(() {}); // Refresh to show/hide clear button
                      provider.setSearchQuery(query);
                    },
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                      ),
                      suffixIcon: hasSearchText
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                provider.setSearchQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                // Filter button
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showFilterBottomSheet(provider, isDark),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              color: currentFilter != 'all'
                                  ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                                  : (isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary),
                              size: 20,
                            ),
                            if (currentFilter != 'all') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  currentFilter[0].toUpperCase() + currentFilter.substring(1),
                                  style: TextStyle(
                                    color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet(AdminProvider provider, bool isDark) {
    final currentFilter = provider.state.userRoleFilter ?? 'all';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Filter Users',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  if (currentFilter != 'all')
                    TextButton(
                      onPressed: () {
                        provider.setRoleFilter(null);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkError : AppTheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Filter options
            _buildFilterOption('all', 'All Users', Icons.people_rounded, currentFilter, provider, isDark),
            _buildFilterOption('teacher', 'Teachers', Icons.school_rounded, currentFilter, provider, isDark),
            _buildFilterOption('student', 'Students', Icons.person_rounded, currentFilter, provider, isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(
    String value,
    String label,
    IconData icon,
    String currentFilter,
    AdminProvider provider,
    bool isDark,
  ) {
    final isSelected = currentFilter == value;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          provider.setRoleFilter(value == 'all' ? null : value);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor).withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor).withOpacity(0.2)
                      : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCell(Map<String, dynamic> user, bool isDark) {
    final name = user['name'] ?? 'Unknown';
    final profilePicture = user['profilePicture'];

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                  .withOpacity(0.1),
          backgroundImage: profilePicture != null && profilePicture.isNotEmpty
              ? NetworkImage(profilePicture)
              : null,
          child: profilePicture == null || profilePicture.isEmpty
              ? Text(
                  name[0].toUpperCase(),
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkPrimary
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(Map<String, dynamic> user, bool isDark) {
    final role = (user['role'] ?? 'user').toString();
    final isTeacher = role == 'teacher';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isTeacher
            ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor).withOpacity(
                0.1,
              )
            : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                  .withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: isTeacher
              ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
              : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildStatusChip(Map<String, dynamic> user, bool isDark) {
    final isSuspended = user['isSuspended'] == true;
    final isVerified = user['isVerified'] == true;

    String status;
    Color color;

    if (isSuspended) {
      status = 'SUSPENDED';
      color = isDark ? AppTheme.darkError : AppTheme.error;
    } else if (isVerified) {
      status = 'VERIFIED';
      color = isDark ? AppTheme.darkSuccess : AppTheme.success;
    } else {
      status = 'ACTIVE';
      color = isDark ? AppTheme.darkPrimary : AppTheme.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVerified && !isSuspended)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.verified_rounded, size: 12, color: color),
            ),
          Text(
            status,
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

  Widget _buildActions(
    Map<String, dynamic> user,
    AdminProvider provider,
    bool isDark,
  ) {
    final uid = user['uid'] ?? '';
    final isSuspended = user['isSuspended'] == true;
    final isVerified = user['isVerified'] == true;
    final role = user['role'] ?? '';

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
      ),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) {
        switch (action) {
          case 'suspend':
            _showSuspendDialog(user, provider, isDark);
            break;
          case 'unsuspend':
            provider.toggleUserSuspension(uid, role, false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('User has been unsuspended'),
                backgroundColor: isDark ? AppTheme.darkSuccess : AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'verify':
            // Pass email and name for approval email
            provider.verifyTeacher(
              uid,
              email: user['email'] as String?,
              name: user['name'] as String?,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Teacher verified. Approval email sent.'),
                backgroundColor: isDark ? AppTheme.darkSuccess : AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case 'reject':
            _showRejectTeacherDialog(user, provider, isDark);
            break;
          case 'view':
            // Show user details dialog
            _showUserDetailsDialog(user, isDark);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: 18,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'View Details',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (role == 'teacher' && !isVerified && !isSuspended)
          PopupMenuItem(
            value: 'verify',
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Verify Teacher',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        if (role == 'teacher' && !isVerified && !isSuspended)
          PopupMenuItem(
            value: 'reject',
            child: Row(
              children: [
                Icon(
                  Icons.cancel_rounded,
                  size: 18,
                  color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reject Application',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
        if (isSuspended)
          PopupMenuItem(
            value: 'unsuspend',
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Unsuspend',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                  ),
                ),
              ],
            ),
          )
        else
          PopupMenuItem(
            value: 'suspend',
            child: Row(
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 18,
                  color: isDark ? AppTheme.darkError : AppTheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Suspend',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkError : AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> user, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      .withOpacity(0.1),
              child: Text(
                (user['name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user['name'] ?? 'Unknown',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', user['email'] ?? '-', isDark),
              _buildDetailRow('Role', user['role'] ?? '-', isDark),
              _buildDetailRow(
                'Status',
                user['isSuspended'] == true
                    ? 'Suspended'
                    : user['isVerified'] == true
                    ? 'Verified'
                    : 'Active',
                isDark,
              ),
              if (user['bio'] != null)
                _buildDetailRow('Bio', user['bio'], isDark),
              if (user['headline'] != null)
                _buildDetailRow('Headline', user['headline'], isDark),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextTertiary
                  : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuspendDialog(
    Map<String, dynamic> user,
    AdminProvider provider,
    bool isDark,
  ) {
    String suspensionType = 'temporary';
    final reasonController = TextEditingController();
    final uid = user['uid'] ?? '';
    final role = user['role'] ?? '';
    final userName = user['name'] ?? 'User';
    final userEmail = user['email'] ?? '';
    String? reasonError; // For inline validation

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.block_rounded,
                color: isDark ? AppTheme.darkError : AppTheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Suspend User',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Suspending: $userName',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Suspension Type',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: Text(
                    'Temporary',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'User can appeal for review',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: 'temporary',
                  groupValue: suspensionType,
                  activeColor: isDark ? AppTheme.darkWarning : AppTheme.warning,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setDialogState(() => suspensionType = value!);
                  },
                ),
                RadioListTile<String>(
                  title: Text(
                    'Permanent',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkError : AppTheme.error,
                    ),
                  ),
                  subtitle: Text(
                    'Account will be permanently banned',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: 'permanent',
                  groupValue: suspensionType,
                  activeColor: isDark ? AppTheme.darkError : AppTheme.error,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (value) {
                    setDialogState(() => suspensionType = value!);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason for Suspension *',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                  onChanged: (value) {
                    // Clear error when user starts typing
                    if (reasonError != null && value.trim().isNotEmpty) {
                      setDialogState(() => reasonError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter the reason for suspension...',
                    hintStyle: TextStyle(
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkBackground : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: reasonError != null
                          ? BorderSide(color: isDark ? AppTheme.darkError : AppTheme.error, width: 1.5)
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: reasonError != null
                            ? (isDark ? AppTheme.darkError : AppTheme.error)
                            : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    errorText: reasonError,
                    errorStyle: TextStyle(
                      color: isDark ? AppTheme.darkError : AppTheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkInfo : AppTheme.info).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDark ? AppTheme.darkInfo : AppTheme.info).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_rounded,
                        color: isDark ? AppTheme.darkInfo : AppTheme.info,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'An email will be sent to the user notifying them of the suspension.',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkInfo : AppTheme.info,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Inline validation
                if (reasonController.text.trim().isEmpty) {
                  setDialogState(() {
                    reasonError = 'Please provide a reason for suspension';
                  });
                  return;
                }

                final reason = reasonController.text.trim();
                final suspensionTypeFinal = suspensionType;
                
                // Capture the scaffold messenger before closing dialog
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Close dialog first
                Navigator.pop(ctx);
                
                // Suspend user with reason
                await provider.suspendUserWithReason(
                  uid: uid,
                  role: role,
                  reason: reason,
                  isPermanent: suspensionTypeFinal == 'permanent',
                  userEmail: userEmail,
                  userName: userName,
                );

                // Use captured scaffold messenger
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'User has been ${suspensionTypeFinal == 'permanent' ? 'permanently' : 'temporarily'} suspended',
                    ),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
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
              child: const Text('Suspend User'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectTeacherDialog(
    Map<String, dynamic> user,
    AdminProvider provider,
    bool isDark,
  ) {
    final reasonController = TextEditingController();
    final uid = user['uid'] ?? '';
    final userName = user['name'] ?? 'Teacher';
    final userEmail = user['email'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                Icons.cancel_rounded,
                color: isDark ? AppTheme.darkWarning : AppTheme.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reject Teacher Application',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rejecting application from: $userName',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Reason for Rejection (optional)',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Provide feedback to the teacher (e.g., missing credentials, incomplete application)...',
                    hintStyle: TextStyle(
                      color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkBackground : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkInfo : AppTheme.info).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDark ? AppTheme.darkInfo : AppTheme.info).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_rounded,
                        color: isDark ? AppTheme.darkInfo : AppTheme.info,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'An email will be sent to the teacher notifying them of the rejection.',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkInfo : AppTheme.info,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim().isEmpty 
                    ? null 
                    : reasonController.text.trim();
                
                // Capture the scaffold messenger before closing dialog
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Close dialog first
                Navigator.pop(ctx);
                
                // Reject teacher with reason
                await provider.rejectTeacher(
                  uid,
                  email: userEmail,
                  name: userName,
                  reason: reason,
                );

                // Use captured scaffold messenger
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: const Text('Teacher application rejected. Email sent.'),
                    backgroundColor: isDark ? AppTheme.darkWarning : AppTheme.warning,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkWarning : AppTheme.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reject Application'),
            ),
          ],
        ),
      ),
    );
  }
}
