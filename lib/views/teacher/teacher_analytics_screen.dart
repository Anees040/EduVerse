import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/analytics_service.dart';
import 'package:eduverse/widgets/analytics/analytics_cards.dart';
import 'package:eduverse/widgets/analytics/analytics_charts.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

/// Teacher Analytics Dashboard - The "Insights" Screen
/// Provides real-time analytics and integrates student management
class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  // Services
  final AnalyticsService _analyticsService = AnalyticsService();

  // State
  String _selectedDateRange = '7d';
  bool _isLoading = true;
  TeacherAnalytics? _analytics;
  List<Map<String, dynamic>> _students = [];
  Map<String, String> _courseNames = {};

  // Student filters
  String _studentSearchQuery = '';
  String? _selectedCourseFilter;
  String _selectedStudentDateFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final teacherId = FirebaseAuth.instance.currentUser!.uid;

      // Load analytics data
      final analytics = await _analyticsService.getTeacherAnalytics(
        teacherUid: teacherId,
        dateRange: _selectedDateRange,
      );

      // Load students with details
      final students = await _analyticsService.getEnrolledStudentsWithDetails(
        teacherUid: teacherId,
        courseFilter: _selectedCourseFilter,
        dateFilter: _selectedStudentDateFilter,
      );

      // Build course names map
      final courseNames = <String, String>{};
      for (final course in analytics.courseAnalytics) {
        courseNames[course.courseId] = course.courseTitle;
      }

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _students = students;
          _courseNames = courseNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshStudents() async {
    final teacherId = FirebaseAuth.instance.currentUser!.uid;
    final students = await _analyticsService.getEnrolledStudentsWithDetails(
      teacherUid: teacherId,
      courseFilter: _selectedCourseFilter,
      dateFilter: _selectedStudentDateFilter,
    );
    if (mounted) {
      setState(() => _students = students);
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_studentSearchQuery.isEmpty) return _students;

    return _students.where((student) {
      final name = (student['name'] ?? '').toString().toLowerCase();
      final email = (student['email'] ?? '').toString().toLowerCase();
      final query = _studentSearchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = AppTheme.isDarkMode(context);

    // Show loading indicator during initial load
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey[100],
        body: const Center(
          child: EngagingLoadingIndicator(
            message: 'Loading Insights...',
            size: 70,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date filter
              _buildHeader(isDark),
              const SizedBox(height: 20),

              // Key Metrics Cards
              _buildMetricsSection(isDark),
              const SizedBox(height: 24),

              // Activity Chart
              if (_analytics != null &&
                  _analytics!.watchTimesData.isNotEmpty) ...[
                const AnalyticsSectionHeader(
                  title: 'Activity Overview',
                  icon: Icons.show_chart,
                  subtitle: 'Watch patterns and engagement',
                ),
                const SizedBox(height: 12),
                ActivityLineChart(data: _analytics!.watchTimesData),
                const SizedBox(height: 24),
              ],

              // Weekly Activity & Course Completion
              if (_analytics != null) _buildChartRow(isDark),
              const SizedBox(height: 24),

              // Course Performance Summary
              if (_analytics != null &&
                  _analytics!.courseAnalytics.isNotEmpty) ...[
                _buildCoursePerformance(isDark),
                const SizedBox(height: 24),
              ],

              // Engagement Breakdown
              if (_analytics != null && _analytics!.totalStudents > 0) ...[
                _buildEngagementBreakdown(isDark),
                const SizedBox(height: 32),
              ],

              // Student Management Section
              _buildStudentSection(isDark),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Course Performance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Track your teaching impact',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        DateRangeFilter(
          selectedValue: _selectedDateRange,
          options: const [
            {'value': '7d', 'label': 'Last 7 Days'},
            {'value': '30d', 'label': 'Last 30 Days'},
            {'value': '90d', 'label': 'Last 90 Days'},
            {'value': 'all', 'label': 'All Time'},
          ],
          onChanged: (value) {
            setState(() => _selectedDateRange = value);
            _loadData();
          },
        ),
      ],
    );
  }

  Widget _buildMetricsSection(bool isDark) {
    final analytics = _analytics ?? TeacherAnalytics.empty();

    return Column(
      children: [
        // First row - 2 cards
        Row(
          children: [
            Expanded(
              child: AnalyticsCard(
                title: 'Active Students',
                value: analytics.activeStudents.toString(),
                subtitle: 'of ${analytics.totalStudents} enrolled',
                icon: Icons.people,
                iconColor: isDark
                    ? AppTheme.darkPrimary
                    : AppTheme.primaryColor,
                trend: analytics.activeStudentsTrend,
                isPositiveTrend: analytics.activeStudentsTrend >= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnalyticsCard(
                title: 'Avg. Watch Time',
                value: analytics.formattedWatchTime,
                subtitle: 'Per student session',
                icon: Icons.timer,
                iconColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                trend: analytics.avgWatchTimeMinutes > 20 ? 5.2 : -2.1,
                isPositiveTrend: analytics.avgWatchTimeMinutes > 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row - completion rate and new enrollments
        Row(
          children: [
            Expanded(
              child: CompletionRateCard(
                title: 'Completion Rate',
                rate: analytics.overallCompletionRate.clamp(0.0, 1.0),
                subtitle:
                    '${(analytics.overallCompletionRate * analytics.totalStudents).round()} completed',
                trend: analytics.completionTrend,
                isPositiveTrend: analytics.completionTrend >= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnalyticsCard(
                title: 'New This Week',
                value: analytics.newEnrollmentsThisWeek.toString(),
                subtitle: '${analytics.newEnrollmentsThisMonth} this month',
                icon: Icons.person_add,
                iconColor: isDark ? AppTheme.darkSuccess : AppTheme.success,
                trend: analytics.enrollmentTrend,
                isPositiveTrend: analytics.enrollmentTrend >= 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartRow(bool isDark) {
    final analytics = _analytics!;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use column layout on smaller screens
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              if (analytics.weeklyActivityData.isNotEmpty)
                WeeklyActivityChart(data: analytics.weeklyActivityData),
              const SizedBox(height: 16),
              if (analytics.courseAnalytics.isNotEmpty)
                CourseCompletionChart(
                  data: analytics.courseAnalytics
                      .map(
                        (c) => {
                          'courseId': c.courseId,
                          'courseName': c.courseTitle,
                          'shortName': c.shortTitle,
                          'completionRate': c.completionRate,
                          'enrolledCount': c.enrolledCount,
                          'completedCount': c.completedCount,
                        },
                      )
                      .toList(),
                ),
            ],
          );
        }

        // Row layout for larger screens
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (analytics.weeklyActivityData.isNotEmpty)
              Expanded(
                child: WeeklyActivityChart(data: analytics.weeklyActivityData),
              ),
            const SizedBox(width: 16),
            if (analytics.courseAnalytics.isNotEmpty)
              Expanded(
                child: CourseCompletionChart(
                  data: analytics.courseAnalytics
                      .map(
                        (c) => {
                          'courseId': c.courseId,
                          'courseName': c.courseTitle,
                          'shortName': c.shortTitle,
                          'completionRate': c.completionRate,
                          'enrolledCount': c.enrolledCount,
                          'completedCount': c.completedCount,
                        },
                      )
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCoursePerformance(bool isDark) {
    final courses = _analytics!.courseAnalytics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Course Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...courses.map((course) => _buildCourseRow(course, isDark)),
        ],
      ),
    );
  }

  Widget _buildCourseRow(CourseAnalytics course, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              course.courseTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: course.completionRate.clamp(0.0, 1.0),
                    backgroundColor: isDark
                        ? AppTheme.darkBorder
                        : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getCompletionColor(course.completionRate, isDark),
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(course.completionRate * 100).toInt()}% · ${course.enrolledCount} students',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCompletionColor(double rate, bool isDark) {
    if (rate >= 0.75) return isDark ? AppTheme.darkSuccess : AppTheme.success;
    if (rate >= 0.5) return isDark ? AppTheme.darkAccent : AppTheme.accentColor;
    return isDark ? AppTheme.darkWarning : AppTheme.warning;
  }

  Widget _buildEngagementBreakdown(bool isDark) {
    final analytics = _analytics!;
    final total = analytics.totalStudents;
    if (total == 0) return const SizedBox.shrink();

    // Calculate engagement levels based on real progress
    int highlyEngaged = 0;
    int moderatelyEngaged = 0;
    int lowEngaged = 0;
    int inactive = 0;

    for (final studentData in analytics.studentAnalyticsMap.values) {
      final avgProgress = studentData.enrolledCourses.isNotEmpty
          ? studentData.totalProgress / studentData.enrolledCourses.length
          : 0.0;

      if (avgProgress >= 0.8) {
        highlyEngaged++;
      } else if (avgProgress >= 0.4) {
        moderatelyEngaged++;
      } else if (avgProgress >= 0.1) {
        lowEngaged++;
      } else {
        inactive++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart,
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Student Engagement Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              EngagementChip(
                label: 'Highly Engaged',
                count: highlyEngaged,
                color: isDark ? AppTheme.darkSuccess : AppTheme.success,
              ),
              EngagementChip(
                label: 'Moderate',
                count: moderatelyEngaged,
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
              ),
              EngagementChip(
                label: 'Low Engagement',
                count: lowEngaged,
                color: isDark ? AppTheme.darkWarning : AppTheme.warning,
              ),
              EngagementChip(
                label: 'Inactive',
                count: inactive,
                color: isDark ? AppTheme.darkError : AppTheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSection(bool isDark) {
    final displayStudents = _filteredStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        AnalyticsSectionHeader(
          title: 'Enrolled Students',
          icon: Icons.groups,
          subtitle: '${_students.length} total students',
          trailing: IconButton(
            icon: Icon(
              Icons.filter_list,
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
            onPressed: () => _showFilterDialog(isDark),
          ),
        ),
        const SizedBox(height: 12),

        // Active filters display
        if (_selectedCourseFilter != null ||
            _selectedStudentDateFilter != 'all')
          _buildActiveFilters(isDark),

        // Search bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _studentSearchQuery = value),
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search students by name or email...',
              hintStyle: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              suffixIcon: _studentSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : Colors.grey,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _studentSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppTheme.darkCard : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Student list
        if (displayStudents.isEmpty)
          _buildEmptyStudentState(isDark)
        else
          _buildStudentList(displayStudents, isDark),
      ],
    );
  }

  Widget _buildActiveFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_selectedCourseFilter != null)
            _buildFilterChip(
              label: _courseNames[_selectedCourseFilter] ?? 'Course',
              onRemove: () {
                setState(() => _selectedCourseFilter = null);
                _refreshStudents();
              },
              isDark: isDark,
            ),
          if (_selectedStudentDateFilter != 'all')
            _buildFilterChip(
              label: _getDateFilterLabel(_selectedStudentDateFilter),
              onRemove: () {
                setState(() => _selectedStudentDateFilter = 'all');
                _refreshStudents();
              },
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
            .withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getDateFilterLabel(String filter) {
    switch (filter) {
      case '7d':
        return 'Last 7 Days';
      case '30d':
        return 'Last 30 Days';
      case '90d':
        return 'Last 90 Days';
      default:
        return 'All Time';
    }
  }

  void _showFilterDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Students',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCourseFilter = null;
                            _selectedStudentDateFilter = 'all';
                          });
                          setState(() {});
                          _refreshStudents();
                        },
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkError : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Course filter
                  Text(
                    'By Course',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterOption(
                        label: 'All Courses',
                        isSelected: _selectedCourseFilter == null,
                        onTap: () {
                          setModalState(() => _selectedCourseFilter = null);
                          setState(() {});
                          _refreshStudents();
                        },
                        isDark: isDark,
                      ),
                      ..._courseNames.entries.map(
                        (entry) => _buildFilterOption(
                          label: entry.value,
                          isSelected: _selectedCourseFilter == entry.key,
                          onTap: () {
                            setModalState(
                              () => _selectedCourseFilter = entry.key,
                            );
                            setState(() {});
                            _refreshStudents();
                          },
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date filter
                  Text(
                    'By Enrollment Date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterOption(
                        label: 'All Time',
                        isSelected: _selectedStudentDateFilter == 'all',
                        onTap: () {
                          setModalState(
                            () => _selectedStudentDateFilter = 'all',
                          );
                          setState(() {});
                          _refreshStudents();
                        },
                        isDark: isDark,
                      ),
                      _buildFilterOption(
                        label: 'Last 7 Days',
                        isSelected: _selectedStudentDateFilter == '7d',
                        onTap: () {
                          setModalState(
                            () => _selectedStudentDateFilter = '7d',
                          );
                          setState(() {});
                          _refreshStudents();
                        },
                        isDark: isDark,
                      ),
                      _buildFilterOption(
                        label: 'Last 30 Days',
                        isSelected: _selectedStudentDateFilter == '30d',
                        onTap: () {
                          setModalState(
                            () => _selectedStudentDateFilter = '30d',
                          );
                          setState(() {});
                          _refreshStudents();
                        },
                        isDark: isDark,
                      ),
                      _buildFilterOption(
                        label: 'Last 90 Days',
                        isSelected: _selectedStudentDateFilter == '90d',
                        onTap: () {
                          setModalState(
                            () => _selectedStudentDateFilter = '90d',
                          );
                          setState(() {});
                          _refreshStudents();
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
              : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStudentState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: isDark ? AppTheme.darkTextTertiary : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _studentSearchQuery.isNotEmpty
                  ? 'No students match your search'
                  : 'No students enrolled yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _studentSearchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Students will appear here when they enroll in your courses',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList(List<Map<String, dynamic>> students, bool isDark) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(student, isDark);
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isDark) {
    final studentName = student['name'] ?? 'Unknown';
    final studentEmail = student['email'] ?? 'Unknown';
    final averageProgress =
        (student['averageProgress'] as num?)?.toDouble() ?? 0.0;
    final totalCourses = student['totalCoursesEnrolled'] as int? ?? 0;

    return GestureDetector(
      onTap: () => _showStudentDetails(student, isDark),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppTheme.darkBorder.withOpacity(0.5)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.15)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppTheme.darkAccent, AppTheme.darkPrimary]
                      : [AppTheme.primaryColor, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                            .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  studentName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          studentName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    studentEmail,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Course count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? AppTheme.darkPrimary
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$totalCourses ${totalCourses == 1 ? 'course' : 'courses'}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppTheme.darkPrimary
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Progress
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: averageProgress.clamp(0.0, 1.0),
                                  backgroundColor: isDark
                                      ? AppTheme.darkBorder
                                      : Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark
                                        ? AppTheme.darkAccent
                                        : AppTheme.accentColor,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(averageProgress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetails(Map<String, dynamic> student, bool isDark) {
    final studentName = student['name'] ?? 'Unknown';
    final studentEmail = student['email'] ?? 'Unknown';
    final enrolledCourses =
        student['enrolledCourses'] as Map<dynamic, dynamic>?;
    final averageProgress =
        (student['averageProgress'] as num?)?.toDouble() ?? 0.0;
    final earliestEnrollment = student['earliestEnrollment'] as int?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Student header
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [AppTheme.darkAccent, AppTheme.darkPrimary]
                                : [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryLight,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            studentName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              studentEmail,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats row
                  Row(
                    children: [
                      _buildStatItem(
                        label: 'Avg Progress',
                        value: '${(averageProgress * 100).toInt()}%',
                        icon: Icons.trending_up,
                        isDark: isDark,
                      ),
                      _buildStatItem(
                        label: 'Courses',
                        value: '${enrolledCourses?.length ?? 0}',
                        icon: Icons.school,
                        isDark: isDark,
                      ),
                      _buildStatItem(
                        label: 'Joined',
                        value: earliestEnrollment != null
                            ? DateFormat('MMM d').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                  earliestEnrollment,
                                ),
                              )
                            : 'N/A',
                        icon: Icons.calendar_today,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Enrolled courses
                  Text(
                    'Enrolled Courses',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (enrolledCourses != null && enrolledCourses.isNotEmpty)
                    ...enrolledCourses.entries.map((entry) {
                      final courseId = entry.key.toString();
                      final enrollmentData = entry.value;
                      final courseName =
                          _courseNames[courseId] ?? 'Unknown Course';

                      DateTime? enrolledAt;
                      double progress = 0;

                      if (enrollmentData is Map) {
                        if (enrollmentData['enrolledAt'] != null) {
                          enrolledAt = DateTime.fromMillisecondsSinceEpoch(
                            enrollmentData['enrolledAt'] as int,
                          );
                        }
                        if (enrollmentData['progress'] != null) {
                          progress = (enrollmentData['progress'] as num)
                              .toDouble();
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkElevated
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.book,
                                  size: 18,
                                  color: isDark
                                      ? AppTheme.darkPrimary
                                      : AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    courseName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      backgroundColor: isDark
                                          ? AppTheme.darkBorder
                                          : Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark
                                            ? AppTheme.darkAccent
                                            : AppTheme.accentColor,
                                      ),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppTheme.darkAccent
                                        : AppTheme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                            if (enrolledAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Enrolled: ${DateFormat('MMM d, yyyy').format(enrolledAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.darkTextTertiary
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  if (enrolledCourses == null || enrolledCourses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElevated
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'No courses enrolled',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
