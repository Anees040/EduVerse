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

  String _selectedFilter = 'all';

  static const List<Map<String, dynamic>> _teacherFilters = [
    {'value': 'all', 'label': 'All', 'icon': Icons.all_inbox},
    {'value': 'enrollment', 'label': 'Enrollments', 'icon': Icons.person_add},
    {'value': 'qa_question', 'label': 'Questions', 'icon': Icons.help_outline},
    {'value': 'announcement', 'label': 'Announce', 'icon': Icons.campaign},
    {'value': 'course_update', 'label': 'Updates', 'icon': Icons.update},
    {'value': 'maintenance', 'label': 'System', 'icon': Icons.engineering},
  ];

  static const List<Map<String, dynamic>> _studentFilters = [
    {'value': 'all', 'label': 'All', 'icon': Icons.all_inbox},
    {'value': 'new_course', 'label': 'Courses', 'icon': Icons.school},
    {'value': 'course_update', 'label': 'Videos', 'icon': Icons.video_library},
    {'value': 'qa_answer', 'label': 'Answers', 'icon': Icons.question_answer},
    {'value': 'support_reply', 'label': 'Support', 'icon': Icons.support_agent},
    {'value': 'maintenance', 'label': 'System', 'icon': Icons.engineering},
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

  // ──────────── Helpers ────────────

  bool _isNotificationRead(Map<String, dynamic> n) {
    return n['isRead'] == true || n['read'] == true;
  }

  int _getNotificationTime(Map<String, dynamic> n) {
    final t1 = n['createdAt'];
    final t2 = n['timestamp'];
    if (t1 is int) return t1;
    if (t1 is num) return t1.toInt();
    if (t2 is int) return t2;
    if (t2 is num) return t2.toInt();
    return 0;
  }

  Future<void> _markNotificationRead(Map<String, dynamic> notification) async {
    if (_isNotificationRead(notification)) return;
    final notificationId = notification['id'] as String?;
    if (notificationId == null) return;
    await _notificationService.markAsRead(_uid, notificationId);
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'enrollment':
        return Icons.person_add_rounded;
      case 'course_update':
        return Icons.video_library_rounded;
      case 'new_course':
        return Icons.school_rounded;
      case 'qa_answer':
        return Icons.question_answer_rounded;
      case 'qa_question':
        return Icons.help_outline_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'support_reply':
      case 'ticket_status':
        return Icons.support_agent_rounded;
      case 'maintenance':
        return Icons.engineering_rounded;
      case 'certificate':
        return Icons.workspace_premium_rounded;
      case 'moderation':
        return Icons.shield_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type) {
      case 'enrollment':
        return Colors.green;
      case 'course_update':
        return Colors.blue;
      case 'new_course':
        return isDark ? AppTheme.darkAccentColor : AppTheme.accentColor;
      case 'qa_answer':
      case 'qa_question':
        return isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor;
      case 'announcement':
        return Colors.deepPurple;
      case 'support_reply':
      case 'ticket_status':
        return Colors.cyan;
      case 'maintenance':
        return Colors.orange;
      case 'certificate':
        return Colors.amber.shade700;
      case 'moderation':
        return Colors.red;
      default:
        return isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'enrollment':
        return 'Enrollment';
      case 'course_update':
        return 'Video Update';
      case 'new_course':
        return 'New Course';
      case 'qa_answer':
        return 'Q&A Answer';
      case 'qa_question':
        return 'Question';
      case 'announcement':
        return 'Announcement';
      case 'support_reply':
        return 'Support';
      case 'ticket_status':
        return 'Ticket';
      case 'maintenance':
        return 'Maintenance';
      case 'certificate':
        return 'Certificate';
      case 'moderation':
        return 'Moderation';
      default:
        return 'Notification';
    }
  }

  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);
    if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // ──────────── Build ────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                    SnackBar(
                      content: const Text('All notifications marked as read'),
                      backgroundColor: accentColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } else if (value == 'clear_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.getCardColor(context),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text('Clear All Notifications',
                        style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.bold)),
                    content: Text(
                        'This will permanently delete all your notifications.',
                        style: TextStyle(
                            color: AppTheme.getTextSecondary(context))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: AppTheme.getTextSecondary(context))),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _notificationService.clearAllNotifications(_uid);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('All notifications cleared'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
                    Icon(Icons.done_all,
                        size: 20,
                        color: AppTheme.getTextSecondary(context)),
                    const SizedBox(width: 8),
                    Text('Mark all as read',
                        style: TextStyle(
                            color: AppTheme.getTextPrimary(context))),
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
          _buildFilterChips(isDark, accentColor),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _notificationService.getNotificationsStream(_uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: EngagingLoadingIndicator(
                          message: 'Loading notifications...', size: 60));
                }
                if (snapshot.hasError) return _buildErrorState();

                final allNotifications = snapshot.data ?? [];
                final notifications = _selectedFilter == 'all'
                    ? allNotifications
                    : allNotifications.where((n) {
                        final type = n['type'] ?? 'general';
                        if (_selectedFilter == 'support_reply') {
                          return type == 'support_reply' ||
                              type == 'ticket_status';
                        }
                        if (_selectedFilter == 'maintenance') {
                          return type == 'maintenance' ||
                              type == 'moderation' ||
                              type == 'certificate';
                        }
                        return type == _selectedFilter;
                      }).toList();

                if (allNotifications.isEmpty) {
                  return _buildEmptyState(accentColor);
                }
                if (notifications.isEmpty) {
                  return _buildNoFilterResultsState();
                }

                final unreadCount = notifications
                    .where((n) => !_isNotificationRead(n))
                    .length;

                return Column(
                  children: [
                    if (unreadCount > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        color: accentColor.withOpacity(0.06),
                        child: Text(
                          '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildNotificationCard(
                            notifications[index], isDark, accentColor),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── Filter Chips ────────────

  Widget _buildFilterChips(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter['value'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FilterChip(
                avatar: Icon(
                  filter['icon'] as IconData,
                  size: 15,
                  color: isSelected
                      ? Colors.white
                      : AppTheme.getTextSecondary(context),
                ),
                label: Text(filter['label'] as String),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _selectedFilter = filter['value'] as String),
                selectedColor: accentColor,
                backgroundColor:
                    isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppTheme.getTextPrimary(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: isSelected
                      ? BorderSide.none
                      : BorderSide(
                          color: isDark
                              ? AppTheme.darkBorderColor
                              : Colors.grey.shade300,
                          width: 0.5),
                ),
                showCheckmark: false,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ──────────── Notification Card ────────────

  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    bool isDark,
    Color accentColor,
  ) {
    final isRead = _isNotificationRead(notification);
    final type = notification['type'] as String? ?? 'general';
    final createdAt = _getNotificationTime(notification);
    final timeAgo = createdAt > 0 ? _formatTimeAgo(createdAt) : '';
    final notificationId = notification['id'] as String?;
    final title = notification['title'] as String? ?? 'Notification';
    final message = notification['message'] as String? ?? '';
    final typeColor = _getTypeColor(type, isDark);
    final typeIcon = _getTypeIcon(type);
    final typeLabel = _getTypeLabel(type);

    return Dismissible(
      key: Key(
          notificationId ?? DateTime.now().millisecondsSinceEpoch.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        if (notificationId != null) {
          _notificationService.deleteNotification(_uid, notificationId);
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text('Delete',
                style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () async {
          // ALWAYS mark as read on tap
          await _markNotificationRead(notification);
          if (!mounted) return;
          await _handleNotificationTap(notification);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead
                ? (isDark ? AppTheme.darkCard : Colors.white)
                : typeColor.withOpacity(isDark ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? (isDark
                      ? AppTheme.darkBorderColor
                      : Colors.grey.shade200)
                  : typeColor.withOpacity(0.2),
              width: isRead ? 0.5 : 1,
            ),
            boxShadow: isRead
                ? []
                : [
                    BoxShadow(
                      color: typeColor.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      typeColor.withOpacity(0.15),
                      typeColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(typeLabel,
                              style: TextStyle(
                                  color: typeColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3)),
                        ),
                        const Spacer(),
                        if (timeAgo.isNotEmpty)
                          Text(timeAgo,
                              style: TextStyle(
                                  color: AppTheme.getTextSecondary(context)
                                      .withOpacity(0.6),
                                  fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(title,
                        style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.getTextPrimary(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(message,
                        style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 12,
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4, left: 6),
                  decoration: BoxDecoration(
                    color: typeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: typeColor.withOpacity(0.4), blurRadius: 4),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────── Navigation ────────────

  Future<void> _handleNotificationTap(
      Map<String, dynamic> notification) async {
    final type = notification['type'] ?? 'general';
    final relatedCourseId =
        (notification['relatedCourseId'] ?? notification['courseId'])
            as String?;
    final relatedVideoId = notification['relatedVideoId'] as String?;
    final relatedVideoTimestamp =
        notification['relatedVideoTimestamp'] as int?;

    if (relatedCourseId == null) return;
    if (type != 'qa_answer' &&
        type != 'course_update' &&
        type != 'qa_question' &&
        type != 'enrollment' &&
        type != 'new_course' &&
        type != 'announcement') {
      return;
    }

    if ((type == 'qa_question' ||
            type == 'course_update' ||
            type == 'enrollment') &&
        _isTeacher == true) {
      try {
        final courseDetails =
            await _courseService.getCourseDetails(courseUid: relatedCourseId);
        if (courseDetails != null && mounted) {
          int enrolledCount = 0;
          final enrolled = courseDetails['enrolledStudents'];
          if (enrolled is Map) {
            enrolledCount = enrolled.length;
          }
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TeacherCourseManageScreen(
                      courseUid: relatedCourseId,
                      courseTitle: courseDetails['title'] ?? 'Course',
                      imageUrl: courseDetails['imageUrl'] ?? '',
                      description: courseDetails['description'] ?? '',
                      enrolledCount: enrolledCount)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to open course: $e')));
        }
      }
      return;
    }

    try {
      final courseDetails =
          await _courseService.getCourseDetails(courseUid: relatedCourseId);
      if (courseDetails != null && mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StudentCourseDetailScreen(
                    courseUid: relatedCourseId,
                    courseTitle: courseDetails['title'] ?? 'Course',
                    imageUrl: courseDetails['imageUrl'] ?? '',
                    description: courseDetails['description'] ?? '',
                    createdAt: courseDetails['createdAt'],
                    initialVideoId: relatedVideoId,
                    initialVideoTimestampSeconds: relatedVideoTimestamp)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to open course: $e')));
      }
    }
  }

  // ──────────── Empty States ────────────

  Widget _buildEmptyState(Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accentColor.withOpacity(0.12),
                  accentColor.withOpacity(0.05),
                ]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none_rounded,
                  size: 56, color: accentColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text('No notifications yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context))),
            const SizedBox(height: 8),
            Text(
              'You\'ll see activity notifications here\nwhen something happens',
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 14,
                  height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilterResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off_rounded,
                size: 56,
                color: AppTheme.getTextSecondary(context).withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No matching notifications',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextSecondary(context))),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _selectedFilter = 'all'),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Show all'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text('Error loading notifications',
              style:
                  TextStyle(color: AppTheme.getTextSecondary(context))),
        ],
      ),
    );
  }
}
