import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/notification_service.dart';
import 'package:eduverse/services/data_preloader_service.dart';
import 'package:eduverse/views/notifications_screen.dart';
import 'package:eduverse/views/teacher/teacher_courses_screen.dart';
import 'package:eduverse/views/teacher/teacher_home_tab.dart';
import 'package:eduverse/views/teacher/teacher_profile_screen.dart';
import 'package:eduverse/views/teacher/teacher_analytics_screen.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/utils/route_transitions.dart';

class TeacherHomeScreen extends StatefulWidget {
  final String uid;
  final String role;
  const TeacherHomeScreen({super.key, required this.uid, required this.role});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;
  final NotificationService _notificationService = NotificationService();
  final DataPreloaderService _preloaderService = DataPreloaderService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  // GlobalKey to access TeacherAnalyticsScreen state for tab switching
  final GlobalKey<dynamic> _analyticsKey = GlobalKey();

  void _navigateToCoursesTab() {
    setState(() {
      _selectedIndex = 1; // Courses tab index
    });
  }

  /// Navigate to Insights tab and switch to Students sub-tab
  void _navigateToStudentsTab() {
    setState(() {
      _selectedIndex = 2; // Insights tab index
    });
    // Use post-frame callback to ensure the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = _analyticsKey.currentState;
      if (currentState != null) {
        currentState.switchToTab(1); // Students tab is index 1
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // Start preloading all data in parallel immediately
    _preloaderService.preloadTeacherData(uid: widget.uid, role: widget.role);

    _screens = [
      TeacherHomeTab(
        role: widget.role,
        uid: widget.uid,
        onSeeAllCourses: _navigateToCoursesTab,
        onSeeAllStudents:
            _navigateToStudentsTab, // Now navigates to Students sub-tab
      ),
      const TeacherCoursesScreen(),
      TeacherAnalyticsScreen(key: _analyticsKey),
      TeacherProfileScreen(uid: widget.uid, role: widget.role),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.school_rounded,
              color: isDark ? AppTheme.darkPrimary : Colors.white,
              size: 32,
            ),
            const SizedBox(width: 10),
            Text(
              "eduVerse",
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCountStream(_uid),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return SizedBox(
                width: 48,
                height: 48,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    Navigator.push(
                      context,
                      SlideAndFadeRoute(page: const NotificationsScreen()),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: isDark ? AppTheme.darkTextPrimary : Colors.white,
                        size: 26,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkError : Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.primaryColor,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.1),
              blurRadius: isDark ? 20 : 10,
              offset: const Offset(0, -2),
            ),
            if (isDark)
              BoxShadow(
                color: AppTheme.darkPrimary.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: isDark ? AppTheme.darkPrimary : Colors.white,
          unselectedItemColor: isDark
              ? AppTheme.darkTextTertiary
              : Colors.white54,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'Courses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
      // Use IndexedStack to keep all screens alive and avoid reloading
      body: IndexedStack(index: _selectedIndex, children: _screens),
    );
  }
}
