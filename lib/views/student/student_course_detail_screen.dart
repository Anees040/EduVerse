import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/bookmark_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/advanced_video_player.dart';
import 'package:eduverse/widgets/qa_section_widget.dart';
import 'package:eduverse/views/student/certificate_screen.dart';

/// Student Course Detail Screen with Video Playlist
class StudentCourseDetailScreen extends StatefulWidget {
  final String courseUid;
  final String courseTitle;
  final String imageUrl;
  final String description;
  final int? createdAt;

  const StudentCourseDetailScreen({
    super.key,
    required this.courseUid,
    required this.courseTitle,
    required this.imageUrl,
    required this.description,
    this.createdAt,
  });

  @override
  State<StudentCourseDetailScreen> createState() =>
      _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
  final CourseService _courseService = CourseService();
  final BookmarkService _bookmarkService = BookmarkService();
  final String _studentUid = FirebaseAuth.instance.currentUser!.uid;

  List<Map<String, dynamic>> _videos = [];
  Map<String, dynamic> _progress = {};
  int _currentVideoIndex = 0;
  bool _isLoading = true;
  double _overallProgress = 0.0;
  bool _hasReviewed = false;
  String? _teacherUid;
  bool _isBookmarked = false;
  Duration _currentVideoPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadCourseData();
    _checkBookmarkStatus();
  }

  Future<void> _checkBookmarkStatus() async {
    final isBookmarked = await _bookmarkService.isBookmarked(
      studentUid: _studentUid,
      courseUid: widget.courseUid,
    );
    if (mounted) {
      setState(() => _isBookmarked = isBookmarked);
    }
  }

  Future<void> _toggleBookmark() async {
    final newStatus = await _bookmarkService.toggleBookmark(
      studentUid: _studentUid,
      courseUid: widget.courseUid,
      courseTitle: widget.courseTitle,
      imageUrl: widget.imageUrl,
    );
    setState(() => _isBookmarked = newStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus ? 'Added to bookmarks! 🔖' : 'Removed from bookmarks',
        ),
        backgroundColor: newStatus ? AppTheme.success : null,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _loadCourseData() async {
    setState(() => _isLoading = true);
    try {
      final videos = await _courseService.getCourseVideos(
        courseUid: widget.courseUid,
      );
      final progress = await _courseService.getCourseProgress(
        studentUid: _studentUid,
        courseUid: widget.courseUid,
      );
      final overallProgress = await _courseService.calculateCourseProgress(
        studentUid: _studentUid,
        courseUid: widget.courseUid,
      );

      // Get course details for teacher UID
      final courseDetails = await _courseService.getCourseDetails(
        courseUid: widget.courseUid,
      );

      // Check if user has reviewed
      final hasReviewed = await _courseService.hasStudentReviewedCourse(
        studentUid: _studentUid,
        courseUid: widget.courseUid,
      );

      // Find first uncompleted video
      int startIndex = 0;
      for (int i = 0; i < videos.length; i++) {
        final videoId = videos[i]['videoId'];
        if (progress[videoId] == null ||
            progress[videoId]['isCompleted'] != true) {
          startIndex = i;
          break;
        }
      }

      setState(() {
        _videos = videos;
        _progress = progress;
        _currentVideoIndex = startIndex;
        _overallProgress = overallProgress;
        _hasReviewed = hasReviewed;
        _teacherUid = courseDetails?['teacherUid'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading course: $e")));
      }
    }
  }

  void _onVideoPositionChanged(Duration position) async {
    if (_videos.isEmpty) return;

    // Track current position for Q&A timestamps
    _currentVideoPosition = position;

    final videoId = _videos[_currentVideoIndex]['videoId'];
    final isCompleted = position.inSeconds >= 30;

    await _courseService.saveVideoProgress(
      studentUid: _studentUid,
      courseUid: widget.courseUid,
      videoId: videoId,
      positionSeconds: position.inSeconds,
      isCompleted: isCompleted,
    );

    // Update local progress
    if (isCompleted &&
        (_progress[videoId] == null ||
            _progress[videoId]['isCompleted'] != true)) {
      setState(() {
        _progress[videoId] = {
          'positionSeconds': position.inSeconds,
          'isCompleted': true,
        };
        _overallProgress = _calculateLocalProgress();
      });
    }
  }

  double _calculateLocalProgress() {
    if (_videos.isEmpty) return 0.0;
    int completed = 0;
    for (final video in _videos) {
      if (_progress[video['videoId']]?['isCompleted'] == true) {
        completed++;
      }
    }
    return completed / _videos.length;
  }

  void _onVideoComplete() {
    // Mark current video as complete
    final videoId = _videos[_currentVideoIndex]['videoId'];
    setState(() {
      _progress[videoId] = {..._progress[videoId] ?? {}, 'isCompleted': true};
      _overallProgress = _calculateLocalProgress();
    });

    // Auto-play next video
    if (_currentVideoIndex < _videos.length - 1) {
      setState(() => _currentVideoIndex++);
    }
  }

  void _playVideo(int index) {
    setState(() => _currentVideoIndex = index);
  }

  Duration? _getStartPosition() {
    if (_videos.isEmpty) return null;
    final videoId = _videos[_currentVideoIndex]['videoId'];
    final progress = _progress[videoId];
    if (progress != null && progress['positionSeconds'] != null) {
      // Don't resume if completed
      if (progress['isCompleted'] == true) return Duration.zero;
      return Duration(seconds: progress['positionSeconds']);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
            )
          : Column(
              children: [
                // Fixed video player at top
                _buildVideoPlayer(),

                // Scrollable content below
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Course title bar
                        _buildTitleBar(),

                        // Progress indicator
                        _buildProgressSection(),

                        // Video list
                        _buildVideoList(),

                        // Course description
                        _buildDescription(),

                        // Q&A Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: QASectionWidget(
                            courseUid: widget.courseUid,
                            videoId: _videos.isNotEmpty
                                ? _videos[_currentVideoIndex]['videoId']
                                : null,
                            videoTitle: _videos.isNotEmpty
                                ? _videos[_currentVideoIndex]['title']
                                : null,
                            isTeacher: false,
                            courseName: widget.courseTitle,
                            getCurrentVideoPosition: () =>
                                _currentVideoPosition,
                            onTimestampTap: (duration) {
                              // Show a snackbar since we can't directly seek
                              // In a real implementation, you'd add seek functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Go to ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')} in the video',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTitleBar() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? AppTheme.darkPrimaryGradient
            : AppTheme.primaryGradient,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.courseTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Bookmark Button
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
            ),
            onPressed: _toggleBookmark,
            tooltip: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videos.isEmpty) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(
          child: Text(
            'No videos available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final currentVideo = _videos[_currentVideoIndex];

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: AdvancedVideoPlayer(
        key: ValueKey(currentVideo['videoId']), // Force rebuild on video change
        videoUrl: currentVideo['url'],
        videoTitle: currentVideo['title'],
        startPosition: _getStartPosition(),
        videoIndex: _currentVideoIndex,
        totalVideos: _videos.length,
        onPositionChanged: _onVideoPositionChanged,
        onVideoComplete: _onVideoComplete,
        onNext: _currentVideoIndex < _videos.length - 1
            ? () => _playVideo(_currentVideoIndex + 1)
            : null,
        onPrevious: _currentVideoIndex > 0
            ? () => _playVideo(_currentVideoIndex - 1)
            : null,
      ),
    );
  }

  Widget _buildProgressSection() {
    final isDark = AppTheme.isDarkMode(context);
    final progressPercent = (_overallProgress * 100).toInt();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _overallProgress >= 1.0
                      ? AppTheme.getSuccessColor(context).withOpacity(0.1)
                      : (isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor)
                            .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _overallProgress >= 1.0
                      ? Icons.emoji_events
                      : Icons.trending_up,
                  color: _overallProgress >= 1.0
                      ? AppTheme.getSuccessColor(context)
                      : (isDark
                            ? AppTheme.darkPrimaryLight
                            : AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _overallProgress >= 1.0
                          ? 'Course Completed! 🎉'
                          : 'Your Progress',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_countCompletedVideos()} of ${_videos.length} videos completed',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _overallProgress >= 1.0
                      ? AppTheme.getSuccessColor(context)
                      : (isDark
                            ? AppTheme.darkPrimaryLight
                            : AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _overallProgress,
              backgroundColor: isDark
                  ? AppTheme.darkBorder
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _overallProgress >= 1.0
                    ? AppTheme.getSuccessColor(context)
                    : (isDark ? AppTheme.darkAccent : AppTheme.accentColor),
              ),
              minHeight: 10,
            ),
          ),
          // Show review button when course is completed
          if (_overallProgress >= 1.0) ...[
            const SizedBox(height: 16),
            _hasReviewed
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.getSuccessColor(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.getSuccessColor(
                          context,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.getSuccessColor(context),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thank you for your review!',
                          style: TextStyle(
                            color: AppTheme.getSuccessColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isDark
                                      ? AppTheme.darkAccent
                                      : AppTheme.accentColor)
                                  .withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _showReviewDialog,
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Leave a Review'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.accentColor,
                        foregroundColor: const Color(0xFFF0F8FF),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
            // Certificate button
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _viewCertificate,
                icon: const Icon(Icons.workspace_premium),
                label: const Text('View Certificate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700), // Gold
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _countCompletedVideos() {
    int count = 0;
    for (final video in _videos) {
      if (_progress[video['videoId']]?['isCompleted'] == true) {
        count++;
      }
    }
    return count;
  }

  Widget _buildVideoList() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: AppTheme.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.playlist_play,
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Course Videos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_videos.length} videos',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkPrimaryLight
                          : AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.getDividerColor(context)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _videos.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppTheme.getDividerColor(context)),
            itemBuilder: (context, index) => _buildVideoItem(index),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(int index) {
    final isDark = AppTheme.isDarkMode(context);
    final video = _videos[index];
    final isPlaying = index == _currentVideoIndex;
    final isCompleted = _progress[video['videoId']]?['isCompleted'] == true;

    return InkWell(
      onTap: () => _playVideo(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        color: isPlaying
            ? (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                  .withOpacity(0.05)
            : null,
        child: Row(
          children: [
            // Video number with status
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppTheme.getSuccessColor(context)
                    : isPlaying
                    ? (isDark
                          ? AppTheme.darkPrimaryLight
                          : AppTheme.primaryColor)
                    : (isDark ? AppTheme.darkElevated : Colors.grey.shade200),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : isPlaying
                    ? const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // Video info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? 'Video ${index + 1}',
                    style: TextStyle(
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                      color: isPlaying
                          ? (isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor)
                          : AppTheme.getTextPrimary(context),
                    ),
                  ),
                  if (video['description'] != null &&
                      video['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        video['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // Status badge
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.getSuccessColor(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '✓ Done',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.getSuccessColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (isPlaying)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? AppTheme.darkPrimaryLight
                              : AppTheme.primaryColor)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle,
                      size: 14,
                      color: isDark
                          ? AppTheme.darkPrimaryLight
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Playing',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkPrimaryLight
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'About This Course',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.description.isNotEmpty
                ? widget.description
                : 'No description provided.',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewCertificate() async {
    // Get student name from Firebase
    final studentSnapshot = await FirebaseDatabase.instance
        .ref()
        .child('student')
        .child(_studentUid)
        .get();

    String studentName = 'Student';
    if (studentSnapshot.exists && studentSnapshot.value != null) {
      final data = Map<String, dynamic>.from(studentSnapshot.value as Map);
      studentName = data['name'] ?? 'Student';
    }

    // Navigate to certificate screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CertificateScreen(
            studentName: studentName,
            courseName: widget.courseTitle,
            performance: _overallProgress,
            completionDate: DateTime.now(),
          ),
        ),
      );
    }
  }

  void _showReviewDialog() {
    double rating = 5.0;
    final reviewController = TextEditingController();
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.rate_review,
                  color: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rate This Course',
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How would you rate "${widget.courseTitle}"?',
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
                ),
                const SizedBox(height: 20),
                // Star rating
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            rating = index + 1.0;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _getRatingText(rating),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: reviewController,
                  maxLines: 4,
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  decoration: InputDecoration(
                    hintText:
                        'Share your experience with this course (optional)',
                    hintStyle: TextStyle(color: AppTheme.getTextHint(context)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.getBorderColor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.getBorderColor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppTheme.darkPrimaryLight
                            : AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _submitReview(rating, reviewController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.accentColor,
                foregroundColor: const Color(0xFFF0F8FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 6,
                shadowColor:
                    (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                        .withOpacity(0.5),
              ),
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    switch (rating.toInt()) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Future<void> _submitReview(double rating, String reviewText) async {
    if (_teacherUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit review. Please try again.'),
        ),
      );
      return;
    }

    try {
      // Get student name
      final studentSnap = await FirebaseDatabase.instance
          .ref()
          .child('student')
          .child(_studentUid)
          .child('name')
          .get();
      final studentName = studentSnap.exists
          ? studentSnap.value.toString()
          : 'Anonymous';

      await _courseService.submitCourseReview(
        studentUid: _studentUid,
        courseUid: widget.courseUid,
        teacherUid: _teacherUid!,
        rating: rating,
        reviewText: reviewText,
        studentName: studentName,
      );

      setState(() {
        _hasReviewed = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review! ⭐'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to submit review: $e')));
      }
    }
  }
}
