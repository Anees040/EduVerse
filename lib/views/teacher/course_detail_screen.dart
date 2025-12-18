import 'package:flutter/material.dart';
import 'package:eduverse/services/video_player_widget.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(courseTitle),
        backgroundColor: const Color.fromARGB(255, 17, 51, 96),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image, size: 50, color: Colors.grey),
                  ),
            const SizedBox(height: 16),

            // Enrolled students
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "$enrolledStudents students enrolled",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),

            // Created at
            if (createdAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Created at: ${DateTime.fromMillisecondsSinceEpoch(createdAt!).toLocal()}",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            const Divider(height: 32),

            // Course overview / description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Course Overview",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                description.isNotEmpty ? description : "No description provided",
                style: const TextStyle(fontSize: 16),
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
                    const Text(
                      "Course Video",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayerWidget(videoUrl: videoUrl!), // Custom widget to play video
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
