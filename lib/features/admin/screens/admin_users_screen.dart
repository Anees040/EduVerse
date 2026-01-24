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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSearchBar(
            hintText: 'Search by name or email...',
            onSearch: provider.setSearchQuery,
            initialValue: provider.state.userSearchQuery,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdown(
                  'Role',
                  provider.state.userRoleFilter ?? 'all',
                  ['all', 'teacher', 'student'],
                  (value) =>
                      provider.setRoleFilter(value == 'all' ? null : value),
                  isDark,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: AdminSearchBar(
            hintText: 'Search by name or email...',
            onSearch: provider.setSearchQuery,
            initialValue: provider.state.userSearchQuery,
          ),
        ),
        const SizedBox(width: 16),
        _buildFilterDropdown(
          'Role',
          provider.state.userRoleFilter ?? 'all',
          ['all', 'teacher', 'student'],
          (value) => provider.setRoleFilter(value == 'all' ? null : value),
          isDark,
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    Function(String) onChanged,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
          dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(
                '$label: ${option[0].toUpperCase()}${option.substring(1)}',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
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
            _showConfirmDialog(
              title: 'Suspend User',
              message: 'Are you sure you want to suspend this user?',
              confirmText: 'Suspend',
              isDark: isDark,
              isDestructive: true,
              onConfirm: () => provider.toggleUserSuspension(uid, role, true),
            );
            break;
          case 'unsuspend':
            provider.toggleUserSuspension(uid, role, false);
            break;
          case 'verify':
            provider.verifyTeacher(uid);
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

  void _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isDark,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
        ),
        content: Text(
          message,
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
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? (isDark ? AppTheme.darkError : AppTheme.error)
                  : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
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
}
