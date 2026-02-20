import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:eduverse/services/video_player_widget.dart';
import 'package:eduverse/utils/app_theme.dart';

class CourseDetailScreen extends StatelessWidget {
  final String courseTitle;
  final int enrolledStudents;
  final String imageUrl;
  final String description;
  final String? videoUrl;
  final int? createdAt; // milliseconds since epoch

  const CourseDetailScreen({
    super.key,
    required this.courseTitle,
    required this.enrolledStudents,
    required this.imageUrl,
    required this.description,
    required this.videoUrl,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(courseTitle),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, color: Colors.grey),
                  )
                : Container(
                    width: double.infinity,
                    height: 200,
                    color: isDark ? AppTheme.darkCard : Colors.grey.shade300,
                    child: Icon(
                      Icons.image,
                      size: 50,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
            const SizedBox(height: 16),

            // Enrolled students
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "$enrolledStudents students enrolled",
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Created at
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Created at: ${DateTime.fromMillisecondsSinceEpoch(createdAt!).toLocal()}",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ),
            Divider(height: 32, color: AppTheme.getDividerColor(context)),

            // Course overview / description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Course Overview",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                description.isNotEmpty
                    ? description
                    : "No description provided",
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Video section
            if (videoUrl != null && videoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Course Video",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayerWidget(
                        videoUrl: videoUrl!,
                      ), // Custom widget to play video
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
