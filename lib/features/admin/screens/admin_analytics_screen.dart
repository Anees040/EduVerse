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
          horizontalInterval: maxY > 0 ? maxY / 5 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: data.length > 6 ? 2 : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  final month = data[index]['month'] as String;
                  // Parse month string (YYYY-MM) and format
                  try {
                    final date = DateTime.parse('$month-01');
                    return Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        DateFormat('MMM').format(date),
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextTertiary
                              : AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
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
            color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
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
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = index < data.length
                    ? data[index]['date'] as String
                    : '';
                return LineTooltipItem(
                  '${spot.y.toInt()} users\n$date',
                  TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
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
          horizontalInterval: maxRevenue / 4,
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
