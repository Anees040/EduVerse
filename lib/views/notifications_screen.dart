import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/notification_service.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/student/student_course_detail_screen.dart';
import 'package:eduverse/views/teacher/teacher_course_manage_screen.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final CourseService _courseService = CourseService();
  final UserService _userService = UserService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  bool? _isTeacher;

  // Filter state
  String _selectedFilter = 'all';

  // Filter options for teacher
  static const List<Map<String, dynamic>> _teacherFilters = [
    {'value': 'all', 'label': 'All', 'icon': Icons.all_inbox},
    {'value': 'enrollment', 'label': 'Enrollments', 'icon': Icons.person_add},
    {'value': 'qa_question', 'label': 'Questions', 'icon': Icons.help_outline},
    {'value': 'course_update', 'label': 'Updates', 'icon': Icons.update},
  ];

  // Filter options for student
  static const List<Map<String, dynamic>> _studentFilters = [
    {'value': 'all', 'label': 'All', 'icon': Icons.all_inbox},
    {'value': 'new_course', 'label': 'New Courses', 'icon': Icons.school},
    {'value': 'course_update', 'label': 'Videos', 'icon': Icons.video_library},
    {'value': 'qa_answer', 'label': 'Answers', 'icon': Icons.question_answer},
  ];

  @override
  void initState() {
    super.initState();
    _detectUserRole();
  }

  Future<void> _detectUserRole() async {
    try {
      final user = await _userService.getUser(uid: _uid, role: 'teacher');
      if (mounted) setState(() => _isTeacher = user != null);
    } catch (_) {
      if (mounted) setState(() => _isTeacher = false);
    }
  }

  List<Map<String, dynamic>> get _filters =>
      _isTeacher == true ? _teacherFilters : _studentFilters;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Notifications'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppTheme.getCardColor(context),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await _notificationService.markAllAsRead(_uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                    ),
                  );
                }
              } else if (value == 'clear_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.getCardColor(context),
                    title: Text(
                      'Clear All Notifications',
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    ),
                    content: Text(
                      'Are you sure you want to delete all notifications?',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: const Color(0xFFF5F5F5),
                          elevation: 6,
                          shadowColor: Colors.red.withOpacity(0.5),
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _notificationService.clearAllNotifications(_uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications cleared'),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(
                      Icons.done_all,
                      size: 20,
                      color: AppTheme.getTextSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mark all as read',
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear all', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(isDark),
          // Notifications list
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _notificationService.getNotificationsStream(_uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: EngagingLoadingIndicator(
                      message: 'Loading notifications...',
                      size: 60,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading notifications',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allNotifications = snapshot.data ?? [];

                // Apply filter
                final notifications = _selectedFilter == 'all'
                    ? allNotifications
                    : allNotifications
                          .where((n) => n['type'] == _selectedFilter)
                          .toList();

                if (allNotifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppTheme.darkPrimaryLight
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_none,
                            size: 64,
                            color:
                                (isDark
                                        ? AppTheme.darkPrimaryLight
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll see notifications here when there\'s activity',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Show empty state when filter returns no results
                if (notifications.isEmpty && allNotifications.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 64,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications match this filter',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedFilter = 'all'),
                          child: Text(
                            'Show all notifications',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationTile(notification);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter['value'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppTheme.darkTextSecondary
                                : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    Text(filter['label'] as String),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedFilter = filter['value'] as String);
                },
                selectedColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                backgroundColor: isDark
                    ? AppTheme.darkSurface
                    : Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide.none,
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final isDark = AppTheme.isDarkMode(context);
    final isRead = notification['isRead'] == true;
    final type = notification['type'] ?? 'general';
    final createdAt = notification['createdAt'] as int?;
    final timeAgo = createdAt != null ? _formatTimeAgo(createdAt) : '';
    final notificationId = notification['id'] as String?;

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'enrollment':
        icon = Icons.person_add;
        iconColor = Colors.green;
        break;
      case 'course_update':
        icon = Icons.video_library;
        iconColor = Colors.blue;
        break;
      case 'new_course':
        icon = Icons.school;
        iconColor = isDark ? AppTheme.darkAccentColor : AppTheme.accentColor;
        break;
      case 'qa_answer':
        icon = Icons.question_answer;
        iconColor = isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor;
        break;
      default:
        icon = Icons.notifications;
        iconColor = isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor;
    }

    return Dismissible(
      key: Key(
        notificationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        if (notificationId != null) {
          _notificationService.deleteNotification(_uid, notificationId);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: InkWell(
        onTap: () async {
          // Mark as read first
          if (!isRead && notificationId != null) {
            _notificationService.markAsRead(_uid, notificationId);
          }

          // Navigate only for QA answers, course updates, or QA questions with video context.
          final relatedCourseId = notification['relatedCourseId'] as String?;
          final relatedVideoId = notification['relatedVideoId'] as String?;
          final relatedVideoTimestamp =
              notification['relatedVideoTimestamp'] as int?;
          if (relatedCourseId != null &&
              (type == 'qa_answer' ||
                  type == 'course_update' ||
                  type == 'qa_question')) {
            // If this is a QA question notification OR course_update for a teacher,
            // open the teacher course manage screen.
            if ((type == 'qa_question' || type == 'course_update') &&
                _isTeacher == true) {
              try {
                final courseDetails = await _courseService.getCourseDetails(
                  courseUid: relatedCourseId,
                );
                if (courseDetails != null && mounted) {
                  int enrolledCount = 0;
                  final enrolled = courseDetails['enrolledStudents'];
                  if (enrolled is Map) enrolledCount = enrolled.length;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TeacherCourseManageScreen(
                        courseUid: relatedCourseId,
                        courseTitle: courseDetails['title'] ?? 'Course',
                        imageUrl: courseDetails['imageUrl'] ?? '',
                        description: courseDetails['description'] ?? '',
                        enrolledCount: enrolledCount,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to open manage screen: $e')),
                  );
                }
              }
              return;
            }
            try {
              // Fetch course details
              final courseDetails = await _courseService.getCourseDetails(
                courseUid: relatedCourseId,
              );
              if (courseDetails != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentCourseDetailScreen(
                      courseUid: relatedCourseId,
                      courseTitle: courseDetails['title'] ?? 'Course',
                      imageUrl: courseDetails['imageUrl'] ?? '',
                      description: courseDetails['description'] ?? '',
                      createdAt: courseDetails['createdAt'],
                      initialVideoId: relatedVideoId,
                      initialVideoTimestampSeconds: relatedVideoTimestamp,
                    ),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to open course: $e')),
                );
              }
            }
          }
        },
        child: Container(
          color: isRead
              ? AppTheme.getCardColor(context)
              : (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                    .withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkPrimaryLight
                                  : AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['message'] ?? '',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);

    if (diff.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
