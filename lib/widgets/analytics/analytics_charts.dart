import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Activity Line Chart showing watch times throughout the day
class ActivityLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;

  const ActivityLineChart({
    super.key,
    required this.data,
    this.title = 'Popular Watch Times',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final lineColor = isDark ? AppTheme.darkPrimary : AppTheme.primaryColor;
    final gradientColors = isDark
        ? [AppTheme.darkPrimary, AppTheme.darkAccent]
        : [AppTheme.primaryColor, AppTheme.accentColor];

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
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Active viewers by time of day',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? AppTheme.darkBorder.withOpacity(0.3)
                          : Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppTheme.darkTextTertiary
                                  : Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 &&
                            index < data.length &&
                            index % 4 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index]['label'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppTheme.darkTextTertiary
                                    : Colors.grey.shade500,
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
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value['viewers'] as int).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: gradientColors
                            .map((color) => color.withOpacity(0.2))
                            .toList(),
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppTheme.darkElevated : Colors.grey.shade800,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final dataPoint = data[spot.x.toInt()];
                        return LineTooltipItem(
                          '${dataPoint['label']}\n${spot.y.toInt()} viewers',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly Activity Chart showing student engagement over days
class WeeklyActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const WeeklyActivityChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

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
            'Weekly Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Active students per day',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 200,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppTheme.darkElevated : Colors.grey.shade800,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dayData = data[group.x.toInt()];
                      return BarTooltipItem(
                        '${dayData['day']}\n${rod.toY.toInt()} students',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 50,
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
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index]['day'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? AppTheme.darkBorder.withOpacity(0.3)
                          : Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: data.asMap().entries.map((entry) {
                  final value = (entry.value['activeStudents'] as int)
                      .toDouble();
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: 28,
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
}

/// Course Completion Bar Chart
class CourseCompletionChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const CourseCompletionChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

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
            'Course Completion Rates',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Percentage of students who completed each course',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppTheme.darkElevated : Colors.grey.shade800,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final courseData = data[group.x.toInt()];
                      return BarTooltipItem(
                        '${courseData['courseName']}\n${rod.toY.toInt()}% completed',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 25,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
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
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index]['shortName'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark
                          ? AppTheme.darkBorder.withOpacity(0.3)
                          : Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: data.asMap().entries.map((entry) {
                  final rate = entry.value['completionRate'] as double;
                  final percentage = rate * 100;

                  // Color based on completion rate
                  Color barColor;
                  if (rate >= 0.75) {
                    barColor = isDark ? AppTheme.darkSuccess : AppTheme.success;
                  } else if (rate >= 0.5) {
                    barColor = isDark
                        ? AppTheme.darkAccent
                        : AppTheme.accentColor;
                  } else {
                    barColor = isDark ? AppTheme.darkWarning : AppTheme.warning;
                  }

                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: percentage,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        color: barColor,
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: isDark
                              ? AppTheme.darkBorder.withOpacity(0.3)
                              : Colors.grey.shade200,
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
}

/// Most Replayed Sections List
class ReplayedSectionsList extends StatelessWidget {
  final List<Map<String, dynamic>> sections;

  const ReplayedSectionsList({super.key, required this.sections});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

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
                Icons.replay_circle_filled,
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Most Replayed Sections',
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
          ...sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            final isLast = index == sections.length - 1;

            return Column(
              children: [
                _buildSectionItem(context, section, index + 1, isDark),
                if (!isLast)
                  Divider(
                    color: isDark
                        ? AppTheme.darkBorder.withOpacity(0.5)
                        : Colors.grey.shade200,
                    height: 24,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionItem(
    BuildContext context,
    Map<String, dynamic> section,
    int rank,
    bool isDark,
  ) {
    return Row(
      children: [
        // Rank badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _getRankColor(rank, isDark).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getRankColor(rank, isDark),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Section info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section['sectionName'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                section['courseName'] as String,
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
        // Replay count
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${section['replayCount']}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
              ),
            ),
            Text(
              'replays',
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getRankColor(int rank, bool isDark) {
    switch (rank) {
      case 1:
        return isDark ? const Color(0xFFFFD700) : const Color(0xFFDAA520);
      case 2:
        return isDark ? const Color(0xFFC0C0C0) : const Color(0xFF808080);
      case 3:
        return isDark ? const Color(0xFFCD7F32) : const Color(0xFF8B4513);
      default:
        return isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    }
  }
}
