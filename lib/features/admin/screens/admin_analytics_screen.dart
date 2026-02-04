import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin Analytics Screen - Professional Platform Analytics with Real Data
/// Features: User Growth & Revenue Charts with Functional Filters
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // User Growth State
  String _userGrowthFilter = '12months';
  List<UserGrowthPoint> _userGrowthData = [];
  bool _isLoadingUserGrowth = true;
  int _totalSignups = 0;

  // Revenue State
  String _revenueFilter = 'year';
  List<RevenuePoint> _revenueData = [];
  bool _isLoadingRevenue = true;
  double _platformCommission = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserGrowthData();
    _loadRevenueData();
  }

  /// Load user growth data based on filter
  Future<void> _loadUserGrowthData() async {
    setState(() => _isLoadingUserGrowth = true);

    try {
      final now = DateTime.now();
      List<int> allTimestamps = [];

      // Fetch all users from both student and teacher nodes
      for (String role in ['student', 'teacher']) {
        final snapshot = await _db.child(role).get();
        if (snapshot.exists && snapshot.value != null) {
          final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
          for (var entry in usersMap.entries) {
            final user = Map<String, dynamic>.from(entry.value as Map);
            final createdAt = user['createdAt'];
            if (createdAt != null && createdAt is int) {
              allTimestamps.add(createdAt);
            }
          }
        }
      }

      List<UserGrowthPoint> growthData = [];
      int totalCount = 0;

      switch (_userGrowthFilter) {
        case 'all':
          // Group by year
          growthData = _groupByYear(allTimestamps, now);
          break;
        case '12months':
          // Group by month for last 12 months
          growthData = _groupByMonth(allTimestamps, now, 12);
          break;
        case '6months':
          // Group by month for last 6 months
          growthData = _groupByMonth(allTimestamps, now, 6);
          break;
        case '30days':
          // Group by day for last 30 days
          growthData = _groupByDay(allTimestamps, now, 30);
          break;
        case '7days':
          // Group by day for last 7 days
          growthData = _groupByDay(allTimestamps, now, 7);
          break;
      }

      totalCount = growthData.fold(0, (sum, point) => sum + point.count);

      setState(() {
        _userGrowthData = growthData;
        _totalSignups = totalCount;
        _isLoadingUserGrowth = false;
      });
    } catch (e) {
      debugPrint('Error loading user growth: $e');
      setState(() => _isLoadingUserGrowth = false);
    }
  }

  /// Group timestamps by year
  List<UserGrowthPoint> _groupByYear(List<int> timestamps, DateTime now) {
    if (timestamps.isEmpty) return [];

    // Find earliest year
    final earliestYear = timestamps
        .map((t) => DateTime.fromMillisecondsSinceEpoch(t).year)
        .reduce((a, b) => a < b ? a : b);

    List<UserGrowthPoint> data = [];
    for (int year = earliestYear; year <= now.year; year++) {
      final yearStart = DateTime(year, 1, 1).millisecondsSinceEpoch;
      final yearEnd = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
      final count = timestamps
          .where((t) => t >= yearStart && t < yearEnd)
          .length;
      data.add(
        UserGrowthPoint(
          label: year.toString(),
          count: count,
          date: DateTime(year, 1, 1),
        ),
      );
    }
    return data;
  }

  /// Group timestamps by month
  List<UserGrowthPoint> _groupByMonth(
    List<int> timestamps,
    DateTime now,
    int months,
  ) {
    List<UserGrowthPoint> data = [];
    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthStart = date.millisecondsSinceEpoch;
      final monthEnd = DateTime(
        date.year,
        date.month + 1,
        1,
      ).millisecondsSinceEpoch;
      final count = timestamps
          .where((t) => t >= monthStart && t < monthEnd)
          .length;
      data.add(
        UserGrowthPoint(
          label: DateFormat("MMM ''yy").format(date),
          count: count,
          date: date,
        ),
      );
    }
    return data;
  }

  /// Group timestamps by day
  List<UserGrowthPoint> _groupByDay(
    List<int> timestamps,
    DateTime now,
    int days,
  ) {
    List<UserGrowthPoint> data = [];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dayStart = date.millisecondsSinceEpoch;
      final dayEnd = dayStart + 86400000;
      final count = timestamps.where((t) => t >= dayStart && t < dayEnd).length;
      data.add(
        UserGrowthPoint(
          label: DateFormat('MMM d').format(date),
          count: count,
          date: date,
        ),
      );
    }
    return data;
  }

  /// Load revenue data based on filter with 20% commission calculation
  Future<void> _loadRevenueData() async {
    setState(() => _isLoadingRevenue = true);

    try {
      final now = DateTime.now();
      List<EnrollmentRecord> allEnrollments = [];

      // Fetch all courses and their enrollments
      final coursesSnapshot = await _db.child('courses').get();
      if (coursesSnapshot.exists && coursesSnapshot.value != null) {
        final coursesMap = Map<String, dynamic>.from(
          coursesSnapshot.value as Map,
        );

        for (var courseEntry in coursesMap.entries) {
          final course = Map<String, dynamic>.from(courseEntry.value as Map);
          final price = (course['price'] ?? 0).toDouble();
          final isFree = course['isFree'] == true || price == 0;

          if (!isFree && price > 0) {
            // Check enrolledStudents node
            if (course['enrolledStudents'] != null) {
              final enrolled = Map<String, dynamic>.from(
                course['enrolledStudents'] as Map,
              );
              for (var enrollEntry in enrolled.entries) {
                final enrollData = enrollEntry.value;
                int? enrolledAt;
                if (enrollData is Map) {
                  enrolledAt = enrollData['enrolledAt'] as int?;
                } else if (enrollData is int) {
                  enrolledAt = enrollData;
                }
                if (enrolledAt != null) {
                  allEnrollments.add(
                    EnrollmentRecord(amount: price, timestamp: enrolledAt),
                  );
                }
              }
            }
          }
        }
      }

      List<RevenuePoint> revenueData = [];

      switch (_revenueFilter) {
        case 'all':
          // Group by year
          revenueData = _groupRevenueByYear(allEnrollments, now);
          break;
        case 'year':
          // Group by month for current year
          revenueData = _groupRevenueByMonth(allEnrollments, now, 12);
          break;
        case 'month':
          // Group by day for current month
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          revenueData = _groupRevenueByDay(allEnrollments, now, daysInMonth);
          break;
        case 'week':
          // Group by day for last 7 days
          revenueData = _groupRevenueByDay(allEnrollments, now, 7);
          break;
      }

      // Calculate total platform commission (sum of all points which already have 20% applied)
      final commission = revenueData.fold(
        0.0,
        (sum, point) => sum + point.amount,
      );

      setState(() {
        _revenueData = revenueData;
        _platformCommission = commission;
        _isLoadingRevenue = false;
      });
    } catch (e) {
      debugPrint('Error loading revenue: $e');
      setState(() => _isLoadingRevenue = false);
    }
  }

  /// Group enrollments by year for revenue
  List<RevenuePoint> _groupRevenueByYear(
    List<EnrollmentRecord> enrollments,
    DateTime now,
  ) {
    if (enrollments.isEmpty) {
      // Return current year with 0
      return [RevenuePoint(label: now.year.toString(), amount: 0, date: now)];
    }

    final earliestYear = enrollments
        .map((e) => DateTime.fromMillisecondsSinceEpoch(e.timestamp).year)
        .reduce((a, b) => a < b ? a : b);

    List<RevenuePoint> data = [];
    for (int year = earliestYear; year <= now.year; year++) {
      final yearStart = DateTime(year, 1, 1).millisecondsSinceEpoch;
      final yearEnd = DateTime(year + 1, 1, 1).millisecondsSinceEpoch;
      final amount = enrollments
          .where((e) => e.timestamp >= yearStart && e.timestamp < yearEnd)
          .fold(0.0, (sum, e) => sum + e.amount);
      data.add(
        RevenuePoint(
          label: year.toString(),
          amount: amount * 0.20, // 20% commission
          date: DateTime(year, 1, 1),
        ),
      );
    }
    return data;
  }

  /// Group enrollments by month for revenue
  List<RevenuePoint> _groupRevenueByMonth(
    List<EnrollmentRecord> enrollments,
    DateTime now,
    int months,
  ) {
    List<RevenuePoint> data = [];
    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthStart = date.millisecondsSinceEpoch;
      final monthEnd = DateTime(
        date.year,
        date.month + 1,
        1,
      ).millisecondsSinceEpoch;
      final amount = enrollments
          .where((e) => e.timestamp >= monthStart && e.timestamp < monthEnd)
          .fold(0.0, (sum, e) => sum + e.amount);
      data.add(
        RevenuePoint(
          label: DateFormat('MMM').format(date),
          amount: amount * 0.20, // 20% commission
          date: date,
        ),
      );
    }
    return data;
  }

  /// Group enrollments by day for revenue
  List<RevenuePoint> _groupRevenueByDay(
    List<EnrollmentRecord> enrollments,
    DateTime now,
    int days,
  ) {
    List<RevenuePoint> data = [];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dayStart = date.millisecondsSinceEpoch;
      final dayEnd = dayStart + 86400000;
      final amount = enrollments
          .where((e) => e.timestamp >= dayStart && e.timestamp < dayEnd)
          .fold(0.0, (sum, e) => sum + e.amount);
      data.add(
        RevenuePoint(
          label: DateFormat('d').format(date),
          amount: amount * 0.20, // 20% commission
          date: date,
        ),
      );
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1000;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserGrowthData();
        await _loadRevenueData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Platform Analytics',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visual insights and performance metrics',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 24),

            // Charts - Side by side on wide screens
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildUserGrowthChart(isDark)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildRevenueChart(isDark)),
                ],
              )
            else ...[
              _buildUserGrowthChart(isDark),
              const SizedBox(height: 20),
              _buildRevenueChart(isDark),
            ],
          ],
        ),
      ),
    );
  }

  /// Build User Growth Chart with working filters
  Widget _buildUserGrowthChart(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Growth',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalSignups signups',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoadingUserGrowth ? null : _loadUserGrowthData,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.getTextSecondary(context),
                  size: 20,
                ),
                tooltip: 'Refresh data',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Time', 'all', _userGrowthFilter, (v) {
                  setState(() => _userGrowthFilter = v);
                  _loadUserGrowthData();
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('12 Months', '12months', _userGrowthFilter, (
                  v,
                ) {
                  setState(() => _userGrowthFilter = v);
                  _loadUserGrowthData();
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('6 Months', '6months', _userGrowthFilter, (v) {
                  setState(() => _userGrowthFilter = v);
                  _loadUserGrowthData();
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('30 Days', '30days', _userGrowthFilter, (v) {
                  setState(() => _userGrowthFilter = v);
                  _loadUserGrowthData();
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('7 Days', '7days', _userGrowthFilter, (v) {
                  setState(() => _userGrowthFilter = v);
                  _loadUserGrowthData();
                }, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                      isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'New User Signups',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 250,
            child: _isLoadingUserGrowth
                ? _buildLoadingState(isDark)
                : _userGrowthData.isEmpty
                ? _buildEmptyState(isDark)
                : _buildUserGrowthLineChart(isDark),
          ),
        ],
      ),
    );
  }

  /// Build User Growth Line Chart
  Widget _buildUserGrowthLineChart(bool isDark) {
    final spots = _userGrowthData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
    }).toList();

    final maxY =
        _userGrowthData.fold<double>(
          1.0,
          (max, point) => point.count > max ? point.count.toDouble() : max,
        ) *
        1.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 5 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? AppTheme.darkBorder : Colors.grey.shade200)
                .withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxY > 5 ? maxY / 5 : 1,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox();
                }
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: _calculateXAxisInterval(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _userGrowthData.length) {
                  return const SizedBox();
                }

                // Smart label display
                if (!_shouldShowLabel(index)) return const SizedBox();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _userGrowthData[index].label,
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 9,
                    ),
                  ),
                );
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
        minX: 0,
        maxX: (_userGrowthData.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            gradient: LinearGradient(
              colors: [
                isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                isDark ? AppTheme.darkAccent : AppTheme.accentColor,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                  strokeWidth: 2,
                  strokeColor: isDark ? AppTheme.darkCard : Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      .withOpacity(0.3),
                  (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      .withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? AppTheme.darkElevated : Colors.white,
            tooltipBorder: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final label = index < _userGrowthData.length
                    ? _userGrowthData[index].label
                    : '';
                return LineTooltipItem(
                  '${spot.y.toInt()} new users\n$label',
                  TextStyle(
                    color: isDark
                        ? AppTheme.darkPrimary
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double _calculateXAxisInterval() {
    final len = _userGrowthData.length;
    if (len <= 7) return 1;
    if (len <= 12) return 2;
    if (len <= 30) return 5;
    return (len / 6).ceilToDouble();
  }

  bool _shouldShowLabel(int index) {
    final len = _userGrowthData.length;
    if (len <= 7) return true;
    if (index == 0 || index == len - 1) return true;

    final interval = _calculateXAxisInterval().toInt();
    return index % interval == 0;
  }

  /// Build Revenue Chart with working filters
  Widget _buildRevenueChart(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.grey).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.attach_money_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Revenue',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '\$${_platformCommission.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '20% commission',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isLoadingRevenue ? null : _loadRevenueData,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.getTextSecondary(context),
                  size: 20,
                ),
                tooltip: 'Refresh data',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Time', 'all', _revenueFilter, (v) {
                  setState(() => _revenueFilter = v);
                  _loadRevenueData();
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('This Year', 'year', _revenueFilter, (v) {
                  setState(() => _revenueFilter = v);
                  _loadRevenueData();
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('This Month', 'month', _revenueFilter, (v) {
                  setState(() => _revenueFilter = v);
                  _loadRevenueData();
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('This Week', 'week', _revenueFilter, (v) {
                  setState(() => _revenueFilter = v);
                  _loadRevenueData();
                }, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Platform Commission (20%)',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 200,
            child: _isLoadingRevenue
                ? _buildLoadingState(isDark)
                : _revenueData.isEmpty
                ? _buildEmptyState(isDark)
                : _buildRevenueBarChart(isDark),
          ),
        ],
      ),
    );
  }

  /// Build Revenue Bar Chart
  Widget _buildRevenueBarChart(bool isDark) {
    final maxY =
        _revenueData.fold<double>(
          10.0,
          (max, point) => point.amount > max ? point.amount : max,
        ) *
        1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 4 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? AppTheme.darkBorder : Colors.grey.shade200)
                .withOpacity(0.5),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: maxY > 4 ? maxY / 4 : 1,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox();
                return Text(
                  '\$${value.toInt()}',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 10,
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
                if (index < 0 || index >= _revenueData.length) {
                  return const SizedBox();
                }

                // Show only some labels if too many
                final len = _revenueData.length;
                if (len > 12 &&
                    index != 0 &&
                    index != len - 1 &&
                    index % 3 != 0) {
                  return const SizedBox();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _revenueData[index].label,
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 9,
                    ),
                  ),
                );
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
        barGroups: _revenueData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.amount,
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF34D399)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: _revenueData.length > 20 ? 8 : 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? AppTheme.darkElevated : Colors.white,
            tooltipBorder: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = groupIndex < _revenueData.length
                  ? _revenueData[groupIndex].label
                  : '';
              return BarTooltipItem(
                '\$${rod.toY.toStringAsFixed(2)}\n$label',
                const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build filter chip
  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    Function(String) onSelected,
    bool isDark,
  ) {
    final isSelected = value == currentValue;

    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
              : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppTheme.getTextSecondary(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading data...',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: AppTheme.getTextSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No data available for this period',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
        ],
      ),
    );
  }
}

/// Data point for user growth chart
class UserGrowthPoint {
  final String label;
  final int count;
  final DateTime date;

  UserGrowthPoint({
    required this.label,
    required this.count,
    required this.date,
  });
}

/// Data point for revenue chart
class RevenuePoint {
  final String label;
  final double amount;
  final DateTime date;

  RevenuePoint({required this.label, required this.amount, required this.date});
}

/// Enrollment record for revenue calculation
class EnrollmentRecord {
  final double amount;
  final int timestamp;

  EnrollmentRecord({required this.amount, required this.timestamp});
}
