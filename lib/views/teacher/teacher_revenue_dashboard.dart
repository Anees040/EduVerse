import 'package:flutter/material.dart';
import 'package:eduverse/services/teacher_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Revenue dashboard for teachers showing earnings, growth, and per-course breakdown.
class TeacherRevenueDashboard extends StatefulWidget {
  const TeacherRevenueDashboard({super.key});

  @override
  State<TeacherRevenueDashboard> createState() =>
      _TeacherRevenueDashboardState();
}

class _TeacherRevenueDashboardState extends State<TeacherRevenueDashboard> {
  final _service = TeacherFeatureService();
  Map<String, dynamic> _data = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _service.getRevenueData();
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
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
          icon: Icon(Icons.arrow_back, color: AppTheme.getTextPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Revenue Dashboard',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.getTextSecondary(context)),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Revenue Card
                    _buildTotalRevenueCard(isDark, accentColor),
                    const SizedBox(height: 16),

                    // Quick Stats
                    _buildQuickStats(isDark),
                    const SizedBox(height: 20),

                    // Monthly Trend
                    _buildMonthlyTrend(isDark, accentColor),
                    const SizedBox(height: 20),

                    // Per-Course Revenue
                    _buildCourseRevenue(isDark, accentColor),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTotalRevenueCard(bool isDark, Color accentColor) {
    final totalRevenue =
        (_data['totalRevenue'] as num?)?.toDouble() ?? 0;
    final thisMonth =
        (_data['thisMonthRevenue'] as num?)?.toDouble() ?? 0;
    final growth = _data['growthPercent'] as String? ?? '0.0';
    final growthVal = double.tryParse(growth) ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accentColor, accentColor.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Revenue',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${totalRevenue.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
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
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${growthVal >= 0 ? '+' : ''}$growth%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'vs last month',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This month: \$${thisMonth.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    final totalTransactions =
        (_data['totalTransactions'] as num?)?.toInt() ?? 0;
    final totalEnrollments =
        (_data['totalEnrollments'] as num?)?.toInt() ?? 0;
    final lastMonth =
        (_data['lastMonthRevenue'] as num?)?.toDouble() ?? 0;

    return Row(
      children: [
        _buildStatCard(
          '$totalTransactions',
          'Transactions',
          Icons.receipt_long,
          Colors.blue,
          isDark,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          '$totalEnrollments',
          'Enrollments',
          Icons.people,
          Colors.green,
          isDark,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          '\$${lastMonth.toStringAsFixed(0)}',
          'Last Month',
          Icons.calendar_month,
          Colors.orange,
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrend(bool isDark, Color accentColor) {
    final monthlyRevenue =
        _data['monthlyRevenue'] as Map<String, dynamic>? ?? {};

    if (monthlyRevenue.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Text(
            'No revenue data yet',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
        ),
      );
    }

    // Sort months and take last 6
    final sortedMonths = monthlyRevenue.keys.toList()..sort();
    final recentMonths = sortedMonths.length > 6
        ? sortedMonths.sublist(sortedMonths.length - 6)
        : sortedMonths;

    double maxVal = 1;
    for (final m in recentMonths) {
      final val = (monthlyRevenue[m] as num?)?.toDouble() ?? 0;
      if (val > maxVal) maxVal = val;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Revenue',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recentMonths.map((month) {
                final val = (monthlyRevenue[month] as num?)?.toDouble() ?? 0;
                final barHeight = (val / maxVal * 80).clamp(4.0, 80.0);
                final monthLabel = month.length >= 7
                    ? month.substring(5) // Just month part
                    : month;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '\$${val.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 28,
                        height: val > 0 ? barHeight : 4,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(val > 0 ? 0.7 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        monthLabel,
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseRevenue(bool isDark, Color accentColor) {
    final courseRevenue =
        _data['courseRevenue'] as Map<String, dynamic>? ?? {};

    if (courseRevenue.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by revenue desc
    final sorted = courseRevenue.entries.toList()
      ..sort((a, b) {
        final aVal = (a.value as num?)?.toDouble() ?? 0;
        final bVal = (b.value as num?)?.toDouble() ?? 0;
        return bVal.compareTo(aVal);
      });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by Course',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.take(10).map((entry) {
            final courseId = entry.key;
            final amount = (entry.value as num?)?.toDouble() ?? 0;
            final totalRev =
                (_data['totalRevenue'] as num?)?.toDouble() ?? 1;
            final pct = totalRev > 0 ? amount / totalRev : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          courseId.length > 20
                              ? '${courseId.substring(0, 20)}...'
                              : courseId,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey.shade200,
                      color: accentColor,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
