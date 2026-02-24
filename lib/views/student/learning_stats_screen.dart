import 'package:flutter/material.dart';
import 'package:eduverse/services/learning_stats_service.dart';
import 'package:eduverse/services/study_streak_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Full-screen learning statistics dashboard for students.
/// Shows study time, streaks, weekly activity chart, and activity breakdowns.
class LearningStatsScreen extends StatefulWidget {
  const LearningStatsScreen({super.key});

  @override
  State<LearningStatsScreen> createState() => _LearningStatsScreenState();
}

class _LearningStatsScreenState extends State<LearningStatsScreen> {
  final _statsService = LearningStatsService();
  final _streakService = StudyStreakService();

  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _streak = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _statsService.getStats(),
        _streakService.getStreakData(),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0];
          _streak = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
          'My Learning Stats',
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
                    // Streak Header
                    _buildStreakHeader(isDark, accentColor),
                    const SizedBox(height: 20),

                    // Quick Stats Grid
                    _buildStatsGrid(isDark, accentColor),
                    const SizedBox(height: 20),

                    // Weekly Activity Chart
                    _buildWeeklyChart(isDark, accentColor),
                    const SizedBox(height: 20),

                    // Activity Breakdown
                    _buildActivityBreakdown(isDark, accentColor),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStreakHeader(bool isDark, Color accentColor) {
    final currentStreak = _streak['currentStreak'] as int? ?? 0;
    final longestStreak = _streak['longestStreak'] as int? ?? 0;
    final studiedToday = _streak['studiedToday'] as bool? ?? false;
    final totalDays = _streak['totalDaysStudied'] as int? ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withOpacity(0.7),
          ],
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$currentStreak Day Streak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    studiedToday
                        ? "You've studied today! Keep it up!"
                        : 'Study today to keep your streak!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStreakStat('Longest', '$longestStreak days', Colors.white),
              Container(width: 1, height: 30, color: Colors.white30),
              _buildStreakStat('Total Days', '$totalDays', Colors.white),
              Container(width: 1, height: 30, color: Colors.white30),
              _buildStreakStat(
                'Status',
                studiedToday ? '✅ Done' : '⏳ Pending',
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark, Color accentColor) {
    final totalHours = _stats['totalHours'] as String? ?? '0.0';
    final totalSessions = _stats['totalSessions'] as int? ?? 0;
    final videosWatched = _stats['videosWatched'] as int? ?? 0;
    final quizzesTaken = _stats['quizzesTaken'] as int? ?? 0;
    final assignmentsDone = _stats['assignmentsDone'] as int? ?? 0;
    final thisWeekHours = _stats['thisWeekHours'] as String? ?? '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _buildStatTile(
              '${totalHours}h',
              'Total Study',
              Icons.timer_outlined,
              Colors.blue,
              isDark,
            ),
            _buildStatTile(
              '$totalSessions',
              'Sessions',
              Icons.repeat,
              Colors.purple,
              isDark,
            ),
            _buildStatTile(
              '${thisWeekHours}h',
              'This Week',
              Icons.calendar_today,
              Colors.teal,
              isDark,
            ),
            _buildStatTile(
              '$videosWatched',
              'Videos',
              Icons.play_circle_outline,
              Colors.red,
              isDark,
            ),
            _buildStatTile(
              '$quizzesTaken',
              'Quizzes',
              Icons.quiz_outlined,
              Colors.orange,
              isDark,
            ),
            _buildStatTile(
              '$assignmentsDone',
              'Assignments',
              Icons.assignment_outlined,
              Colors.green,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  Widget _buildWeeklyChart(bool isDark, Color accentColor) {
    final weekDaySeconds = _stats['weekDaySeconds'] as List<dynamic>? ?? List.filled(7, 0);
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Find max for chart scaling
    double maxMinutes = 1;
    for (final s in weekDaySeconds) {
      final minutes = ((s as num?)?.toInt() ?? 0) / 60.0;
      if (minutes > maxMinutes) maxMinutes = minutes;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week\'s Activity',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final seconds = (weekDaySeconds[i] as num?)?.toInt() ?? 0;
                final minutes = seconds / 60.0;
                final barHeight = maxMinutes > 0
                    ? (minutes / maxMinutes * 100).clamp(4.0, 100.0)
                    : 4.0;
                final isToday = DateTime.now().weekday == i + 1;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (minutes >= 1)
                        Text(
                          '${minutes.toStringAsFixed(0)}m',
                          style: TextStyle(
                            color: isToday
                                ? accentColor
                                : AppTheme.getTextSecondary(context),
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 24,
                        height: seconds > 0 ? barHeight : 4,
                        decoration: BoxDecoration(
                          color: isToday
                              ? accentColor
                              : accentColor.withOpacity(
                                  seconds > 0 ? 0.4 : 0.1,
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLabels[i],
                        style: TextStyle(
                          color: isToday
                              ? accentColor
                              : AppTheme.getTextSecondary(context),
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBreakdown(bool isDark, Color accentColor) {
    final videosWatched = _stats['videosWatched'] as int? ?? 0;
    final quizzesTaken = _stats['quizzesTaken'] as int? ?? 0;
    final assignmentsDone = _stats['assignmentsDone'] as int? ?? 0;
    final total = videosWatched + quizzesTaken + assignmentsDone;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Breakdown',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
            'Videos Watched',
            videosWatched,
            total,
            Icons.play_circle_outline,
            Colors.red,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow(
            'Quizzes Taken',
            quizzesTaken,
            total,
            Icons.quiz_outlined,
            Colors.orange,
            isDark,
          ),
          const SizedBox(height: 10),
          _buildBreakdownRow(
            'Assignments Done',
            assignmentsDone,
            total,
            Icons.assignment_outlined,
            Colors.green,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    int count,
    int total,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final pct = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$count',
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
                  backgroundColor: isDark
                      ? Colors.white12
                      : Colors.grey.shade200,
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
