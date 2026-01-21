import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eduverse/services/thumbnail_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Widget that displays a video thumbnail with loading state
/// Uses Cloudinary's URL transformation for fast thumbnail loading
class VideoThumbnailWidget extends StatelessWidget {
  final String videoUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? videoNumber;
  final bool showPlayIcon;
  final bool isPlaying;
  final bool isCompleted;
  final bool isPublic;
  final bool showVisibilityBadge;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    this.width = 140,
    this.height = 90,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.videoNumber,
    this.showPlayIcon = true,
    this.isPlaying = false,
    this.isCompleted = false,
    this.isPublic = true,
    this.showVisibilityBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.primaryColor;
    final radius = borderRadius ?? BorderRadius.circular(12);

    // Get Cloudinary thumbnail URL
    final thumbnailService = ThumbnailService();
    final thumbnailUrl = thumbnailService.getCloudinaryThumbnailUrl(videoUrl);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail image from Cloudinary or gradient fallback
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    _buildLoadingPlaceholder(isDark, accentColor),
                errorWidget: (context, url, error) =>
                    _buildGradientPlaceholder(isDark, accentColor),
              )
            else
              _buildGradientPlaceholder(isDark, accentColor),

            // Overlay for playing state
            if (isPlaying)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Icon(Icons.graphic_eq, size: 36, color: Colors.white),
                ),
              ),

            // Completed overlay
            if (isCompleted && !isPlaying)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),

            // Video number badge
            if (videoNumber != null)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$videoNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Play icon overlay (when not playing)
            if (showPlayIcon && !isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),

            // Visibility badge (for teacher view)
            if (showVisibilityBadge)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isPublic
                        ? AppTheme.success.withOpacity(0.9)
                        : Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPublic ? Icons.public : Icons.lock_outline,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isPublic ? 'Public' : 'Private',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(bool isDark, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(isDark ? 0.2 : 0.15),
            (isDark ? AppTheme.darkAccent : AppTheme.accentColor).withOpacity(
              isDark ? 0.3 : 0.25,
            ),
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientPlaceholder(bool isDark, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(isDark ? 0.3 : 0.2),
            (isDark ? AppTheme.darkAccent : AppTheme.accentColor).withOpacity(
              isDark ? 0.4 : 0.3,
            ),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          size: 32,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}
