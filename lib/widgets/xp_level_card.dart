import 'package:flutter/material.dart';
import 'package:eduverse/services/gamification_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/student/achievements_screen.dart';

/// Compact card showing the student's current level, XP bar, and recent badges.
/// Tapping opens the full Achievements screen.
class XpLevelCard extends StatelessWidget {
  const XpLevelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accent = AppTheme.getPrimaryColor(context);

    return StreamBuilder<Map<String, dynamic>>(
      stream: GamificationService().profileStream(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? GamificationService().profileStream().first as Map<String, dynamic>? ?? _defaults();

        final int totalXP = (profile['totalXP'] as num?)?.toInt() ?? 0;
        final int level = (profile['level'] as num?)?.toInt() ?? 1;
        final String title = profile['levelTitle'] as String? ?? 'Beginner';
        final double progress = (profile['levelProgress'] as num?)?.toDouble() ?? 0.0;
        final int xpInLevel = (profile['xpInCurrentLevel'] as num?)?.toInt() ?? 0;
        final int xpNeeded = (profile['xpNeededForNext'] as num?)?.toInt() ?? 100;
        final Map<String, dynamic> badges =
            Map<String, dynamic>.from((profile['badges'] as Map?) ?? {});

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? accent.withOpacity(0.25)
                    : Colors.grey.shade200,
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.08),
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
                // ── Top row: level badge + title + total XP ──
                Row(
                  children: [
                    // Level circle
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [accent, accent.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Level $level  •  $totalXP XP',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Arrow
                    Icon(Icons.chevron_right_rounded,
                        color: AppTheme.getTextSecondary(context)),
                  ],
                ),

                const SizedBox(height: 14),

                // ── XP progress bar ──
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$xpInLevel / $xpNeeded XP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? AppTheme.darkElevated
                              : Colors.grey.shade200,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Recent badges row (if any) ──
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Text(
                          'Badges',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _buildBadgeChips(context, badges),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBadgeChips(
      BuildContext context, Map<String, dynamic> badges) {
    // Sort by unlock time (most recent first), take up to 5 to keep compact
    final sorted = badges.entries.toList()
      ..sort((a, b) {
        final aTime = (a.value as num?)?.toInt() ?? 0;
        final bTime = (b.value as num?)?.toInt() ?? 0;
        return bTime.compareTo(aTime);
      });

    return sorted.take(5).map((entry) {
      final def = GamificationService.getBadgeDefinition(entry.key);
      if (def == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: def['name'] as String,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.isDarkMode(context)
                  ? AppTheme.darkElevated
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              def['icon'] as String,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }).toList();
  }

  Map<String, dynamic> _defaults() => {
        'totalXP': 0,
        'level': 1,
        'levelTitle': 'Beginner',
        'levelProgress': 0.0,
        'xpInCurrentLevel': 0,
        'xpNeededForNext': 100,
        'badges': <String, dynamic>{},
      };
}
