import 'package:flutter/material.dart';
import 'package:eduverse/services/study_streak_service.dart';
import 'package:eduverse/services/learning_stats_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/student/learning_stats_screen.dart';

/// Compact card showing study streak (fire icon + count) and quick stats.
/// Designed for the student home tab.
class StudyStreakCard extends StatefulWidget {
  const StudyStreakCard({super.key});

  @override
  State<StudyStreakCard> createState() => _StudyStreakCardState();
}

class _StudyStreakCardState extends State<StudyStreakCard>
    with SingleTickerProviderStateMixin {
  final _streakService = StudyStreakService();
  final _statsService = LearningStatsService();

  late AnimationController _fireController;

  @override
  void initState() {
    super.initState();
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fireController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return StreamBuilder<Map<String, dynamic>>(
      stream: _streakService.streakStream(),
      builder: (context, snapshot) {
        final streak = snapshot.data ?? {};
        final currentStreak = streak['currentStreak'] as int? ?? 0;
        final longestStreak = streak['longestStreak'] as int? ?? 0;
        final studiedToday = streak['studiedToday'] as bool? ?? false;

        return StreamBuilder<Map<String, dynamic>>(
          stream: _statsService.statsStream(),
          builder: (context, statsSnap) {
            final statsData = statsSnap.data;
            final statsLoaded = statsData != null;
            final totalHours = statsLoaded
                ? (statsData['totalHours'] as String? ?? '0.0')
                : '...';
            final videosWatched = statsLoaded
                ? (statsData['videosWatched'] as int? ?? 0)
                : 0;
            final quizzesTaken = statsLoaded
                ? (statsData['quizzesTaken'] as int? ?? 0)
                : 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LearningStatsScreen()),
            );
          },
          child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF4CC9F0).withOpacity(0.2)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF4CC9F0).withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          // Streak row
          Row(
            children: [
              // Animated fire icon
              AnimatedBuilder(
                animation: _fireController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + _fireController.value * 0.15,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: currentStreak > 0
                          ? [const Color(0xFFFF6B35), const Color(0xFFFF4500)]
                          : [Colors.grey.shade400, Colors.grey.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: currentStreak > 0
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$currentStreak day streak',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        if (studiedToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '✓ Today',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Best: $longestStreak days',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          // Divider
          Divider(
            height: 1,
            color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
          ),
          const SizedBox(height: 14),

          // Quick stats row
          Row(
            children: [
              _buildMiniStat(
                context,
                icon: Icons.timer_outlined,
                value: '${totalHours}h',
                label: 'Study Time',
                color: const Color(0xFF4CC9F0),
              ),
              _buildDivider(isDark),
              _buildMiniStat(
                context,
                icon: Icons.play_circle_outline,
                value: '$videosWatched',
                label: 'Videos',
                color: const Color(0xFF7B68EE),
              ),
              _buildDivider(isDark),
              _buildMiniStat(
                context,
                icon: Icons.quiz_outlined,
                value: '$quizzesTaken',
                label: 'Quizzes',
                color: const Color(0xFF2EC4B6),
              ),
            ],
          ),

          // Tap hint
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart,
                size: 14,
                color: AppTheme.getTextSecondary(context),
              ),
              const SizedBox(width: 4),
              Text(
                'Tap for full stats',
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
          },
        );
      },
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 36,
      color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
    );
  }
}
