import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../providers/admin_provider.dart';

/// Admin Analytics Screen - Platform analytics with charts
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    // Load analytics data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AdminProvider>(context, listen: false);
      if (provider.state.userGrowthData.isEmpty) {
        provider.loadAnalyticsData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 1000;

    return Consumer<AdminProvider>(
      builder: (context, provider, child) {
        return RefreshIndicator(
          onRefresh: () => provider.loadAnalyticsData(),
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
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Visual insights and performance metrics',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Charts
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildUserGrowthChart(provider, isDark)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildRevenueSplitChart(provider, isDark),
                      ),
                    ],
                  )
                else ...[
                  _buildUserGrowthChart(provider, isDark),
                  const SizedBox(height: 20),
                  _buildRevenueSplitChart(provider, isDark),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserGrowthChart(AdminProvider provider, bool isDark) {
    final data = provider.state.userGrowthData;
    final isLoading = data.isEmpty;

    // Calculate stats for display
    int totalUsers = 0;
    int growthPercent = 0;
    if (data.isNotEmpty) {
      totalUsers = data.fold<int>(0, (sum, item) => sum + (item['count'] as int? ?? 0));
      if (data.length >= 2) {
        final recent = (data.last['count'] as int? ?? 0);
        final previous = (data[data.length - 2]['count'] as int? ?? 1);
        if (previous > 0) {
          growthPercent = (((recent - previous) / previous) * 100).round();
        }
      }
    }

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
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (!isLoading) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$totalUsers total signups',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (growthPercent != 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (growthPercent > 0
                                        ? (isDark ? AppTheme.darkSuccess : AppTheme.success)
                                        : (isDark ? AppTheme.darkError : AppTheme.error))
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    growthPercent > 0
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 12,
                                    color: growthPercent > 0
                                        ? (isDark ? AppTheme.darkSuccess : AppTheme.success)
                                        : (isDark ? AppTheme.darkError : AppTheme.error),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${growthPercent.abs()}%',
                                    style: TextStyle(
                                      color: growthPercent > 0
                                          ? (isDark ? AppTheme.darkSuccess : AppTheme.success)
                                          : (isDark ? AppTheme.darkError : AppTheme.error),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Refresh button
              IconButton(
                onPressed: isLoading ? null : () => provider.loadAnalyticsData(),
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  size: 20,
                ),
                tooltip: 'Refresh data',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'New signups over the last 12 months',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: isLoading
                ? _buildLoadingChart(isDark)
                : _buildLineChart(data, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> data, bool isDark) {
    if (data.isEmpty) {
      return _buildNoDataState(isDark);
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['count'] as int).toDouble(),
      );
    }).toList();

    final maxY =
        data.fold<double>(0, (max, item) {
          final count = (item['count'] as int).toDouble();
          return count > max ? count : max;
        }) *
        1.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 5 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: (isDark ? AppTheme.darkBorder : Colors.grey.shade200).withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: maxY > 5 ? maxY / 5 : 1,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  // Only show every nth label to avoid overlap
                  final showLabel = data.length <= 6 || index % 2 == 0 || index == data.length - 1;
                  if (!showLabel) return const SizedBox();
                  
                  final dateStr = data[index]['date']?.toString() ?? '';
                  try {
                    if (dateStr.isNotEmpty) {
                      final date = DateTime.parse(dateStr);
                      final monthName = DateFormat('MMM').format(date);
                      final year = date.year.toString().substring(2); // '26' from '2026'
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RotatedBox(
                          quarterTurns: 0,
                          child: Text(
                            "$monthName '$year",
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  } catch (_) {
                    return const Text('');
                  }
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY > 0 ? maxY : 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
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
                  radius: 5,
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                  strokeWidth: 2.5,
                  strokeColor: isDark ? AppTheme.darkCard : Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      .withOpacity(0.25),
                  (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      .withOpacity(0.05),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            maxContentWidth: 150,
            getTooltipColor: (_) =>
                isDark ? AppTheme.darkElevated : Colors.white,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tooltipBorder: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                String dateDisplay = '';
                if (index < data.length) {
                  final dateStr = data[index]['date']?.toString() ?? '';
                  try {
                    if (dateStr.isNotEmpty) {
                      final date = DateTime.parse(dateStr);
                      dateDisplay = DateFormat('MMM d, yyyy').format(date);
                    }
                  } catch (_) {}
                }
                return LineTooltipItem(
                  '${spot.y.toInt()} new users\n',
                  TextStyle(
                    color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: dateDisplay,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                      .withOpacity(0.3),
                  strokeWidth: 2,
                  dashArray: [5, 5],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 7,
                      color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                      strokeWidth: 3,
                      strokeColor: isDark ? AppTheme.darkCard : Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildRevenueSplitChart(AdminProvider provider, bool isDark) {
    final data = provider.state.revenueData;
    final isLoading = data.isEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Monthly Revenue',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Revenue trends over the past months',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: isLoading
                ? _buildLoadingChart(isDark)
                : _buildRevenueBarChart(data, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBarChart(List<Map<String, dynamic>> data, bool isDark) {
    if (data.isEmpty) {
      return _buildNoDataState(isDark);
    }

    final maxRevenue = data.fold<double>(0, (max, item) {
      final revenue = (item['revenue'] ?? 0).toDouble();
      return revenue > max ? revenue : max;
    });

    final currencyFormat = NumberFormat.compactCurrency(symbol: '\$');

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxRevenue * 1.2,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? AppTheme.darkElevated : Colors.white,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = data[group.x.toInt()]['month'] as String;
              return BarTooltipItem(
                '${currencyFormat.format(rod.toY)}\n$month',
                TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final month = data[index]['month'] as String;
                  // Show only month abbreviation
                  final parts = month.split('-');
                  if (parts.length >= 2) {
                    final monthNum = int.tryParse(parts[1]) ?? 1;
                    const monthNames = [
                      'J',
                      'F',
                      'M',
                      'A',
                      'M',
                      'J',
                      'J',
                      'A',
                      'S',
                      'O',
                      'N',
                      'D',
                    ];
                    return Text(
                      monthNames[monthNum - 1],
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    );
                  }
                }
                return const SizedBox();
              },
              reservedSize: 20,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  currencyFormat.format(value),
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.textSecondary,
                    fontSize: 10,
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
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxRevenue > 4 ? maxRevenue / 4 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (index) {
          final revenue = (data[index]['revenue'] ?? 0).toDouble();
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: revenue,
                color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLoadingChart(bool isDark) {
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
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: isDark ? AppTheme.darkTextTertiary : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No data available',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
