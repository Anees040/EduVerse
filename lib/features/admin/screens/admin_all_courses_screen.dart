import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/models/course_model.dart';
import 'admin_course_detail_screen.dart';

/// Admin All Courses Screen - Course Content Management Module
/// Features: Pagination, filtering, search, audit logging
class AdminAllCoursesScreen extends StatefulWidget {
  final bool showBackButton;

  const AdminAllCoursesScreen({super.key, this.showBackButton = false});

  @override
  State<AdminAllCoursesScreen> createState() => _AdminAllCoursesScreenState();
}

class _AdminAllCoursesScreenState extends State<AdminAllCoursesScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Course> _courses = [];
  List<Course> _filteredCourses = [];
  final Map<String, String> _teacherNames = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // Filters
  String _categoryFilter = 'all';
  String _statusFilter = 'all'; // all, published, unpublished
  String _priceFilter = 'all'; // all, free, paid
  String _sortBy = 'newest'; // newest, oldest, title, enrolled, rating

  // Pagination
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreCourses();
      }
    }
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
    });

    try {
      final snapshot = await _db.child('courses').get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final courses = <Course>[];

        for (var entry in data.entries) {
          try {
            final course = Course.fromMap(
              entry.key.toString(),
              Map<dynamic, dynamic>.from(entry.value as Map),
            );
            courses.add(course);

            // Load teacher name if not cached
            if (!_teacherNames.containsKey(course.teacherUid)) {
              _loadTeacherName(course.teacherUid);
            }
          } catch (e) {
            debugPrint('Error parsing course ${entry.key}: $e');
          }
        }

        setState(() {
          _courses = courses;
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() {
          _courses = [];
          _filteredCourses = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeacherName(String teacherUid) async {
    try {
      final snapshot = await _db
          .child('teacher')
          .child(teacherUid)
          .child('name')
          .get();
      if (snapshot.exists) {
        setState(() {
          _teacherNames[teacherUid] = snapshot.value.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading teacher name: $e');
    }
  }

  Future<void> _loadMoreCourses() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    // Simulate pagination delay
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _currentPage++;
      _isLoadingMore = false;

      // Check if we've loaded all items
      if (_currentPage * _pageSize >= _filteredCourses.length) {
        _hasMore = false;
      }
    });
  }

  void _applyFilters() {
    var filtered = List<Course>.from(_courses);

    // Search filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.title.toLowerCase().contains(query) ||
            c.description.toLowerCase().contains(query) ||
            (_teacherNames[c.teacherUid]?.toLowerCase().contains(query) ??
                false);
      }).toList();
    }

    // Category filter
    if (_categoryFilter != 'all') {
      filtered = filtered
          .where(
            (c) => c.category.toLowerCase() == _categoryFilter.toLowerCase(),
          )
          .toList();
    }

    // Status filter
    if (_statusFilter == 'published') {
      filtered = filtered.where((c) => c.isPublished).toList();
    } else if (_statusFilter == 'unpublished') {
      filtered = filtered.where((c) => !c.isPublished).toList();
    }

    // Price filter
    if (_priceFilter == 'free') {
      filtered = filtered.where((c) => c.isFree).toList();
    } else if (_priceFilter == 'paid') {
      filtered = filtered.where((c) => !c.isFree).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'title':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'enrolled':
        filtered.sort((a, b) => b.enrolledCount.compareTo(a.enrolledCount));
        break;
      case 'rating':
        filtered.sort(
          (a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0),
        );
        break;
    }

    setState(() {
      _filteredCourses = filtered;
      _currentPage = 0;
      _hasMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    // Calculate displayed courses with pagination
    final displayCount = ((_currentPage + 1) * _pageSize).clamp(
      0,
      _filteredCourses.length,
    );
    final displayedCourses = _filteredCourses.take(displayCount).toList();

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppTheme.getTextPrimary(context),
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Course Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCourses),
        ],
      ),
      body: Column(
        children: [
          // Stats Header
          _buildStatsHeader(isDark),

          // Search Bar
          _buildSearchBar(isDark),

          // Filters
          _buildFilters(isDark),

          // Course List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedCourses.isEmpty
                ? _buildEmptyState(isDark)
                : _buildCourseList(displayedCourses, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(bool isDark) {
    final totalCourses = _courses.length;
    final publishedCount = _courses.where((c) => c.isPublished).length;
    final freeCount = _courses.where((c) => c.isFree).length;
    final totalEnrolled = _courses.fold<int>(
      0,
      (sum, c) => sum + c.enrolledCount,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatChip(
            'Total: $totalCourses',
            Icons.library_books,
            Colors.blue,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            'Published: $publishedCount',
            Icons.check_circle,
            Colors.green,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            'Free: $freeCount',
            Icons.card_giftcard,
            Colors.orange,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            'Enrolled: $totalEnrolled',
            Icons.people,
            Colors.purple,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search courses by title, description, or teacher...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? AppTheme.darkCard : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => _applyFilters(),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Category Filter
            _buildFilterDropdown(
              value: _categoryFilter,
              items: [
                'all',
                ...CourseCategories.categories.map((c) => c.toLowerCase()),
              ],
              label: 'Category',
              onChanged: (v) {
                setState(() => _categoryFilter = v!);
                _applyFilters();
              },
              isDark: isDark,
            ),
            const SizedBox(width: 8),

            // Status Filter
            _buildFilterDropdown(
              value: _statusFilter,
              items: ['all', 'published', 'unpublished'],
              label: 'Status',
              onChanged: (v) {
                setState(() => _statusFilter = v!);
                _applyFilters();
              },
              isDark: isDark,
            ),
            const SizedBox(width: 8),

            // Price Filter
            _buildFilterDropdown(
              value: _priceFilter,
              items: ['all', 'free', 'paid'],
              label: 'Price',
              onChanged: (v) {
                setState(() => _priceFilter = v!);
                _applyFilters();
              },
              isDark: isDark,
            ),
            const SizedBox(width: 8),

            // Sort
            _buildFilterDropdown(
              value: _sortBy,
              items: ['newest', 'oldest', 'title', 'enrolled', 'rating'],
              label: 'Sort',
              onChanged: (v) {
                setState(() => _sortBy = v!);
                _applyFilters();
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required void Function(String?) onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item == 'all' ? 'All ${label}s' : _formatLabel(item),
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppTheme.getTextSecondary(context),
          ),
          dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
        ),
      ),
    );
  }

  String _formatLabel(String value) {
    return value
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: AppTheme.getTextSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No courses found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList(List<Course> courses, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: courses.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= courses.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final course = courses[index];
        return _buildCourseCard(course, isDark);
      },
    );
  }

  Widget _buildCourseCard(Course course, bool isDark) {
    final teacherName = _teacherNames[course.teacherUid] ?? 'Loading...';
    final createdDate = DateFormat(
      'MMM d, yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(course.createdAt));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () => _openCourseDetail(course),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  course.imageUrl,
                  width: 100,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 100,
                    height: 75,
                    color: isDark
                        ? AppTheme.darkElevated
                        : Colors.grey.shade200,
                    child: Icon(
                      Icons.play_circle_outline,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Course Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: course.isPublished
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            course.isPublished ? 'Published' : 'Draft',
                            style: TextStyle(
                              color: course.isPublished
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Teacher
                    Text(
                      'By $teacherName',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Stats Row
                    Row(
                      children: [
                        _buildMiniStat(
                          Icons.people,
                          '${course.enrolledCount}',
                          isDark,
                        ),
                        const SizedBox(width: 12),
                        _buildMiniStat(
                          Icons.video_library,
                          '${course.videoCount}',
                          isDark,
                        ),
                        const SizedBox(width: 12),
                        if (course.averageRating != null &&
                            course.averageRating! > 0)
                          _buildMiniStat(
                            Icons.star,
                            course.averageRating!.toStringAsFixed(1),
                            isDark,
                            iconColor: Colors.amber,
                          ),
                        const Spacer(),
                        // Price/Free badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: course.isFree
                                ? Colors.green.withOpacity(0.1)
                                : (isDark
                                          ? AppTheme.darkAccent
                                          : AppTheme.primaryColor)
                                      .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            course.isFree
                                ? 'FREE'
                                : '\$${course.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: course.isFree
                                  ? Colors.green
                                  : (isDark
                                        ? AppTheme.darkAccent
                                        : AppTheme.primaryColor),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Category and Date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkElevated
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            course.category,
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          createdDate,
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppTheme.getTextSecondary(context),
                ),
                onSelected: (action) => _handleCourseAction(course, action),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Text('View Details'),
                  ),
                  PopupMenuItem(
                    value: course.isPublished ? 'unpublish' : 'publish',
                    child: Text(course.isPublished ? 'Unpublish' : 'Publish'),
                  ),
                  const PopupMenuItem(
                    value: 'flag',
                    child: Text('Flag for Review'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete Course',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    IconData icon,
    String value,
    bool isDark, {
    Color? iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: iconColor ?? AppTheme.getTextSecondary(context),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _openCourseDetail(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCourseDetailScreen(course: course),
      ),
    ).then((_) => _loadCourses());
  }

  Future<void> _handleCourseAction(Course course, String action) async {
    switch (action) {
      case 'view':
        _openCourseDetail(course);
        break;
      case 'publish':
      case 'unpublish':
        await _togglePublishStatus(course);
        break;
      case 'flag':
        await _flagCourse(course);
        break;
      case 'delete':
        await _deleteCourse(course);
        break;
    }
  }

  Future<void> _togglePublishStatus(Course course) async {
    final newStatus = !course.isPublished;

    try {
      await _db.child('courses').child(course.courseUid).update({
        'isPublished': newStatus,
        'updatedAt': ServerValue.timestamp,
      });

      // Also update in teacher's courses
      await _db
          .child('teacher')
          .child(course.teacherUid)
          .child('courses')
          .child(course.courseUid)
          .update({
            'isPublished': newStatus,
            'updatedAt': ServerValue.timestamp,
          });

      // Log action
      await _logAdminAction(
        action: newStatus ? 'publish_course' : 'unpublish_course',
        targetId: course.courseUid,
        details:
            'Course "${course.title}" ${newStatus ? 'published' : 'unpublished'}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course ${newStatus ? 'published' : 'unpublished'}'),
          ),
        );
        _loadCourses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _flagCourse(Course course) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _FlagReasonDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await _db.child('flagged_content').child(course.courseUid).set({
          'type': 'course',
          'courseUid': course.courseUid,
          'teacherUid': course.teacherUid,
          'title': course.title,
          'reason': reason,
          'flaggedAt': ServerValue.timestamp,
        });

        await _logAdminAction(
          action: 'flag_course',
          targetId: course.courseUid,
          details: 'Course "${course.title}" flagged: $reason',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course flagged for review')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteCourse(Course course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
          'Are you sure you want to delete "${course.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Archive before deleting
        final courseData =
            (await _db.child('courses').child(course.courseUid).get()).value;
        await _db.child('deleted_courses').child(course.courseUid).set({
          ...Map<String, dynamic>.from(courseData as Map),
          'deletedAt': ServerValue.timestamp,
        });

        // Delete from both locations
        await _db.child('courses').child(course.courseUid).remove();
        await _db
            .child('teacher')
            .child(course.teacherUid)
            .child('courses')
            .child(course.courseUid)
            .remove();

        await _logAdminAction(
          action: 'delete_course',
          targetId: course.courseUid,
          details: 'Course "${course.title}" deleted',
        );

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Course deleted')));
          _loadCourses();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _logAdminAction({
    required String action,
    required String targetId,
    required String details,
  }) async {
    await _db.child('admin_logs').push().set({
      'action': action,
      'targetId': targetId,
      'details': details,
      'timestamp': ServerValue.timestamp,
    });
  }
}

/// Dialog for entering flag reason
class _FlagReasonDialog extends StatefulWidget {
  @override
  State<_FlagReasonDialog> createState() => _FlagReasonDialogState();
}

class _FlagReasonDialogState extends State<_FlagReasonDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Flag Course'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Enter reason for flagging',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Flag'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
