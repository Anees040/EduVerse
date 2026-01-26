import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_scaffold.dart';
import 'admin_users_screen.dart';
import 'admin_verification_queue_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_data_screen.dart';
import 'admin_support_screen.dart';
import 'admin_all_courses_screen.dart';

/// Main Admin Dashboard Screen
/// Hub for all admin functionalities with KPI overview
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  Timer? _refreshTimer;

  final List<Widget> _screens = [
    const _DashboardHomeTab(),
    const AdminUsersScreen(),
    const AdminVerificationQueueScreen(),
    const AdminModerationScreen(),
    const AdminAnalyticsScreen(),
    const AdminDataScreen(),
    const AdminSupportScreen(),
    const AdminAllCoursesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Verify admin access and load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAdmin();
    });
    // Set up periodic refresh every 30 seconds for real-time feel
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshDashboardData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshDashboardData() {
    if (!mounted) return;
    final provider = Provider.of<AdminProvider>(context, listen: false);
    provider.loadKPIStats();
    // Only refresh users if on dashboard or users tab
    if (_selectedIndex == 0 || _selectedIndex == 1) {
      provider.loadUsers(refresh: true);
    }
  }

  /// Public method to change tab from child widgets
  void navigateToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _initializeAdmin() async {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    final isAdmin = await provider.checkAdminAccess();

    if (!isAdmin && mounted) {
      // Show access denied and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied. Admin privileges required.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // Load dashboard data
    provider.loadKPIStats();
    provider.loadUsers(refresh: true);
    provider.loadFlaggedContent();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        if (provider.state.isLoading && !provider.state.isAdmin) {
          return _buildLoadingScreen();
        }

        return AdminScaffold(
          title: _getTabTitle(_selectedIndex),
          selectedIndex: _selectedIndex,
          onNavigationChanged: (index) {
            setState(() => _selectedIndex = index);
          },
          body: _screens[_selectedIndex],
        );
      },
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Users';
      case 2:
        return 'Verification';
      case 3:
        return 'Moderation';
      case 4:
        return 'Analytics';
      case 5:
        return 'Data';
      case 6:
        return 'Support';
      case 7:
        return 'Courses';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildLoadingScreen() {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? AppTheme.darkPrimaryGradient
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isDark
                                      ? AppTheme.darkPrimary
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Admin Panel',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifying access...',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            // Animated dots loading indicator
            SizedBox(
              width: 60,
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 600 + (index * 200)),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? AppTheme.darkPrimary
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.3 + (value * 0.7)),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard Home Tab - KPI Overview
class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab();

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        final stats = provider.state.kpiStats;
        final isLoading = stats == null;

        return RefreshIndicator(
          onRefresh: () async {
            await provider.loadKPIStats();
            await provider.loadUsers(refresh: true);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome header
                _buildWelcomeHeader(isDark),
                const SizedBox(height: 24),

                // KPI Cards
                Text(
                  'Platform Overview',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                _buildKPIGrid(stats, isLoading, isDark),
                const SizedBox(height: 32),

                // Quick Actions
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickActions(context, isDark, provider),
                const SizedBox(height: 32),

                // Recent Users Preview - Real-time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecentActivityStream(isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeHeader(bool isDark) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.darkPrimaryGradient
            : AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                .withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, Admin! 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(now),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid(
    Map<String, dynamic>? stats,
    bool isLoading,
    bool isDark,
  ) {
    final totalUsers = stats?['totalUsers'] ?? 0;
    final totalTeachers = stats?['totalTeachers'] ?? 0;
    final pendingTeachers = stats?['pendingTeachers'] ?? 0;
    final totalCourses = stats?['totalCourses'] ?? 0;
    final totalRevenue = (stats?['totalRevenue'] ?? 0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Responsive: 2x2 on larger screens, 1 column on small screens
        final crossAxisCount = screenWidth >= 500 ? 2 : 1;
        final spacing = 16.0;

        final tiles = [
          _buildSquareTile(
            icon: Icons.people_rounded,
            count: isLoading ? '...' : '$totalUsers',
            label: 'Total Users',
            color: const Color(0xFF4CAF50),
            isDark: isDark,
            onTap: () {
              final dashboardState = context
                  .findAncestorStateOfType<_AdminDashboardScreenState>();
              dashboardState?.navigateToTab(1);
            },
          ),
          _buildSquareTile(
            icon: Icons.school_rounded,
            count: isLoading ? '...' : '$totalTeachers',
            label: 'Teachers',
            color: const Color(0xFF2196F3),
            isDark: isDark,
            badge: pendingTeachers > 0 ? '$pendingTeachers pending' : null,
            onTap: () {
              final dashboardState = context
                  .findAncestorStateOfType<_AdminDashboardScreenState>();
              dashboardState?.navigateToTab(2);
            },
          ),
          _buildSquareTile(
            icon: Icons.menu_book_rounded,
            count: isLoading ? '...' : '$totalCourses',
            label: 'Courses',
            color: const Color(0xFF9C27B0),
            isDark: isDark,
            onTap: () {
              final dashboardState = context
                  .findAncestorStateOfType<_AdminDashboardScreenState>();
              dashboardState?.navigateToTab(7);
            },
          ),
          _buildSquareTile(
            icon: Icons.attach_money_rounded,
            count: isLoading ? '...' : '\$${totalRevenue.toInt()}',
            label: 'Revenue',
            color: const Color(0xFFFF9800),
            isDark: isDark,
            onTap: () {
              final dashboardState = context
                  .findAncestorStateOfType<_AdminDashboardScreenState>();
              dashboardState?.navigateToTab(4);
            },
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.0, // Square tiles
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) => tiles[index],
        );
      },
    );
  }

  Widget _buildSquareTile({
    required IconData icon,
    required String count,
    required String label,
    required Color color,
    required bool isDark,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background decoration
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      // Count and Label
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count,
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: isDark
                                    ? AppTheme.darkTextTertiary
                                    : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Badge
                if (badge != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    bool isDark,
    AdminProvider provider,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _QuickActionButton(
          icon: Icons.person_add_rounded,
          label: 'Verify Teachers',
          color: isDark ? AppTheme.darkSuccess : AppTheme.success,
          onTap: () {
            // Navigate to Verification tab (index 2)
            final dashboardState = context
                .findAncestorStateOfType<_AdminDashboardScreenState>();
            if (dashboardState != null) {
              dashboardState.navigateToTab(2);
            }
          },
        ),
        _QuickActionButton(
          icon: Icons.report_rounded,
          label: 'Review Reports',
          color: isDark ? AppTheme.darkError : AppTheme.error,
          badge: provider.state.reportedContent.isNotEmpty
              ? '${provider.state.reportedContent.length}'
              : null,
          onTap: () {
            // Navigate to Moderation tab (index 3)
            final dashboardState = context
                .findAncestorStateOfType<_AdminDashboardScreenState>();
            if (dashboardState != null) {
              dashboardState.navigateToTab(3);
            }
          },
        ),
        _QuickActionButton(
          icon: Icons.download_rounded,
          label: 'Export Data',
          color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
          onTap: () {
            // Navigate to Data tab (index 5)
            final dashboardState = context
                .findAncestorStateOfType<_AdminDashboardScreenState>();
            if (dashboardState != null) {
              dashboardState.navigateToTab(5);
            }
          },
        ),
        _QuickActionButton(
          icon: Icons.analytics_rounded,
          label: 'View Analytics',
          color: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
          onTap: () {
            // Navigate to Analytics tab (index 4)
            final dashboardState = context
                .findAncestorStateOfType<_AdminDashboardScreenState>();
            if (dashboardState != null) {
              dashboardState.navigateToTab(4);
            }
          },
        ),
        _QuickActionButton(
          icon: Icons.support_agent_rounded,
          label: 'Support Tickets',
          color: Colors.teal,
          onTap: () {
            // Navigate to Support tab (index 6)
            final dashboardState = context
                .findAncestorStateOfType<_AdminDashboardScreenState>();
            if (dashboardState != null) {
              dashboardState.navigateToTab(6);
            }
          },
        ),
        _QuickActionButton(
          icon: Icons.library_books_rounded,
          label: 'Manage Courses',
          color: Colors.deepPurple,
          onTap: () {
            // Navigate to Courses tab (index 7)
            final dashboardState = context
                .findAncestorStateOfType<_AdminDashboardScreenState>();
            if (dashboardState != null) {
              dashboardState.navigateToTab(7);
            }
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivityStream(bool isDark) {
    final database = FirebaseDatabase.instance;

    return StreamBuilder<DatabaseEvent>(
      stream: database
          .ref('student')
          .orderByChild('createdAt')
          .limitToLast(10)
          .onValue,
      builder: (context, studentSnapshot) {
        return StreamBuilder<DatabaseEvent>(
          stream: database
              .ref('teacher')
              .orderByChild('createdAt')
              .limitToLast(10)
              .onValue,
          builder: (context, teacherSnapshot) {
            // Combine users from both streams
            List<Map<String, dynamic>> allUsers = [];

            if (studentSnapshot.hasData &&
                studentSnapshot.data!.snapshot.value != null) {
              final studentsMap =
                  studentSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              studentsMap.forEach((key, value) {
                if (value is Map) {
                  allUsers.add({
                    'uid': key,
                    'name': value['name'] ?? value['displayName'] ?? 'Student',
                    'email': value['email'] ?? '',
                    'role': 'student',
                    'createdAt': value['createdAt'],
                    'photoUrl': value['photoUrl'],
                  });
                }
              });
            }

            if (teacherSnapshot.hasData &&
                teacherSnapshot.data!.snapshot.value != null) {
              final teachersMap =
                  teacherSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              teachersMap.forEach((key, value) {
                if (value is Map) {
                  allUsers.add({
                    'uid': key,
                    'name': value['name'] ?? value['displayName'] ?? 'Teacher',
                    'email': value['email'] ?? '',
                    'role': 'teacher',
                    'createdAt': value['createdAt'],
                    'photoUrl': value['photoUrl'],
                  });
                }
              });
            }

            // Sort by createdAt descending and take 5 most recent
            allUsers.sort((a, b) {
              final aTime = a['createdAt'] ?? 0;
              final bTime = b['createdAt'] ?? 0;
              if (aTime is int && bTime is int) {
                return bTime.compareTo(aTime);
              }
              return 0;
            });

            final recentUsers = allUsers.take(5).toList();

            if (studentSnapshot.connectionState == ConnectionState.waiting &&
                teacherSnapshot.connectionState == ConnectionState.waiting) {
              return Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: isDark
                        ? AppTheme.darkPrimary
                        : AppTheme.primaryColor,
                  ),
                ),
              );
            }

            if (recentUsers.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Center(
                  child: Text(
                    'No users yet',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentUsers.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                ),
                itemBuilder: (context, index) {
                  final user = recentUsers[index];
                  final photoUrl = user['photoUrl'] as String?;
                  final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (isDark
                                  ? AppTheme.darkPrimary
                                  : AppTheme.primaryColor)
                              .withOpacity(0.1),
                      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              (user['name'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkPrimary
                                    : AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    title: Text(
                      user['name'] ?? 'Unknown',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      user['email'] ?? '',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: user['role'] == 'teacher'
                            ? (isDark
                                      ? AppTheme.darkAccent
                                      : AppTheme.accentColor)
                                  .withOpacity(0.1)
                            : (isDark
                                      ? AppTheme.darkPrimary
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (user['role'] ?? 'User').toString().toUpperCase(),
                        style: TextStyle(
                          color: user['role'] == 'teacher'
                              ? (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.accentColor)
                              : (isDark
                                    ? AppTheme.darkPrimary
                                    : AppTheme.primaryColor),
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Quick Action Button Widget
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (badge != null && badge != '0')
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkError : AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
