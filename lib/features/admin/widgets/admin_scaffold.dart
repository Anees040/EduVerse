import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Responsive Admin Scaffold with side navigation drawer
/// Adapts to Desktop, Tablet, and Mobile screen sizes
class AdminScaffold extends StatefulWidget {
  final String title;
  final int selectedIndex;
  final Function(int) onNavigationChanged;
  final Widget body;
  final List<Widget>? actions;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onNavigationChanged,
    required this.body,
    this.actions,
  });

  @override
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  bool _isDrawerExpanded = true;

  // Navigation items
  static const List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard', 'Overview & KPIs'),
    _NavItem(Icons.people_rounded, 'Users', 'User Management'),
    _NavItem(Icons.shield_rounded, 'Moderation', 'Content Moderation'),
    _NavItem(Icons.analytics_rounded, 'Analytics', 'Reports & Charts'),
    _NavItem(Icons.backup_rounded, 'Data', 'Export & Backup'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 768 && screenWidth < 1200;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return _buildMobileLayout(isDark);
    } else if (isTablet) {
      return _buildTabletLayout(isDark);
    } else {
      return _buildDesktopLayout(isDark, isDesktop);
    }
  }

  /// Mobile layout with bottom navigation
  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _buildAppBar(isDark, showMenuButton: true),
      drawer: _buildDrawer(isDark),
      body: widget.body,
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  /// Tablet layout with collapsible rail
  Widget _buildTabletLayout(bool isDark) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Row(
        children: [
          _buildNavigationRail(isDark),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(isDark, showMenuButton: false),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop layout with expanded sidebar
  Widget _buildDesktopLayout(bool isDark, bool isWideDesktop) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isDrawerExpanded ? 260 : 80,
            child: _buildSidebar(isDark),
          ),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(isDark, showMenuButton: false),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build App Bar
  PreferredSizeWidget _buildAppBar(
    bool isDark, {
    required bool showMenuButton,
  }) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      elevation: 0,
      leading: showMenuButton
          ? Builder(
              builder: (context) => IconButton(
                icon: Icon(
                  Icons.menu_rounded,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : IconButton(
              icon: Icon(
                _isDrawerExpanded
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
              onPressed: () {
                setState(() => _isDrawerExpanded = !_isDrawerExpanded);
              },
            ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.darkPrimaryGradient
                  : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Admin Panel',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.title,
              style: TextStyle(
                color: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.actions != null) ...widget.actions!,
        const SizedBox(width: 8),
      ],
    );
  }

  /// Build Sidebar for Desktop
  Widget _buildSidebar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppTheme.darkPrimaryGradient
                        : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (_isDrawerExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    'EduVerse',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSelected = widget.selectedIndex == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onNavigationChanged(index),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: _isDrawerExpanded ? 16 : 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                        ? AppTheme.darkPrimary
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color:
                                      (isDark
                                              ? AppTheme.darkPrimary
                                              : AppTheme.primaryColor)
                                          .withOpacity(0.3),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected
                                  ? (isDark
                                        ? AppTheme.darkPrimary
                                        : AppTheme.primaryColor)
                                  : (isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary),
                              size: 24,
                            ),
                            if (_isDrawerExpanded) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDark
                                                  ? AppTheme.darkPrimary
                                                  : AppTheme.primaryColor)
                                            : (isDark
                                                  ? AppTheme.darkTextPrimary
                                                  : AppTheme.textPrimary),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      item.subtitle,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppTheme.darkTextTertiary
                                            : AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Logout button
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Handle logout
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isDrawerExpanded ? 16 : 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: isDark ? AppTheme.darkError : AppTheme.error,
                        size: 24,
                      ),
                      if (_isDrawerExpanded) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Exit Admin',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkError : AppTheme.error,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
    );
  }

  /// Build Navigation Rail for Tablet
  Widget _buildNavigationRail(bool isDark) {
    return NavigationRail(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: widget.onNavigationChanged,
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      destinations: _navItems.map((item) {
        return NavigationRailDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.icon),
          label: Text(item.label),
        );
      }).toList(),
      selectedIconTheme: IconThemeData(
        color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
      ),
      unselectedIconTheme: IconThemeData(
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
      ),
      selectedLabelTextStyle: TextStyle(
        color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
        fontSize: 11,
      ),
    );
  }

  /// Build Drawer for Mobile
  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.darkPrimaryGradient
                    : AppTheme.primaryGradient,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'EduVerse Management',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Navigation items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = widget.selectedIndex == index;

                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected
                          ? (isDark
                                ? AppTheme.darkPrimary
                                : AppTheme.primaryColor)
                          : (isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark
                                  ? AppTheme.darkPrimary
                                  : AppTheme.primaryColor)
                            : (isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor:
                        (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                            .withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      widget.onNavigationChanged(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            // Exit button
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: isDark ? AppTheme.darkError : AppTheme.error,
              ),
              title: Text(
                'Exit Admin',
                style: TextStyle(
                  color: isDark ? AppTheme.darkError : AppTheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build Bottom Navigation for Mobile
  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = widget.selectedIndex == index;

              return InkWell(
                onTap: () => widget.onNavigationChanged(index),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                                  ? AppTheme.darkPrimary
                                  : AppTheme.primaryColor)
                              .withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected
                            ? (isDark
                                  ? AppTheme.darkPrimary
                                  : AppTheme.primaryColor)
                            : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected
                              ? (isDark
                                    ? AppTheme.darkPrimary
                                    : AppTheme.primaryColor)
                              : (isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary),
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Navigation item model
class _NavItem {
  final IconData icon;
  final String label;
  final String subtitle;

  const _NavItem(this.icon, this.label, this.subtitle);
}
