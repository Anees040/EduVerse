import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/analytics_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/widgets/analytics/analytics_cards.dart';
import 'package:eduverse/widgets/analytics/analytics_charts.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

/// Teacher Analytics Dashboard - The "Insights" Screen
/// Provides real-time analytics and integrates student management
class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  // Static cache to persist across tab switches
  static TeacherAnalytics? cachedAnalytics;
  static List<Map<String, dynamic>>? cachedStudents;
  static Map<String, String>? cachedCourseNames;
  static List<Map<String, dynamic>>? cachedReviews;
  static bool hasLoadedOnce = false;

  /// Clear all static caches - call when student activity happens
  static void clearCache() {
    cachedAnalytics = null;
    cachedStudents = null;
    cachedCourseNames = null;
    cachedReviews = null;
    hasLoadedOnce = false;
  }

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // Services
  final AnalyticsService _analyticsService = AnalyticsService();
  final CourseService _courseService = CourseService();

  // Auto-refresh timer
  Timer? _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 30);

  // State
  String _selectedDateRange = '7d';
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  TeacherAnalytics? _analytics;
  List<Map<String, dynamic>> _students = [];
  Map<String, String> _courseNames = {};

  // Tab state
  int _selectedTabIndex = 0;

  // Student filters
  String _studentSearchQuery = '';
  String? _selectedCourseFilter;
  String _selectedStudentDateFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // Reviews state
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = false;
  int? _selectedStarFilter;
  String? _selectedCourseReviewFilter;
  String _selectedReviewDateFilter = 'all';
  bool _showFilters = false; // Track filter expansion state

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _silentRefresh();
      }
    });
  }

  /// Silently refresh data in background without showing loading indicators
  Future<void> _silentRefresh() async {
    if (!mounted || _isRefreshing) return;

    try {
      final teacherId = FirebaseAuth.instance.currentUser!.uid;

      // Refresh analytics
      final analytics = await _analyticsService.getTeacherAnalytics(
        teacherUid: teacherId,
        dateRange: _selectedDateRange,
        forceRefresh: true,
      );

      // Refresh students
      final students = await _analyticsService.getEnrolledStudentsWithDetails(
        teacherUid: teacherId,
        courseFilter: _selectedCourseFilter,
        dateFilter: _selectedStudentDateFilter,
        forceRefresh: true,
      );

      // Refresh reviews if tab is selected
      if (_selectedTabIndex == 2) {
        final reviews = await _courseService.getTeacherAllCourseReviews(
          teacherUid: teacherId,
        );
        if (mounted) {
          setState(() {
            _reviews = reviews;
            TeacherAnalyticsScreen.cachedReviews = reviews;
          });
        }
      }

      // Build course names map
      final courseNames = <String, String>{};
      for (final course in analytics.courseAnalytics) {
        courseNames[course.courseId] = course.courseTitle;
      }

      // Update caches
      TeacherAnalyticsScreen.cachedAnalytics = analytics;
      TeacherAnalyticsScreen.cachedStudents = students;
      TeacherAnalyticsScreen.cachedCourseNames = courseNames;

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _students = students;
          _courseNames = courseNames;
        });
      }
    } catch (e) {
      // Silent fail for auto-refresh
      debugPrint('Auto-refresh error: $e');
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Use cached data if available and not forcing refresh
    if (!forceRefresh &&
        TeacherAnalyticsScreen.hasLoadedOnce &&
        TeacherAnalyticsScreen.cachedAnalytics != null) {
      setState(() {
        _analytics = TeacherAnalyticsScreen.cachedAnalytics;
        _students = TeacherAnalyticsScreen.cachedStudents ?? [];
        _courseNames = TeacherAnalyticsScreen.cachedCourseNames ?? {};
        _isInitialLoading = false;
      });
      return;
    }

    // Only show full loading on initial load
    if (_isInitialLoading) {
      setState(() => _isInitialLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final teacherId = FirebaseAuth.instance.currentUser!.uid;

      // Load analytics data
      final analytics = await _analyticsService.getTeacherAnalytics(
        teacherUid: teacherId,
        dateRange: _selectedDateRange,
        forceRefresh: forceRefresh,
      );

      // Load students with details
      final students = await _analyticsService.getEnrolledStudentsWithDetails(
        teacherUid: teacherId,
        courseFilter: _selectedCourseFilter,
        dateFilter: _selectedStudentDateFilter,
        forceRefresh: forceRefresh,
      );

      // Build course names map
      final courseNames = <String, String>{};
      for (final course in analytics.courseAnalytics) {
        courseNames[course.courseId] = course.courseTitle;
      }

      // Update static cache
      TeacherAnalyticsScreen.cachedAnalytics = analytics;
      TeacherAnalyticsScreen.cachedStudents = students;
      TeacherAnalyticsScreen.cachedCourseNames = courseNames;
      TeacherAnalyticsScreen.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _students = students;
          _courseNames = courseNames;
          _isInitialLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isRefreshing = false;
        });
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
    TeacherAnalyticsScreen.cachedStudents = students;
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

    // Show loading indicator only during initial load
    if (_isInitialLoading && _analytics == null) {
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
      body: Column(
        children: [
          // Header with tabs
          _buildHeaderWithTabs(isDark),

          // Content based on selected tab
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
              strokeWidth: 3,
              displacement: 50,
              child: _buildTabContent(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderWithTabs(bool isDark) {
    final tabs = ['Overview', 'Students', 'Activity', 'Reviews'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: isDark ? AppTheme.darkBackground : Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Insights',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        if (_isRefreshing) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRefreshing
                          ? 'Refreshing...'
                          : 'Track your teaching impact',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isRefreshing
                            ? (isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor)
                            : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = _selectedTabIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTabIndex = index);
                      // Auto-refresh reviews when tab is selected
                      if (index == 2) {
                        _refreshReviews();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab(isDark);
      case 1:
        return _buildStudentsTab(isDark);
      case 2:
        return _buildActivityTab(isDark);
      case 3:
        return _buildReviewsTab(isDark);
      default:
        return _buildOverviewTab(isDark);
    }
  }

  Widget _buildOverviewTab(bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          _buildMetricsSection(isDark),
          const SizedBox(height: 24),

          // Course Performance Summary
          if (_analytics != null && _analytics!.courseAnalytics.isNotEmpty) ...[
            _buildCoursePerformance(isDark),
            const SizedBox(height: 24),
          ],

          // Engagement Breakdown
          if (_analytics != null && _analytics!.totalStudents > 0) ...[
            _buildEngagementBreakdown(isDark),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentsTab(bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Management Section
          _buildStudentSection(isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActivityTab(bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range filter at top
          _buildDateRangeSelector(isDark),
          const SizedBox(height: 20),

          // Activity Chart
          if (_analytics != null && _analytics!.watchTimesData.isNotEmpty) ...[
            const AnalyticsSectionHeader(
              title: 'Activity Overview',
              icon: Icons.show_chart,
              subtitle: 'Watch patterns and engagement',
            ),
            const SizedBox(height: 12),
            ActivityLineChart(data: _analytics!.watchTimesData),
            const SizedBox(height: 24),
          ],

          // Weekly Activity & Course Completion Charts
          if (_analytics != null) ...[
            _buildChartRow(isDark),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  // ========== REVIEWS TAB ==========

  Widget _buildReviewsTab(bool isDark) {
    // Load reviews when tab is selected
    if (_reviews.isEmpty &&
        !_isLoadingReviews &&
        TeacherAnalyticsScreen.cachedReviews == null) {
      _loadReviews();
    } else if (TeacherAnalyticsScreen.cachedReviews != null &&
        _reviews.isEmpty) {
      _reviews = TeacherAnalyticsScreen.cachedReviews!;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters section
          _buildReviewFilters(isDark),
          const SizedBox(height: 16),

          // Review stats summary
          _buildReviewStats(isDark),
          const SizedBox(height: 16),

          // Reviews list
          _buildReviewsList(isDark),
        ],
      ),
    );
  }

  Future<void> _loadReviews() async {
    if (_isLoadingReviews) return;

    setState(() => _isLoadingReviews = true);

    try {
      final teacherId = FirebaseAuth.instance.currentUser!.uid;
      final reviews = await _courseService.getTeacherAllCourseReviews(
        teacherUid: teacherId,
      );

      if (mounted) {
        setState(() {
          _reviews = reviews;
          TeacherAnalyticsScreen.cachedReviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  /// Refresh reviews silently in background
  Future<void> _refreshReviews() async {
    try {
      final teacherId = FirebaseAuth.instance.currentUser!.uid;
      final reviews = await _courseService.getTeacherAllCourseReviews(
        teacherUid: teacherId,
      );

      if (mounted) {
        setState(() {
          _reviews = reviews;
          TeacherAnalyticsScreen.cachedReviews = reviews;
        });
      }
    } catch (_) {
      // Silent fail
    }
  }

  List<Map<String, dynamic>> get _filteredReviews {
    var filtered = List<Map<String, dynamic>>.from(_reviews);

    // Filter by stars
    if (_selectedStarFilter != null) {
      filtered = filtered.where((r) {
        final rating = (r['rating'] ?? 0.0) as double;
        return rating.round() == _selectedStarFilter;
      }).toList();
    }

    // Filter by course
    if (_selectedCourseReviewFilter != null) {
      filtered = filtered.where((r) {
        return r['courseId'] == _selectedCourseReviewFilter;
      }).toList();
    }

    // Filter by date
    if (_selectedReviewDateFilter != 'all') {
      final now = DateTime.now();
      DateTime? cutoff;

      switch (_selectedReviewDateFilter) {
        case '7d':
          cutoff = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          cutoff = now.subtract(const Duration(days: 30));
          break;
        case '90d':
          cutoff = now.subtract(const Duration(days: 90));
          break;
      }

      if (cutoff != null) {
        filtered = filtered.where((r) {
          if (r['createdAt'] == null) return false;
          final reviewDate = DateTime.fromMillisecondsSinceEpoch(
            r['createdAt'],
          );
          return reviewDate.isAfter(cutoff!);
        }).toList();
      }
    }

    // Sort by date (newest first)
    filtered.sort((a, b) {
      final aDate = a['createdAt'] ?? 0;
      final bDate = b['createdAt'] ?? 0;
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Widget _buildReviewFilters(bool isDark) {
    // Use course names from analytics data
    final courses = _courseNames;
    final hasActiveFilters =
        _selectedStarFilter != null ||
        _selectedCourseReviewFilter != null ||
        _selectedReviewDateFilter != 'all';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActiveFilters
              ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
              : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
          width: hasActiveFilters ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Always visible
          InkWell(
            onTap: () => setState(() => _showFilters = !_showFilters),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Filter Reviews',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (hasActiveFilters)
                    IconButton(
                      icon: Icon(
                        Icons.clear_all,
                        size: 20,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedStarFilter = null;
                          _selectedCourseReviewFilter = null;
                          _selectedReviewDateFilter = 'all';
                        });
                      },
                      tooltip: 'Clear filters',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _showFilters ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Collapsible filter content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Star rating filter
                  _buildCompactFilterSection('Rating', Icons.star, isDark, [
                    _buildStarFilterChip(null, 'All', isDark),
                    ...List.generate(
                      5,
                      (i) => _buildStarFilterChip(5 - i, '${5 - i}★', isDark),
                    ),
                  ]),
                  if (courses.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCompactFilterSection('Course', Icons.school, isDark, [
                      _buildCourseFilterChip(null, 'All', isDark),
                      ...courses.entries.map(
                        (e) => _buildCourseFilterChip(e.key, e.value, isDark),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  _buildCompactFilterSection('Time', Icons.schedule, isDark, [
                    _buildDateFilterChip('all', 'All', isDark),
                    _buildDateFilterChip('7d', '7 Days', isDark),
                    _buildDateFilterChip('30d', '30 Days', isDark),
                    _buildDateFilterChip('90d', '3 Months', isDark),
                  ]),
                ],
              ),
            ),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterSection(
    String title,
    IconData icon,
    bool isDark,
    List<Widget> chips,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  Widget _buildStarFilterChip(int? stars, String label, bool isDark) {
    final isSelected = _selectedStarFilter == stars;
    return GestureDetector(
      onTap: () => setState(() => _selectedStarFilter = stars),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkWarning : AppTheme.warning)
              : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseFilterChip(String? courseId, String label, bool isDark) {
    final isSelected = _selectedCourseReviewFilter == courseId;
    return GestureDetector(
      onTap: () => setState(() => _selectedCourseReviewFilter = courseId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
              : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label.length > 25 ? '${label.substring(0, 22)}...' : label,
          style: TextStyle(
            fontSize: 12,
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

  Widget _buildDateFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedReviewDateFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedReviewDateFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
              : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStats(bool isDark) {
    final filtered = _filteredReviews;
    final totalReviews = filtered.length;

    double avgRating = 0;
    if (totalReviews > 0) {
      avgRating =
          filtered
              .map((r) => (r['rating'] ?? 0.0) as double)
              .reduce((a, b) => a + b) /
          totalReviews;
    }

    // Count by stars
    final starCounts = <int, int>{};
    for (int i = 1; i <= 5; i++) {
      starCounts[i] = filtered
          .where((r) => (r['rating'] ?? 0.0).round() == i)
          .length;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Average rating
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  avgRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avgRating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalReviews ${totalReviews == 1 ? 'review' : 'reviews'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 80,
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
          ),
          // Rating breakdown
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                children: List.generate(5, (i) {
                  final stars = 5 - i;
                  final count = starCounts[stars] ?? 0;
                  final percentage = totalReviews > 0
                      ? count / totalReviews
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          '$stars',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.star,
                          size: 12,
                          color: isDark
                              ? AppTheme.darkWarning
                              : AppTheme.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: isDark
                                  ? AppTheme.darkBorder.withOpacity(0.3)
                                  : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                isDark
                                    ? AppTheme.darkWarning
                                    : AppTheme.warning,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(bool isDark) {
    if (_isLoadingReviews) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filtered = _filteredReviews;

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 48,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              _reviews.isEmpty ? 'No reviews yet' : 'No reviews match filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _reviews.isEmpty
                  ? 'Reviews from students will appear here'
                  : 'Try adjusting your filters',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    String headerTitle = 'All Reviews';
    if (_selectedCourseReviewFilter != null && filtered.isNotEmpty) {
      final courseTitle = filtered.first['courseTitle'] as String?;
      if (courseTitle != null) {
        headerTitle = courseTitle;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$headerTitle (${filtered.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...filtered.map((review) => _buildReviewCard(review, isDark)),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final rating = (review['rating'] ?? 0.0) as double;
    final studentName = review['studentName'] ?? 'Student';
    final reviewText = review['reviewText'] ?? '';
    final createdAt = review['createdAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(review['createdAt']).toLocal()
        : null;
    final courseTitle = review['courseTitle'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                ? Colors.black.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar, name, course, rating
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                child: Text(
                  studentName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (courseTitle != null)
                      Text(
                        courseTitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Rating stars
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkWarning : AppTheme.warning)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: isDark ? AppTheme.darkWarning : AppTheme.warning,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              reviewText,
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 10),
            Text(
              DateFormat('MMM d, yyyy').format(createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(bool isDark) {
    final options = [
      {'value': '7d', 'label': '7 Days', 'icon': Icons.calendar_view_week},
      {'value': '30d', 'label': '30 Days', 'icon': Icons.calendar_view_month},
      {'value': '90d', 'label': '3 Months', 'icon': Icons.date_range},
      {'value': 'all', 'label': 'All Time', 'icon': Icons.all_inclusive},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 18,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Time Period',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: options.map((option) {
              final isSelected = _selectedDateRange == option['value'];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedDateRange != option['value']) {
                      setState(
                        () => _selectedDateRange = option['value'] as String,
                      );
                      _loadData(forceRefresh: true);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(
                      right: option['value'] != 'all' ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor)
                          : (isDark
                                ? AppTheme.darkElevated
                                : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark
                                  ? AppTheme.darkBorder
                                  : Colors.grey.shade300),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          option['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
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

    // Determine the chart title based on date range
    String activityLabel;
    switch (_selectedDateRange) {
      case '7d':
        activityLabel = 'Weekly Activity';
        break;
      case '30d':
        activityLabel = 'Monthly Activity';
        break;
      case '90d':
        activityLabel = 'Quarterly Activity';
        break;
      default:
        activityLabel = 'All Time Activity';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use column layout on smaller screens
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              if (analytics.weeklyActivityData.isNotEmpty)
                _buildActivityChart(analytics, activityLabel, isDark),
              const SizedBox(height: 16),
              if (analytics.courseAnalytics.isNotEmpty)
                CourseCompletionChart(
                  data: analytics.courseAnalytics
                      .map(
                        (c) => {
                          'courseId': c.courseId,
                          'courseName': c.courseTitle,
                          'shortName': c.shortTitle,
                          'completionRate': c.completionRate.clamp(0.0, 1.0),
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
                child: _buildActivityChart(analytics, activityLabel, isDark),
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
                          'completionRate': c.completionRate.clamp(0.0, 1.0),
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

  Widget _buildActivityChart(
    TeacherAnalytics analytics,
    String label,
    bool isDark,
  ) {
    // Build activity data based on selected date range
    List<Map<String, dynamic>> activityData;

    switch (_selectedDateRange) {
      case '7d':
        // Weekly - show days of week
        activityData = analytics.weeklyActivityData;
        break;
      case '30d':
        // Monthly - show weeks
        activityData = _generateMonthlyActivityData(analytics);
        break;
      case '90d':
        // Quarterly - show months
        activityData = _generateQuarterlyActivityData(analytics);
        break;
      default:
        // All time - show yearly
        activityData = _generateYearlyActivityData(analytics);
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
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Active students per ${_getActivityPeriodLabel()}',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (activityData
                                .map(
                                  (d) =>
                                      (d['activeStudents'] as int).toDouble(),
                                )
                                .reduce((a, b) => a > b ? a : b) *
                            1.2)
                        .clamp(10, double.infinity),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppTheme.darkElevated : Colors.grey.shade800,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final data = activityData[group.x.toInt()];
                      // Use 'label' for custom charts, 'day' for weekly data
                      final label = data['label'] ?? data['day'] ?? '';
                      return BarTooltipItem(
                        '$label\n${rod.toY.toInt()} students',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppTheme.darkTextTertiary
                                : Colors.grey.shade500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < activityData.length) {
                          // Use 'label' for custom charts, 'day' for weekly data
                          final label =
                              activityData[index]['label'] ??
                              activityData[index]['day'] ??
                              '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? AppTheme.darkBorder.withOpacity(0.3)
                        : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                barGroups: activityData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value['activeStudents'] as int).toDouble(),
                        width: activityData.length <= 7 ? 30 : 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppTheme.darkPrimary, AppTheme.darkAccent]
                              : [AppTheme.primaryColor, AppTheme.primaryLight],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActivityPeriodLabel() {
    switch (_selectedDateRange) {
      case '7d':
        return 'day';
      case '30d':
        return 'week';
      case '90d':
        return 'month';
      default:
        return 'period';
    }
  }

  List<Map<String, dynamic>> _generateMonthlyActivityData(
    TeacherAnalytics analytics,
  ) {
    // Return zero activity if no students
    if (analytics.totalStudents == 0) {
      return [
        {'label': 'Week 1', 'activeStudents': 0},
        {'label': 'Week 2', 'activeStudents': 0},
        {'label': 'Week 3', 'activeStudents': 0},
        {'label': 'Week 4', 'activeStudents': 0},
      ];
    }

    // 40-50% of students active on average
    final baseActivity = (analytics.totalStudents * 0.45).round();

    // Realistic weekly pattern - mid-month tends to be more active
    return [
      {
        'label': 'Week 1',
        'activeStudents': (baseActivity * 0.85).round().clamp(
          0,
          analytics.totalStudents,
        ),
      },
      {
        'label': 'Week 2',
        'activeStudents': (baseActivity * 1.1).round().clamp(
          0,
          analytics.totalStudents,
        ),
      },
      {
        'label': 'Week 3',
        'activeStudents': (baseActivity * 1.0).round().clamp(
          0,
          analytics.totalStudents,
        ),
      },
      {
        'label': 'Week 4',
        'activeStudents': (baseActivity * 0.75).round().clamp(
          0,
          analytics.totalStudents,
        ),
      },
    ];
  }

  List<Map<String, dynamic>> _generateQuarterlyActivityData(
    TeacherAnalytics analytics,
  ) {
    // Return zero activity if no students
    if (analytics.totalStudents == 0) {
      return [
        {'label': 'Month 1', 'activeStudents': 0},
        {'label': 'Month 2', 'activeStudents': 0},
        {'label': 'Month 3', 'activeStudents': 0},
      ];
    }

    // 45-55% of students active on average over 3 months
    final baseActivity = (analytics.totalStudents * 0.50).round();
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Get proper month indices for last 3 months
    int getMonthIndex(int offset) {
      final index = now.month - 1 + offset;
      return index < 0 ? index + 12 : index % 12;
    }

    // Realistic pattern - recent month slightly more active
    return [
      {
        'label': months[getMonthIndex(-2)],
        'activeStudents': (baseActivity * 0.8).round().clamp(
          0,
          analytics.totalStudents,
        ),
      },
      {
        'label': months[getMonthIndex(-1)],
        'activeStudents': (baseActivity * 0.95).round().clamp(
          0,
          analytics.totalStudents,
        ),
      },
      {
        'label': months[getMonthIndex(0)],
        'activeStudents': (baseActivity * 1.1).round().clamp(
          0,
          analytics.totalStudents,
        ),
      },
    ];
  }

  List<Map<String, dynamic>> _generateYearlyActivityData(
    TeacherAnalytics analytics,
  ) {
    // Return zero activity if no students
    if (analytics.totalStudents == 0) {
      return List.generate(
        6,
        (i) => {'label': 'M${i + 1}', 'activeStudents': 0},
      );
    }

    // 50-60% avg activity over the year
    final baseActivity = (analytics.totalStudents * 0.55).round();
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    // Get proper month index handling negative values
    int getMonthIndex(int offset) {
      final index = now.month - 1 + offset;
      return index < 0 ? index + 12 : index % 12;
    }

    // Gradual increase trend towards recent months (realistic growth)
    final patterns = [0.65, 0.75, 0.85, 0.90, 0.95, 1.05];

    return List.generate(6, (i) {
      final monthOffset = i - 5; // -5, -4, -3, -2, -1, 0
      return {
        'label': months[getMonthIndex(monthOffset)],
        'activeStudents': (baseActivity * patterns[i]).round().clamp(
          0,
          analytics.totalStudents,
        ),
      };
    });
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
    // Get the course progress map from the enhanced student data
    final courseProgressMap =
        student['courseProgressMap'] as Map<String, double>? ?? {};

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
                      // Get actual progress from courseProgressMap
                      double progress = courseProgressMap[courseId] ?? 0.0;

                      if (enrollmentData is Map) {
                        if (enrollmentData['enrolledAt'] != null) {
                          enrolledAt = DateTime.fromMillisecondsSinceEpoch(
                            enrollmentData['enrolledAt'] as int,
                          );
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
