import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Beautiful Course Card Widget with progress tracking support
class CourseCard extends StatelessWidget {
  final String title;
  final String? description;
  final String imageUrl;
  final int? createdAt;
  final double progress; // 0.0 to 1.0
  final bool isEnrolled;
  final bool showEnrollButton;
  final bool isTeacherView;
  final String? instructorName;
  final double? instructorRating;
  final int? reviewCount;
  final VoidCallback? onTap;
  final VoidCallback? onEnroll;

  const CourseCard({
    super.key,
    required this.title,
    this.description,
    required this.imageUrl,
    this.createdAt,
    this.progress = 0.0,
    this.isEnrolled = false,
    this.showEnrollButton = false,
    this.isTeacherView = false,
    this.instructorName,
    this.instructorRating,
    this.reviewCount,
    this.onTap,
    this.onEnroll,
  });

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (progress * 100).toInt();
    final isDark = AppTheme.isDarkMode(context);
    
    // Vibrant colors for dark mode
    final accentColor = isDark ? const Color(0xFF9B7DFF) : AppTheme.primaryColor;
    final tealAccent = isDark ? const Color(0xFF4ECDC4) : AppTheme.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppTheme.darkCard : Colors.white,
          border: isDark ? Border.all(color: accentColor.withOpacity(0.2)) : null,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course Image with overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    accentColor.withOpacity(0.8),
                                    tealAccent.withOpacity(0.6),
                                  ]
                                : [
                                    AppTheme.primaryColor.withOpacity(0.8),
                                    AppTheme.primaryLight.withOpacity(0.6),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.school,
                            size: 40,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Date badge
                if (createdAt != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface.withOpacity(0.9) : Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // Enrolled badge
                if (isEnrolled && !isTeacherView)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Enrolled',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Teacher badge
                if (isTeacherView)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tealAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Manage',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Course Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Instructor info (for explore/unenrolled courses)
                    if (instructorName != null && !isTeacherView) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 12,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              instructorName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (instructorRating != null &&
                          instructorRating! > 0) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${instructorRating!.toStringAsFixed(1)}${reviewCount != null && reviewCount! > 0 ? ' ($reviewCount)' : ''}',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ] else if (description != null &&
                        description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          description!,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Progress bar for enrolled courses
                    if (isEnrolled && !isTeacherView) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0
                                      ? AppTheme.success
                                      : tealAccent,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$progressPercent%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: progress >= 1.0
                                  ? AppTheme.success
                                  : tealAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress >= 1.0 ? '✓ Completed' : 'In Progress',
                        style: TextStyle(
                          fontSize: 10,
                          color: progress >= 1.0
                              ? AppTheme.success
                              : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                          fontWeight: progress >= 1.0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],

                    // Enroll button for non-enrolled courses
                    if (showEnrollButton && !isEnrolled) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onEnroll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Enroll Now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // View button for enrolled courses
                    if (isEnrolled && !isTeacherView && !showEnrollButton) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Continue Learning',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal Course Card for list views
class CourseCardHorizontal extends StatelessWidget {
  final String title;
  final String? description;
  final String imageUrl;
  final int? createdAt;
  final double progress;
  final int enrolledCount;
  final bool isTeacherView;
  final VoidCallback? onTap;

  const CourseCardHorizontal({
    super.key,
    required this.title,
    this.description,
    required this.imageUrl,
    this.createdAt,
    this.progress = 0.0,
    this.enrolledCount = 0,
    this.isTeacherView = false,
    this.onTap,
  });

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = (progress * 100).toInt();
    final isDark = AppTheme.isDarkMode(context);
    
    // Vibrant colors for dark mode
    final accentColor = isDark ? const Color(0xFF9B7DFF) : AppTheme.primaryColor;
    final tealAccent = isDark ? const Color(0xFF4ECDC4) : AppTheme.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppTheme.darkCard : Colors.white,
          border: isDark ? Border.all(color: accentColor.withOpacity(0.2)) : null,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
        child: Row(
          children: [
            // Course Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                accentColor.withOpacity(0.8),
                                tealAccent.withOpacity(0.6),
                              ]
                            : [
                                AppTheme.primaryColor.withOpacity(0.8),
                                AppTheme.primaryLight.withOpacity(0.6),
                              ],
                      ),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white54,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

            // Course Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Description
                    if (description != null)
                      Text(
                        description!,
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 8),

                    // Bottom info row
                    Row(
                      children: [
                        if (createdAt != null) ...[
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                        ],

                        if (isTeacherView) ...[
                          Icon(
                            Icons.people,
                            size: 12,
                            color: isDark ? tealAccent : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$enrolledCount students',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                            ),
                          ),
                        ] else ...[
                          // Progress for student view
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: progress >= 1.0
                                  ? AppTheme.success.withOpacity(isDark ? 0.2 : 0.1)
                                  : tealAccent.withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: isDark
                                  ? Border.all(
                                      color: (progress >= 1.0 ? AppTheme.success : tealAccent)
                                          .withOpacity(0.3),
                                    )
                                  : null,
                            ),
                            child: Text(
                              progress >= 1.0
                                  ? '✓ Complete'
                                  : '$progressPercent% done',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: progress >= 1.0
                                    ? AppTheme.success
                                    : tealAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Arrow icon
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right, 
                color: isDark ? accentColor.withOpacity(0.7) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
