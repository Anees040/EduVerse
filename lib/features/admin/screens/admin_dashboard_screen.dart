import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/kpi_card.dart';
import 'admin_users_screen.dart';
import 'admin_verification_queue_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_data_screen.dart';

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
                          color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
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
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                          color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
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

                // Recent Users Preview
                Text(
                  'Recent Users',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecentUsersPreview(provider, isDark),
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
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        int crossAxisCount;
        double childAspectRatio;
        double spacing;

        // More responsive breakpoints with better aspect ratios
        if (screenWidth >= 1200) {
          crossAxisCount = 4;
          childAspectRatio = 1.6;
          spacing = 16;
        } else if (screenWidth >= 900) {
          crossAxisCount = 4;
          childAspectRatio = 1.3;
          spacing = 12;
        } else if (screenWidth >= 600) {
          crossAxisCount = 2;
          childAspectRatio = 1.8;
          spacing = 16;
        } else if (screenWidth >= 400) {
          crossAxisCount = 2;
          childAspectRatio = 1.4;
          spacing = 12;
        } else {
          crossAxisCount = 1;
          childAspectRatio = 2.8;
          spacing = 12;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
          children: [
            KPICard(
              title: 'Total Users',
              value: isLoading ? '...' : '${stats!['totalUsers'] ?? 0}',
              icon: Icons.people_rounded,
              iconColor: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
              isLoading: isLoading,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
                dashboardState?.navigateToTab(1);
              },
            ),
            KPICard(
              title: 'Total Teachers',
              value: isLoading ? '...' : '${stats!['totalTeachers'] ?? 0}',
              subtitle: '${stats?['pendingTeachers'] ?? 0} pending',
              icon: Icons.school_rounded,
              iconColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
              isLoading: isLoading,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
                dashboardState?.navigateToTab(2);
              },
            ),
            KPICard(
              title: 'Total Courses',
              value: isLoading ? '...' : '${stats!['totalCourses'] ?? 0}',
              icon: Icons.menu_book_rounded,
              iconColor: isDark ? AppTheme.darkWarning : AppTheme.warning,
              isLoading: isLoading,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
                dashboardState?.navigateToTab(5);
              },
            ),
            KPICard(
              title: 'Total Revenue',
              value: isLoading
                  ? '...'
                  : currencyFormat.format(stats!['totalRevenue'] ?? 0),
              icon: Icons.attach_money_rounded,
              iconColor: isDark ? AppTheme.darkSuccess : AppTheme.success,
              isLoading: isLoading,
              onTap: () {
                final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
                dashboardState?.navigateToTab(4);
              },
            ),
          ],
        );
      },
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
            final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
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
            final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
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
            final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
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
            final dashboardState = context.findAncestorStateOfType<_AdminDashboardScreenState>();
            if (dashboardState != null) {
              dashboardState.navigateToTab(3);
            }
          },
        ),
      ],
    );
  }

  Widget _buildRecentUsersPreview(AdminProvider provider, bool isDark) {
    final users = provider.state.users.take(5).toList();

    if (users.isEmpty) {
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
        itemCount: users.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            leading: CircleAvatar(
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
            title: Text(
              user['name'] ?? 'Unknown',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user['role'] == 'teacher'
                    ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                          .withOpacity(0.1)
                    : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                          .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (user['role'] ?? 'User').toString().toUpperCase(),
                style: TextStyle(
                  color: user['role'] == 'teacher'
                      ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                      : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          );
        },
      ),
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
