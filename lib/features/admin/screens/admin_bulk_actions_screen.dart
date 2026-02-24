import 'package:flutter/material.dart';
import 'package:eduverse/features/admin/services/admin_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin screen for performing bulk actions on multiple users.
class AdminBulkActionsScreen extends StatefulWidget {
  const AdminBulkActionsScreen({super.key});

  @override
  State<AdminBulkActionsScreen> createState() => _AdminBulkActionsScreenState();
}

class _AdminBulkActionsScreenState extends State<AdminBulkActionsScreen> {
  final _featureService = AdminFeatureService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  Set<String> _selectedUids = {};
  bool _isLoading = true;
  bool _isPerformingAction = false;
  String _filterRole = 'all'; // all, student, teacher

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _featureService.exportUserData();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var list = _users;
    if (_filterRole != 'all') {
      list = list.where((u) => u['role'] == _filterRole).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((u) =>
              (u['name'] as String? ?? '').toLowerCase().contains(query) ||
              (u['email'] as String? ?? '').toLowerCase().contains(query))
          .toList();
    }
    return list;
  }

  Future<void> _performBulkSuspend() async {
    if (_selectedUids.isEmpty) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Suspend ${_selectedUids.length} Users?',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will suspend all selected users and prevent them from accessing the platform.',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Reason for suspension',
                labelStyle: TextStyle(
                    color: AppTheme.getTextSecondary(context)),
                filled: true,
                fillColor: AppTheme.isDarkMode(context)
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suspend All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPerformingAction = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final selectedUsers = _users
        .where((u) => _selectedUids.contains(u['uid']))
        .map((u) => {
              'uid': u['uid'] as String? ?? '',
              'role': u['role'] as String? ?? 'student',
            })
        .toList();

    final results = await _featureService.bulkSuspendUsers(
      selectedUsers,
      reasonCtrl.text.trim().isEmpty
          ? 'Bulk suspension by admin'
          : reasonCtrl.text.trim(),
    );

    final successCount = results.values.where((v) => v).length;

    if (mounted) {
      setState(() {
        _isPerformingAction = false;
        _selectedUids.clear();
      });
      _loadUsers();
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Suspended $successCount/${selectedUsers.length} users'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _performBulkUnsuspend() async {
    if (_selectedUids.isEmpty) return;

    setState(() => _isPerformingAction = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final selectedUsers = _users
        .where((u) => _selectedUids.contains(u['uid']))
        .map((u) => {
              'uid': u['uid'] as String? ?? '',
              'role': u['role'] as String? ?? 'student',
            })
        .toList();

    final results = await _featureService.bulkUnsuspendUsers(selectedUsers);
    final successCount = results.values.where((v) => v).length;

    if (mounted) {
      setState(() {
        _isPerformingAction = false;
        _selectedUids.clear();
      });
      _loadUsers();
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content:
            Text('Unsuspended $successCount/${selectedUsers.length} users'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
    final filtered = _filteredUsers;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Icon(Icons.groups_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bulk User Actions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
              ),
              if (_selectedUids.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedUids.length} selected',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Search & filter
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: TextStyle(
                        color: AppTheme.getTextSecondary(context)),
                    prefixIcon: Icon(Icons.search,
                        color: AppTheme.getTextSecondary(context)),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCard : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _filterRole,
                dropdownColor:
                    isDark ? AppTheme.darkCard : Colors.white,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 13,
                ),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Roles')),
                  DropdownMenuItem(value: 'student', child: Text('Students')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                ],
                onChanged: (v) => setState(() => _filterRole = v ?? 'all'),
              ),
            ],
          ),
        ),

        // Bulk action bar
        if (_selectedUids.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isPerformingAction ? null : _performBulkSuspend,
                    icon: _isPerformingAction
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.block, size: 16),
                    label: const Text('Suspend Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isPerformingAction ? null : _performBulkUnsuspend,
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Unsuspend Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Select All / Clear
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(
                '${filtered.length} users',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedUids.length == filtered.length) {
                      _selectedUids.clear();
                    } else {
                      _selectedUids = filtered
                          .map((u) => u['uid'] as String? ?? '')
                          .where((uid) => uid.isNotEmpty)
                          .toSet();
                    }
                  });
                },
                child: Text(
                  _selectedUids.length == filtered.length
                      ? 'Clear All'
                      : 'Select All',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // User list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildUserTile(
                              filtered[index], isDark, accentColor);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildUserTile(
    Map<String, dynamic> user,
    bool isDark,
    Color accentColor,
  ) {
    final uid = user['uid'] as String? ?? '';
    final name = user['name'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? 'student';
    final isSuspended = user['isSuspended'] as bool? ?? false;
    final isSelected = _selectedUids.contains(uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? accentColor.withOpacity(0.08)
            : (isDark ? AppTheme.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? accentColor.withOpacity(0.4)
              : (isDark ? AppTheme.darkBorderColor : Colors.grey.shade200),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) {
            setState(() {
              if (isSelected) {
                _selectedUids.remove(uid);
              } else {
                _selectedUids.add(uid);
              }
            });
          },
          activeColor: accentColor,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: role == 'teacher'
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  color:
                      role == 'teacher' ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            if (isSuspended) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SUSPENDED',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          email,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedUids.remove(uid);
            } else {
              _selectedUids.add(uid);
            }
          });
        },
      ),
    );
  }
}
