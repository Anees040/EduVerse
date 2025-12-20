import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';

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
  final int? enrolledCount;
  final int? videoCount;
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
    this.enrolledCount,
    this.videoCount,
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
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;
    final tealAccent = isDark ? const Color(0xFF4ECDC4) : AppTheme.accentColor;
    // Use same color as the 'Create Course' button:
    // - Light theme: primaryColor
    // - Dark theme: darkPrimaryLight
    final buttonColor = isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? AppTheme.darkCard : Colors.white,
          border: Border.all(
            color: isDark ? tealAccent.withOpacity(0.25) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? tealAccent.withOpacity(0.12)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              spreadRadius: 0,
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
                      aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [accentColor.withOpacity(0.8), tealAccent.withOpacity(0.6)]
                                : [AppTheme.primaryColor.withOpacity(0.8), AppTheme.primaryLight.withOpacity(0.6)],
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
                // Date chip moved below image to improve card balance (see bottom of card)
                // Top-right small enroll/continue badge removed to keep single primary action button
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(builder: (context, constraints) {
                final cardWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
                final isCompact = cardWidth < 160;
                // responsive font sizes (titleFont not needed directly here)
                final descFont = isCompact ? 10.0 : 12.0;
                final smallTextFont = isCompact ? 10.0 : 11.0;
                final avatarSize = isCompact ? 22.0 : 28.0;
                final iconSize = isCompact ? 12.0 : 14.0;
                final progressHeight = 6.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Instructor name and rating row (more interactive feel)
                  if (instructorName != null || instructorRating != null) ...[
                    SizedBox(height: isCompact ? 4 : 6),
                    Row(
                      children: [
                        // Instructor initial avatar
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            instructorName != null && instructorName!.isNotEmpty
                                ? instructorName!.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
                                : 'T',
                            style: TextStyle(
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              fontSize: isCompact ? 10 : 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 6 : 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (instructorName != null) ...[
                                Text(
                                  instructorName!,
                                  style: TextStyle(
                                    fontSize: isCompact ? 11 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              Row(
                                children: [
                                  if (instructorRating != null) ...[
                                    Icon(Icons.star, size: iconSize, color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor),
                                    SizedBox(width: isCompact ? 4 : 6),
                                    Text(
                                      instructorRating!.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: smallTextFont,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                      ),
                                    ),
                                    SizedBox(width: isCompact ? 4 : 6),
                                  ],
                                  if (reviewCount != null) ...[
                                    Text(
                                      '(${reviewCount.toString()})',
                                      style: TextStyle(
                                        fontSize: isCompact ? 10 : 11,
                                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  // For teacher view show quick stats (students, videos)
                  if (isTeacherView) ...[
                    SizedBox(height: isCompact ? 4 : 6),
                    Row(
                      children: [
                        Icon(Icons.people, size: iconSize, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                        SizedBox(width: isCompact ? 6 : 8),
                        Text(
                          '${enrolledCount ?? 0} students',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                            fontSize: isCompact ? 11 : 12,
                          ),
                        ),
                        SizedBox(width: isCompact ? 10 : 12),
                        Icon(Icons.video_collection, size: iconSize, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600),
                        SizedBox(width: isCompact ? 6 : 8),
                        Text(
                          '${videoCount ?? 0} videos',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
                            fontSize: isCompact ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ] else if (description != null && description!.isNotEmpty) ...[
                    SizedBox(height: isCompact ? 4 : 6),
                    Text(
                      description!,
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        fontSize: descFont,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // show video count for student/explore cards in a compact manner
                    if (!isTeacherView && videoCount != null) ...[
                      SizedBox(height: isCompact ? 6 : 8),
                      Row(
                        children: [
                          Icon(Icons.video_collection, size: iconSize, color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor),
                          SizedBox(width: isCompact ? 6 : 8),
                          Text(
                            videoCount! > 1 ? '$videoCount videos' : '$videoCount video',
                            style: TextStyle(
                              fontSize: isCompact ? 11 : 12,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  // Date placed above the primary action to make the card feel interactive
                  if (createdAt != null) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: isCompact ? 2 : 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface.withOpacity(0.9) : Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 10 : 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                  ],
                  // Show a progress bar for enrolled courses to make the card more interactive
                  if (isEnrolled) ...[
                    SizedBox(height: isCompact ? 4 : 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: progressHeight,
                              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                            ),
                          ),
                        ),
                        SizedBox(width: isCompact ? 6 : 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 6 : 8),
                  ],
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: buttonColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isTeacherView ? (onTap ?? onEnroll) : (isEnrolled ? onTap : onEnroll),
                      icon: Icon(
                        isTeacherView ? Icons.settings : (isEnrolled ? Icons.play_arrow_rounded : Icons.add_rounded),
                        size: isCompact ? 14 : 16,
                      ),
                      label: Text(
                        isTeacherView ? 'Manage' : (isEnrolled ? 'Continue' : 'Enroll'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                        style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, isCompact ? 36 : 40),
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 6 : 8),
                        alignment: Alignment.center,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                );
              }),
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
    final accentColor = isDark
        ? const Color(0xFF9B7DFF)
        : AppTheme.primaryColor;
    final tealAccent = isDark ? const Color(0xFF4ECDC4) : AppTheme.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppTheme.darkCard : Colors.white,
          border: isDark
              ? Border.all(color: accentColor.withOpacity(0.2))
              : null,
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
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
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
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
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
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : Colors.grey.shade600,
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
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : Colors.grey.shade600,
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
                                  ? AppTheme.success.withOpacity(
                                      isDark ? 0.2 : 0.1,
                                    )
                                  : tealAccent.withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: isDark
                                  ? Border.all(
                                      color:
                                          (progress >= 1.0
                                                  ? AppTheme.success
                                                  : tealAccent)
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

            // trailing chevron removed to save vertical space and avoid overflow
          ],
        ),
      ),
    );
  }
}
