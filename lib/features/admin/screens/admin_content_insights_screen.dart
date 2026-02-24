import 'package:flutter/material.dart';
import 'package:eduverse/features/admin/services/admin_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin content insights — course quality, categories, trending content.
class AdminContentInsightsScreen extends StatefulWidget {
  const AdminContentInsightsScreen({super.key});

  @override
  State<AdminContentInsightsScreen> createState() =>
      _AdminContentInsightsScreenState();
}

class _AdminContentInsightsScreenState
    extends State<AdminContentInsightsScreen> {
  final _service = AdminFeatureService();
  Map<String, dynamic> _data = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _service.getContentInsights();
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalCourses = (_data['totalCourses'] as num?)?.toInt() ?? 0;
    final published = (_data['publishedCourses'] as num?)?.toInt() ?? 0;
    final drafts = (_data['draftCourses'] as num?)?.toInt() ?? 0;
    final totalVideos = (_data['totalVideos'] as num?)?.toInt() ?? 0;
    final totalQuizzes = (_data['totalQuizzes'] as num?)?.toInt() ?? 0;
    final avgRating = _data['averageRating'] as String? ?? '0.0';
    final categories = _data['categoryBreakdown'] as Map<String, dynamic>? ?? {};
    final topCourses = _data['topCourses'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Text(
                'Content Insights',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview Stats
          _buildStatsGrid(
            isDark,
            totalCourses,
            published,
            drafts,
            totalVideos,
            totalQuizzes,
            avgRating,
          ),
          const SizedBox(height: 24),

          // Course Status Bar
          _buildCourseStatusBar(published, drafts, isDark),
          const SizedBox(height: 24),

          // Category Breakdown
          Text(
            'Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...categories.entries.map((e) =>
              _buildCategoryBar(e.key, e.value as int, totalCourses, isDark)),

          const SizedBox(height: 24),

          // Top Courses
          Text(
            'Top Courses by Enrollment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...topCourses.take(8).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final course = entry.value as Map<String, dynamic>;
            return _buildTopCourseCard(course, idx + 1, isDark, accentColor);
          }),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    bool isDark,
    int total,
    int published,
    int drafts,
    int videos,
    int quizzes,
    String avgRating,
  ) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard('Total Courses', '$total', Icons.library_books,
            Colors.blue, isDark),
        _buildStatCard(
            'Published', '$published', Icons.check_circle, Colors.green, isDark),
        _buildStatCard(
            'Drafts', '$drafts', Icons.edit_note, Colors.orange, isDark),
        _buildStatCard(
            'Videos', '$videos', Icons.play_circle, Colors.red, isDark),
        _buildStatCard(
            'Quizzes', '$quizzes', Icons.quiz, Colors.purple, isDark),
        _buildStatCard(
            'Avg Rating', avgRating, Icons.star, Colors.amber, isDark),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
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

  Widget _buildCourseStatusBar(int published, int drafts, bool isDark) {
    final total = published + drafts;
    if (total == 0) return const SizedBox.shrink();

    final publishedPct = published / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Publication Status',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    flex: (publishedPct * 100).round(),
                    child: Container(color: Colors.green),
                  ),
                  Expanded(
                    flex: ((1 - publishedPct) * 100).round(),
                    child: Container(color: Colors.orange.shade300),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendDot(Colors.green, 'Published ($published)'),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.orange.shade300, 'Drafts ($drafts)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBar(
    String category,
    int count,
    int totalCourses,
    bool isDark,
  ) {
    final pct = totalCourses > 0 ? count / totalCourses : 0.0;
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    final color = colors[category.hashCode.abs() % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              category,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$count',
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCourseCard(
    Map<String, dynamic> course,
    int rank,
    bool isDark,
    Color accentColor,
  ) {
    final title = course['title'] as String? ?? 'Untitled';
    final enrolled = (course['enrolled'] as num?)?.toInt() ?? 0;
    final rating = (course['rating'] as num?)?.toDouble() ?? 0;
    final category = course['category'] as String? ?? '';
    // isPublished available in course data

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? (rank == 1
                          ? Colors.amber
                          : rank == 2
                              ? Colors.grey.shade400
                              : Colors.brown.shade300)
                      .withOpacity(0.15)
                  : accentColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rank <= 3
                      ? (rank == 1
                          ? Colors.amber.shade700
                          : rank == 2
                              ? Colors.grey.shade600
                              : Colors.brown)
                      : accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 14, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text(
                    '$enrolled',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                  const SizedBox(width: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
