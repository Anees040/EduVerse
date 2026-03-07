import 'package:flutter/material.dart';
import 'package:eduverse/services/gamification_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Full‐screen achievements dashboard — XP summary, level progress,
/// and a grid of all available badges (locked & unlocked).
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _service = GamificationService();
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    // Bootstrap XP from existing data if gamification node is empty
    await _service.syncFromExistingData();
    final profile = await _service.getProfile();
    if (mounted) setState(() { _profile = profile; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accent = AppTheme.getPrimaryColor(context);

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
          'Achievements',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.getTextSecondary(context)),
            onPressed: _loadProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildLevelHeader(isDark, accent),
                  const SizedBox(height: 24),
                  _buildXPStatsRow(isDark, accent),
                  const SizedBox(height: 24),
                  _buildBadgesSection(isDark, accent),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ──────────── Level Header ────────────

  Widget _buildLevelHeader(bool isDark, Color accent) {
    final int level = (_profile['level'] as num?)?.toInt() ?? 1;
    final String title = _profile['levelTitle'] as String? ?? 'Beginner';
    final int totalXP = (_profile['totalXP'] as num?)?.toInt() ?? 0;
    final double progress =
        (_profile['levelProgress'] as num?)?.toDouble() ?? 0.0;
    final int xpInLevel =
        (_profile['xpInCurrentLevel'] as num?)?.toInt() ?? 0;
    final int xpNeeded =
        (_profile['xpNeededForNext'] as num?)?.toInt() ?? 100;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Level circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
            ),
            child: Center(
              child: Text(
                '$level',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalXP XP earned',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 20),
          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level $level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              Text(
                'Level ${level + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withOpacity(0.25),
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$xpInLevel / $xpNeeded XP to next level',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── XP Stats Row ────────────

  Widget _buildXPStatsRow(bool isDark, Color accent) {
    final counters =
        Map<String, dynamic>.from((_profile['counters'] as Map?) ?? {});
    final int videos = (counters['video'] as num?)?.toInt() ?? 0;
    final int quizzes = (counters['quiz'] as num?)?.toInt() ?? 0;
    final int assignments = (counters['assignment'] as num?)?.toInt() ?? 0;
    final int courses = (counters['course'] as num?)?.toInt() ?? 0;

    return Row(
      children: [
        _statTile(context, '🎬', '$videos', 'Videos', isDark, accent),
        const SizedBox(width: 10),
        _statTile(context, '⚡', '$quizzes', 'Quizzes', isDark, accent),
        const SizedBox(width: 10),
        _statTile(context, '📝', '$assignments', 'Tasks', isDark, accent),
        const SizedBox(width: 10),
        _statTile(context, '🎓', '$courses', 'Courses', isDark, accent),
      ],
    );
  }

  Widget _statTile(BuildContext context, String emoji, String value,
      String label, bool isDark, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────── Badges Grid ────────────

  Widget _buildBadgesSection(bool isDark, Color accent) {
    final unlockedBadges =
        Map<String, dynamic>.from((_profile['badges'] as Map?) ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: accent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Badges  (${unlockedBadges.length}/${GamificationService.badgeDefinitions.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: GamificationService.badgeDefinitions.length,
          itemBuilder: (context, index) {
            final def = GamificationService.badgeDefinitions[index];
            final id = def['id'] as String;
            final isUnlocked = unlockedBadges.containsKey(id);
            return _buildBadgeTile(def, isUnlocked, isDark, accent);
          },
        ),
      ],
    );
  }

  Widget _buildBadgeTile(
      Map<String, dynamic> def, bool isUnlocked, bool isDark, Color accent) {
    final name = def['name'] as String;
    final icon = def['icon'] as String;

    return GestureDetector(
      onTap: () => _showBadgeDetail(def, isUnlocked, isDark, accent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? accent.withOpacity(0.5)
                : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
            width: isUnlocked ? 2 : 1,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 30,
                color: isUnlocked ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isUnlocked
                    ? AppTheme.getTextPrimary(context)
                    : AppTheme.getTextSecondary(context).withOpacity(0.5),
              ),
            ),
            if (!isUnlocked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.lock_outline,
                    size: 14,
                    color: AppTheme.getTextSecondary(context).withOpacity(0.4)),
              ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(
      Map<String, dynamic> def, bool isUnlocked, bool isDark, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.getTextSecondary(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                def['icon'] as String,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 12),
              Text(
                def['name'] as String,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                def['description'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? accent.withOpacity(0.15)
                      : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isUnlocked ? '✅  Unlocked!' : '🔒  Locked',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? accent
                        : AppTheme.getTextSecondary(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
