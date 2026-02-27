import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Revenue dashboard with real Firebase data, time filters, per-course breakdown,
/// and enrollment-based analytics for teachers.
class TeacherRevenueDashboard extends StatefulWidget {
  const TeacherRevenueDashboard({super.key});

  @override
  State<TeacherRevenueDashboard> createState() =>
      _TeacherRevenueDashboardState();
}

class _TeacherRevenueDashboardState extends State<TeacherRevenueDashboard> {
  final _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;

  // Filter
  String _selectedPeriod = 'all'; // all, this_month, last_month, last_3
  static const _periodOptions = [
    {'value': 'all', 'label': 'All Time'},
    {'value': 'this_month', 'label': 'This Month'},
    {'value': 'last_month', 'label': 'Last Month'},
    {'value': 'last_3', 'label': 'Last 3 Months'},
  ];

  // Data
  double _totalRevenue = 0;
  double _filteredRevenue = 0;
  double _thisMonthRevenue = 0;
  double _lastMonthRevenue = 0;
  int _totalTransactions = 0;
  int _filteredTransactions = 0;
  int _totalEnrollments = 0;
  int _totalCourses = 0;
  int _publishedCourses = 0;
  int _totalStudents = 0;

  // Per-course data
  List<Map<String, dynamic>> _courseStats = [];
  Map<String, double> _monthlyRevenue = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Get teacher's courses
      final coursesSnap = await _db
          .child('courses')
          .orderByChild('teacherUid')
          .equalTo(uid)
          .get();

      double totalRevenue = 0;
      double thisMonthRev = 0;
      double lastMonthRev = 0;
      int totalTransactions = 0;
      int totalEnrollments = 0;
      int published = 0;
      final courseStatsMap = <String, Map<String, dynamic>>{};
      final studentSet = <String>{};
      final monthlyRev = <String, double>{};

      final now = DateTime.now();
      final thisMonthStart =
          DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      final lastMonthStart =
          DateTime(now.year, now.month - 1, 1).millisecondsSinceEpoch;

      if (coursesSnap.exists && coursesSnap.value != null) {
        final courses =
            Map<String, dynamic>.from(coursesSnap.value as Map);

        for (final e in courses.entries) {
          if (e.value is! Map) continue;
          final course = Map<String, dynamic>.from(e.value as Map);
          final courseId = e.key;
          final title = course['title'] as String? ?? 'Untitled';
          final price = (course['price'] as num?)?.toDouble() ?? 0;
          final isPublished = course['isPublished'] == true;
          if (isPublished) published++;

          int enrolledCount = 0;
          final enrolled = course['enrolledStudents'];
          if (enrolled is Map) {
            enrolledCount = enrolled.length;
            studentSet.addAll(enrolled.keys.cast<String>());
          }
          totalEnrollments += enrolledCount;

          // Calculate revenue from enrollments * price (for free courses = 0)
          double courseRev = enrolledCount > 0 ? enrolledCount * price : 0;

          // Reviews
          int reviewCount = 0;
          double avgRating = 0;
          if (course['reviews'] is Map) {
            final reviews =
                Map<String, dynamic>.from(course['reviews'] as Map);
            reviewCount = reviews.length;
            double totalRating = 0;
            for (final r in reviews.values) {
              if (r is Map) {
                totalRating += (r['rating'] as num?)?.toDouble() ?? 0;
              }
            }
            if (reviewCount > 0) avgRating = totalRating / reviewCount;
          }

          // Videos
          int videoCount = 0;
          if (course['videos'] is Map) {
            videoCount = (course['videos'] as Map).length;
          }

          courseStatsMap[courseId] = {
            'courseId': courseId,
            'title': title,
            'price': price,
            'revenue': courseRev,
            'enrolledCount': enrolledCount,
            'reviewCount': reviewCount,
            'avgRating': avgRating,
            'videoCount': videoCount,
            'isPublished': isPublished,
          };
        }
      }

      // Get payment data for real revenue tracking
      final paymentsSnap = await _db
          .child('payments')
          .orderByChild('teacherId')
          .equalTo(uid)
          .get();

      if (paymentsSnap.exists && paymentsSnap.value != null) {
        final payments =
            Map<String, dynamic>.from(paymentsSnap.value as Map);

        for (final entry in payments.entries) {
          if (entry.value is! Map) continue;
          final payment = Map<String, dynamic>.from(entry.value as Map);
          final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
          final timestamp = (payment['createdAt'] as num?)?.toInt() ?? 0;
          final courseId = payment['courseId'] as String? ?? '';

          totalRevenue += amount;
          totalTransactions++;

          if (timestamp >= thisMonthStart) {
            thisMonthRev += amount;
          } else if (timestamp >= lastMonthStart &&
              timestamp < thisMonthStart) {
            lastMonthRev += amount;
          }

          // Monthly breakdown
          if (timestamp > 0) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final key =
                '${date.year}-${date.month.toString().padLeft(2, '0')}';
            monthlyRev[key] = (monthlyRev[key] ?? 0) + amount;
          }

          // Update per-course revenue from payments (overrides estimate)
          if (courseStatsMap.containsKey(courseId)) {
            courseStatsMap[courseId]!['revenue'] =
                ((courseStatsMap[courseId]!['revenue'] as num?)?.toDouble() ??
                    0) +
                    amount;
          }
        }
      }

      // If no payments exist, use enrollment-based estimates
      if (totalTransactions == 0) {
        for (final cs in courseStatsMap.values) {
          totalRevenue += (cs['revenue'] as num?)?.toDouble() ?? 0;
        }
      }

      // Sort courses by revenue desc
      final sortedCourses = courseStatsMap.values.toList()
        ..sort((a, b) => ((b['revenue'] as num?) ?? 0)
            .compareTo((a['revenue'] as num?) ?? 0));

      if (mounted) {
        setState(() {
          _totalRevenue = totalRevenue;
          _thisMonthRevenue = thisMonthRev;
          _lastMonthRevenue = lastMonthRev;
          _totalTransactions = totalTransactions;
          _totalEnrollments = totalEnrollments;
          _totalCourses = courseStatsMap.length;
          _publishedCourses = published;
          _totalStudents = studentSet.length;
          _courseStats = sortedCourses;
          _monthlyRevenue = monthlyRev;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      debugPrint('Error loading revenue: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    final threeMonthsStart =
        DateTime(now.year, now.month - 3, 1).millisecondsSinceEpoch;

    switch (_selectedPeriod) {
      case 'this_month':
        _filteredRevenue = _thisMonthRevenue;
        _filteredTransactions = _totalTransactions; // simplified
        break;
      case 'last_month':
        _filteredRevenue = _lastMonthRevenue;
        _filteredTransactions = _totalTransactions;
        break;
      case 'last_3':
        double sum = 0;
        for (final entry in _monthlyRevenue.entries) {
          final parts = entry.key.split('-');
          if (parts.length == 2) {
            final dt = DateTime(
                int.parse(parts[0]), int.parse(parts[1]), 1);
            if (dt.millisecondsSinceEpoch >= threeMonthsStart) {
              sum += entry.value;
            }
          }
        }
        _filteredRevenue = sum;
        _filteredTransactions = _totalTransactions;
        break;
      default:
        _filteredRevenue = _totalRevenue;
        _filteredTransactions = _totalTransactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: AppTheme.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Revenue Dashboard',
            style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh,
                color: AppTheme.getTextSecondary(context)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time filter chips
                    _buildPeriodFilter(isDark, accentColor),
                    const SizedBox(height: 16),

                    // Revenue hero card
                    _buildRevenueHeroCard(isDark, accentColor),
                    const SizedBox(height: 16),

                    // Quick stats
                    _buildQuickStats(isDark),
                    const SizedBox(height: 20),

                    // Course performance header
                    _buildSectionHeader(
                        'Course Performance', Icons.bar_chart_rounded, isDark),
                    const SizedBox(height: 10),

                    // Course stats list
                    if (_courseStats.isEmpty)
                      _buildEmptyCourseState(isDark)
                    else
                      ..._courseStats
                          .take(10)
                          .map((c) => _buildCourseCard(c, isDark, accentColor)),

                    // Monthly trend
                    if (_monthlyRevenue.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                          'Monthly Trend', Icons.trending_up_rounded, isDark),
                      const SizedBox(height: 10),
                      _buildMonthlyTrend(isDark, accentColor),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ──── Period Filter ────

  Widget _buildPeriodFilter(bool isDark, Color accentColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _periodOptions.map((opt) {
          final isSelected = _selectedPeriod == opt['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt['label']!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.getTextPrimary(context))),
              selected: isSelected,
              selectedColor: accentColor,
              backgroundColor:
                  isDark ? AppTheme.darkCard : Colors.grey.shade100,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              onSelected: (_) {
                setState(() {
                  _selectedPeriod = opt['value']!;
                  _applyFilter();
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──── Revenue Hero Card ────

  Widget _buildRevenueHeroCard(bool isDark, Color accentColor) {
    final growth = _lastMonthRevenue > 0
        ? ((_thisMonthRevenue - _lastMonthRevenue) /
                _lastMonthRevenue *
                100)
            .toStringAsFixed(1)
        : '0.0';
    final growthVal = double.tryParse(growth) ?? 0;

    final periodLabel = _periodOptions
        .firstWhere((o) => o['value'] == _selectedPeriod)['label']!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: accentColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(periodLabel,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        growthVal >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: Colors.white,
                        size: 14),
                    const SizedBox(width: 4),
                    Text('${growthVal >= 0 ? '+' : ''}$growth%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('\$${_filteredRevenue.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            _selectedPeriod == 'all'
                ? 'Lifetime revenue'
                : 'This month: \$${_thisMonthRevenue.toStringAsFixed(2)}',
            style:
                TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _heroStat(Icons.receipt_long_rounded, '$_filteredTransactions',
                  'Transactions'),
              _heroStat(Icons.people_rounded, '$_totalStudents', 'Students'),
              _heroStat(Icons.school_rounded, '$_publishedCourses',
                  'Published'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ],
    );
  }

  // ──── Quick Stats ────

  Widget _buildQuickStats(bool isDark) {
    return Row(
      children: [
        _buildStatCard('$_totalEnrollments', 'Total\nEnrollments',
            Icons.people_alt_rounded, Colors.green, isDark),
        const SizedBox(width: 10),
        _buildStatCard('$_totalCourses', 'Total\nCourses',
            Icons.library_books_rounded, Colors.blue, isDark),
        const SizedBox(width: 10),
        _buildStatCard(
            '\$${_lastMonthRevenue.toStringAsFixed(0)}',
            'Last\nMonth',
            Icons.calendar_month_rounded,
            Colors.orange,
            isDark),
      ],
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: AppTheme.getTextSecondary(context), fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ──── Section Header ────

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon,
            color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }

  // ──── Course Card ────

  Widget _buildCourseCard(
      Map<String, dynamic> course, bool isDark, Color accentColor) {
    final title = course['title'] as String? ?? 'Untitled';
    final price = (course['price'] as num?)?.toDouble() ?? 0;
    final revenue = (course['revenue'] as num?)?.toDouble() ?? 0;
    final enrolled = (course['enrolledCount'] as num?)?.toInt() ?? 0;
    final reviews = (course['reviewCount'] as num?)?.toInt() ?? 0;
    final avgRating = (course['avgRating'] as num?)?.toDouble() ?? 0;
    final videos = (course['videoCount'] as num?)?.toInt() ?? 0;
    final isPublished = course['isPublished'] == true;
    final pct =
        _totalRevenue > 0 ? (revenue / _totalRevenue * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + badge
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isPublished
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPublished ? 'LIVE' : 'DRAFT',
                  style: TextStyle(
                      color: isPublished ? Colors.green : Colors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: [
              _miniStat(Icons.attach_money, '\$${revenue.toStringAsFixed(0)}',
                  Colors.green),
              _miniStat(Icons.people, '$enrolled', Colors.blue),
              _miniStat(Icons.star, avgRating.toStringAsFixed(1),
                  Colors.amber),
              _miniStat(Icons.play_circle, '$videos', Colors.red),
              _miniStat(Icons.rate_review, '$reviews', Colors.teal),
            ],
          ),
          if (revenue > 0) ...[
            const SizedBox(height: 8),
            // Revenue bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey.shade200,
                      color: accentColor,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (price > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Price: \$${price.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 3),
          Text(value,
              style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }

  // ──── Monthly Trend ────

  Widget _buildMonthlyTrend(bool isDark, Color accentColor) {
    final sortedMonths = _monthlyRevenue.keys.toList()..sort();
    final recentMonths = sortedMonths.length > 6
        ? sortedMonths.sublist(sortedMonths.length - 6)
        : sortedMonths;

    double maxVal = 1;
    for (final m in recentMonths) {
      final val = (_monthlyRevenue[m] ?? 0);
      if (val > maxVal) maxVal = val;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200),
      ),
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: recentMonths.map((month) {
            final val = _monthlyRevenue[month] ?? 0;
            final barHeight = (val / maxVal * 90).clamp(4.0, 90.0);
            String monthLabel;
            try {
              final parts = month.split('-');
              final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
              monthLabel = DateFormat('MMM').format(dt);
            } catch (_) {
              monthLabel = month;
            }

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('\$${val.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 9)),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 30,
                    height: val > 0 ? barHeight : 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.8),
                          accentColor.withOpacity(0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(monthLabel,
                      style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 10)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyCourseState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.school_outlined,
                size: 40,
                color: AppTheme.getTextSecondary(context).withOpacity(0.3)),
            const SizedBox(height: 8),
            Text('No courses yet',
                style: TextStyle(
                    color: AppTheme.getTextSecondary(context), fontSize: 14)),
            Text('Create your first course to start earning',
                style: TextStyle(
                    color:
                        AppTheme.getTextSecondary(context).withOpacity(0.6),
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
