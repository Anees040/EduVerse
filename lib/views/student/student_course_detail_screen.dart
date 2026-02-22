import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/bookmark_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/services/analytics_service.dart';
import 'package:eduverse/services/certificate_service.dart';
import 'package:eduverse/services/study_streak_service.dart';
import 'package:eduverse/services/learning_stats_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/advanced_video_player.dart';
import 'package:eduverse/widgets/qa_section_widget.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';
import 'package:eduverse/widgets/video_thumbnail_widget.dart';
import 'package:eduverse/widgets/course_notes_sheet.dart';
import 'package:eduverse/views/student/certificate_screen.dart';
import 'package:eduverse/views/student/courses_screen.dart';
import 'package:eduverse/views/student/profile_screen.dart';
import 'package:eduverse/views/student/home_tab.dart';
import 'package:eduverse/views/student/student_quiz_list_screen.dart';
import 'package:eduverse/views/student/student_assignment_list_screen.dart';
import 'package:eduverse/views/teacher/teacher_analytics_screen.dart';
import 'package:eduverse/views/teacher/teacher_home_tab.dart';
import 'package:eduverse/widgets/teacher_public_profile_widget.dart';

/// Student Course Detail Screen with Video Playlist
class StudentCourseDetailScreen extends StatefulWidget {
  final String courseUid;
  final String courseTitle;
  final String imageUrl;
  final String description;
  final int? createdAt;
  final String? initialVideoId;
  final int? initialVideoTimestampSeconds;

  const StudentCourseDetailScreen({
    super.key,
    required this.courseUid,
    required this.courseTitle,
    required this.imageUrl,
    required this.description,
    this.createdAt,
    this.initialVideoId,
    this.initialVideoTimestampSeconds,
  });

  @override
  State<StudentCourseDetailScreen> createState() =>
      _StudentCourseDetailScreenState();
}

class _StudentCourseDetailScreenState extends State<StudentCourseDetailScreen> {
  final CourseService _courseService = CourseService();
  final BookmarkService _bookmarkService = BookmarkService();
  final CacheService _cacheService = CacheService();
  final CertificateService _certificateService = CertificateService();
  final String _studentUid = FirebaseAuth.instance.currentUser!.uid;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _videos = [];
  Map<String, dynamic> _progress = {};
  int _currentVideoIndex = 0;
  bool _isLoading = true;
  double _overallProgress = 0.0;
  bool _hasReviewed = false;
  String? _teacherUid;
  bool _isBookmarked = false;
  Duration _currentVideoPosition = Duration.zero;
  bool _isVideosExpanded = false; // Default to collapsed for consistency
  int _privateVideoCount = 0; // Number of private videos
  bool _isVideoMinimized = false; // For picture-in-picture style
  bool _certificateAwarded = false; // Track if certificate was just awarded
  bool _isTransitioning = false; // For smooth transition

  @override
  void initState() {
    super.initState();
    _loadCourseData();
    _checkBookmarkStatus();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Clear all caches on exit so parent screens refresh with latest progress
    _clearAllProgressCaches();
    super.dispose();
  }

  /// Clear all progress-related caches to ensure fresh data on other screens
  void _clearAllProgressCaches() {
    _cacheService.clearStudentProgressCache(_studentUid);
    CoursesScreen.clearCache();
    ProfileScreen.clearCache();
    HomeTab.clearCache();
    // Also clear teacher caches so insights update in real-time
    TeacherAnalyticsScreen.clearCache();
    TeacherHomeTab.clearCache();
    AnalyticsService.clearCache();
  }

  void _onScroll() {
    // When user scrolls past the video height, minimize the video
    final videoHeight = MediaQuery.of(context).size.width * 9 / 16;
    final shouldMinimize = _scrollController.offset > videoHeight + 50;
    if (shouldMinimize != _isVideoMinimized && !_isTransitioning) {
      _isTransitioning = true;
      setState(() => _isVideoMinimized = shouldMinimize);
      // Allow smooth transition to complete
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _isTransitioning = false;
      });
    }
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
    final cacheKey = 'course_detail_${widget.courseUid}_$_studentUid';

    // Check cache first for instant display
    final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
    if (cachedData != null) {
      setState(() {
        _videos = List<Map<String, dynamic>>.from(cachedData['videos'] ?? []);
        _progress = Map<String, dynamic>.from(cachedData['progress'] ?? {});
        _overallProgress = cachedData['overallProgress'] ?? 0.0;
        _hasReviewed = cachedData['hasReviewed'] ?? false;
        _teacherUid = cachedData['teacherUid'];
        _privateVideoCount = cachedData['privateVideoCount'] ?? 0;
        _currentVideoIndex = _determineStartIndex(_videos, _progress);
        _isLoading = false;
      });
      // Refresh in background
      _refreshCourseDataInBackground(cacheKey);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Load all data in PARALLEL for faster loading
      final results = await Future.wait([
        _courseService.getPublicCourseVideos(courseUid: widget.courseUid),
        _courseService.getCourseProgress(
          studentUid: _studentUid,
          courseUid: widget.courseUid,
        ),
        _courseService.calculateCourseProgress(
          studentUid: _studentUid,
          courseUid: widget.courseUid,
        ),
        _courseService.getCourseDetails(courseUid: widget.courseUid),
        _courseService.hasStudentReviewedCourse(
          studentUid: _studentUid,
          courseUid: widget.courseUid,
        ),
        _courseService.getCourseVideos(
          courseUid: widget.courseUid,
        ), // Get all videos for count
      ]);

      final videos = results[0] as List<Map<String, dynamic>>;
      final progress = results[1] as Map<String, dynamic>;
      final overallProgress = results[2] as double;
      final courseDetails = results[3] as Map<String, dynamic>?;
      final hasReviewed = results[4] as bool;
      final allVideos = results[5] as List<Map<String, dynamic>>;

      // Calculate private video count
      final totalCount = allVideos.length;
      final publicCount = videos.length;
      final privateCount = totalCount - publicCount;

      // Cache the results
      _cacheService.set(cacheKey, {
        'videos': videos,
        'progress': progress,
        'overallProgress': overallProgress,
        'hasReviewed': hasReviewed,
        'teacherUid': courseDetails?['teacherUid'],
        'privateVideoCount': privateCount,
      });

      // Determine start index: if notification requested a specific video, use it
      int startIndex = _determineStartIndex(videos, progress);

      setState(() {
        _videos = videos;
        _progress = progress;
        _currentVideoIndex = startIndex;
        _overallProgress = overallProgress;
        _hasReviewed = hasReviewed;
        _teacherUid = courseDetails?['teacherUid'];
        _privateVideoCount = privateCount;
        // If notification provided a timestamp for the initial video, seed local progress
        if (widget.initialVideoId != null &&
            widget.initialVideoTimestampSeconds != null) {
          final vid = widget.initialVideoId!;
          if (_progress[vid] == null) {
            _progress[vid] = {
              'positionSeconds': widget.initialVideoTimestampSeconds,
            };
          }
        }
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

  int _determineStartIndex(
    List<Map<String, dynamic>> videos,
    Map<String, dynamic> progress,
  ) {
    if (widget.initialVideoId != null) {
      final idx = videos.indexWhere(
        (v) => v['videoId'] == widget.initialVideoId,
      );
      if (idx != -1) return idx;
    }
    // Find first incomplete video
    for (int i = 0; i < videos.length; i++) {
      final videoId = videos[i]['videoId'];
      if (progress[videoId] == null ||
          progress[videoId]['isCompleted'] != true) {
        return i;
      }
    }
    return 0;
  }

  Future<void> _refreshCourseDataInBackground(String cacheKey) async {
    try {
      final results = await Future.wait([
        _courseService.getPublicCourseVideos(courseUid: widget.courseUid),
        _courseService.getCourseProgress(
          studentUid: _studentUid,
          courseUid: widget.courseUid,
        ),
        _courseService.calculateCourseProgress(
          studentUid: _studentUid,
          courseUid: widget.courseUid,
        ),
        _courseService.getCourseDetails(courseUid: widget.courseUid),
        _courseService.hasStudentReviewedCourse(
          studentUid: _studentUid,
          courseUid: widget.courseUid,
        ),
        _courseService.getCourseVideos(
          courseUid: widget.courseUid,
        ), // Get all videos for count
      ]);

      final videos = results[0] as List<Map<String, dynamic>>;
      final progress = results[1] as Map<String, dynamic>;
      final overallProgress = results[2] as double;
      final courseDetails = results[3] as Map<String, dynamic>?;
      final hasReviewed = results[4] as bool;
      final allVideos = results[5] as List<Map<String, dynamic>>;

      // Calculate private video count
      final totalCount = allVideos.length;
      final publicCount = videos.length;
      final privateCount = totalCount - publicCount;

      // Update cache
      _cacheService.set(cacheKey, {
        'videos': videos,
        'progress': progress,
        'overallProgress': overallProgress,
        'hasReviewed': hasReviewed,
        'teacherUid': courseDetails?['teacherUid'],
        'privateVideoCount': privateCount,
      });

      if (mounted) {
        setState(() {
          _videos = videos;
          _progress = progress;
          _overallProgress = overallProgress;
          _hasReviewed = hasReviewed;
          _teacherUid = courseDetails?['teacherUid'];
          _privateVideoCount = privateCount;
        });
      }
    } catch (_) {
      // Silent fail for background refresh
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

    // Update local progress when video is completed
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

      // Clear all caches so other screens get fresh data
      _clearAllProgressCaches();
    }
  }

  double _calculateLocalProgress() {
    // Calculate using total videos (public + private) to match card progress
    final totalVideos = _videos.length + _privateVideoCount;
    if (totalVideos == 0) return 0.0;

    int completed = 0;
    for (final video in _videos) {
      if (_progress[video['videoId']]?['isCompleted'] == true) {
        completed++;
      }
    }
    // Divide completed public videos by total all videos (public + private)
    return completed / totalVideos;
  }

  Future<void> _onVideoComplete() async {
    // Mark current video as complete
    final videoId = _videos[_currentVideoIndex]['videoId'];
    setState(() {
      _progress[videoId] = {..._progress[videoId] ?? {}, 'isCompleted': true};
      _overallProgress = _calculateLocalProgress();
    });

    // Persist completion to backend
    try {
      final pos = _currentVideoPosition.inSeconds;
      await _courseService.saveVideoProgress(
        studentUid: _studentUid,
        courseUid: widget.courseUid,
        videoId: videoId,
        positionSeconds: pos,
        isCompleted: true,
      );

      // Clear all caches so other screens get fresh data
      _clearAllProgressCaches();

      // Record study activity for streak & stats tracking
      StudyStreakService().recordStudyActivity();
      LearningStatsService().logStudySession(
        durationSeconds: pos > 0 ? pos : 60,
        activityType: 'video',
        courseId: widget.courseUid,
        videoId: videoId,
      );

      // Check if course is now complete and award certificate
      if (_overallProgress >= 1.0 && !_certificateAwarded) {
        await _checkAndAwardCertificate();
      }
    } catch (_) {
      // ignore save errors here
    }

    // Auto-play next video
    if (_currentVideoIndex < _videos.length - 1) {
      setState(() => _currentVideoIndex++);
    }
  }

  /// Check and award certificate when course is completed
  Future<void> _checkAndAwardCertificate() async {
    try {
      // Get student name
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

      final certificateId = await _certificateService
          .checkAndAwardCourseCertificate(
            studentId: _studentUid,
            courseId: widget.courseUid,
            courseName: widget.courseTitle,
            studentName: studentName,
            completionPercentage: _overallProgress,
          );

      if (certificateId != null && mounted) {
        setState(() => _certificateAwarded = true);

        // Show celebration dialog
        _showCertificateAwardedDialog(studentName);
      }
    } catch (e) {
      // Certificate awarding is non-critical
    }
  }

  /// Show a celebration dialog when certificate is awarded
  void _showCertificateAwardedDialog(String studentName) {
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                size: 64,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '🎉 Congratulations! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ve completed this course!',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A certificate has been added to your profile.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _viewCertificate();
            },
            icon: const Icon(Icons.workspace_premium),
            label: const Text('View Certificate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
          ? const Center(
              child: EngagingLoadingIndicator(
                message: 'Loading course...',
                size: 80,
              ),
            )
          : Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Pinned app bar with back button
                    _buildSliverAppBar(),

                    // Video player (placeholder space when minimized)
                    SliverToBoxAdapter(
                      child: _isVideoMinimized
                          ? SizedBox(
                              height:
                                  MediaQuery.of(context).size.width * 9 / 16,
                            )
                          : _buildVideoPlayer(),
                    ),

                    // Progress indicator
                    SliverToBoxAdapter(child: _buildProgressSection()),

                    // Video list
                    SliverToBoxAdapter(child: _buildVideoList()),

                    // Course description
                    SliverToBoxAdapter(child: _buildDescription()),

                    // Meet Your Instructor section
                    if (_teacherUid != null)
                      SliverToBoxAdapter(child: _buildInstructorSection()),

                    // Quiz & Assignment Section
                    SliverToBoxAdapter(child: _buildQuizAssignmentSection()),

                    // Q&A Section
                    SliverToBoxAdapter(
                      child: Padding(
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
                          getCurrentVideoPosition: () => _currentVideoPosition,
                          onTimestampTap: (duration) {
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
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),

                // Floating mini video player when scrolled - smooth animated transition
                if (_videos.isNotEmpty)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    top: _isVideoMinimized
                        ? MediaQuery.of(context).padding.top + kToolbarHeight
                        : -(MediaQuery.of(context).size.width * 9 / 16 + 50),
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isVideoMinimized ? 1.0 : 0.0,
                      child: Material(
                        elevation: 8,
                        child: GestureDetector(
                          onVerticalDragEnd: (details) {
                            // Swipe up to expand
                            if (details.velocity.pixelsPerSecond.dy < -100) {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildVideoPlayer(),
                                // Swipe indicator bar (no text, just visual indicator)
                                GestureDetector(
                                  onTap: () {
                                    _scrollController.animateTo(
                                      0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    color: isDark
                                        ? AppTheme.darkSurface
                                        : Colors.grey.shade100,
                                    child: Center(
                                      child: Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? AppTheme.darkTextSecondary
                                                    .withOpacity(0.5)
                                              : Colors.grey.shade400,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    final isDark = AppTheme.isDarkMode(context);
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 0, // No expanded height, just the bar
      backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.courseTitle,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.note_alt_outlined, color: Colors.white),
          tooltip: 'Course Notes',
          onPressed: () {
            final videoTitle = _videos.isNotEmpty
                ? _videos[_currentVideoIndex]['title'] as String?
                : null;
            final videoId = _videos.isNotEmpty
                ? _videos[_currentVideoIndex]['videoId'] as String?
                : null;
            CourseNotesSheet.show(
              context,
              courseId: widget.courseUid,
              courseTitle: widget.courseTitle,
              currentVideoId: videoId,
              currentVideoTitle: videoTitle,
            );
          },
        ),
      ],
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
                      '${_countCompletedVideos()} of ${_videos.length + _privateVideoCount} videos completed',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                    if (_privateVideoCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '($_privateVideoCount private video${_privateVideoCount > 1 ? 's' : ''})',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(
                              context,
                            ).withOpacity(0.7),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Bookmark button - more accessible
              GestureDetector(
                onTap: _toggleBookmark,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _isBookmarked
                        ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                              .withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isBookmarked
                          ? (isDark
                                ? AppTheme.darkAccent
                                : AppTheme.accentColor)
                          : AppTheme.getTextSecondary(context).withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: _isBookmarked
                        ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                        : AppTheme.getTextSecondary(context),
                    size: 22,
                  ),
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
          InkWell(
            onTap: () {
              setState(() {
                _isVideosExpanded = !_isVideosExpanded;
              });
            },
            child: Padding(
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
                  const SizedBox(width: 8),
                  Icon(
                    _isVideosExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_videos.length} video${_videos.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_privateVideoCount > 0) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock,
                            size: 12,
                            color: isDark
                                ? AppTheme.darkWarning
                                : AppTheme.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '+$_privateVideoCount',
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.darkWarning
                                  : AppTheme.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isVideosExpanded) ...[
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
        ],
      ),
    );
  }

  Widget _buildVideoItem(int index) {
    final isDark = AppTheme.isDarkMode(context);
    final video = _videos[index];
    final isPlaying = index == _currentVideoIndex;
    final isCompleted = _progress[video['videoId']]?['isCompleted'] == true;
    final accentColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.primaryColor;
    final videoUrl = video['url'] ?? '';

    return InkWell(
      onTap: () => _playVideo(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(color: accentColor, width: 2)
              : (isDark ? Border.all(color: AppTheme.darkBorderColor) : null),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail section with actual video thumbnail
            VideoThumbnailWidget(
              videoUrl: videoUrl,
              width: 130,
              height: 80,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              videoNumber: index + 1,
              isPlaying: isPlaying,
              isCompleted: isCompleted,
              showPlayIcon: !isPlaying,
            ),
            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      video['title'] ?? 'Video ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isPlaying
                            ? accentColor
                            : AppTheme.getTextPrimary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Description or status
                    if (video['description'] != null &&
                        video['description'].toString().isNotEmpty)
                      Text(
                        video['description'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      )
                    else
                      Text(
                        'No description',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Status badge
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isPlaying)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.graphic_eq,
                              size: 12,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Now Playing',
                              style: TextStyle(
                                fontSize: 10,
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

  Widget _buildInstructorSection() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getCardDecoration(context),
      child: InkWell(
        onTap: () {
          if (_teacherUid != null) {
            TeacherPublicProfileWidget.showProfile(
              context: context,
              teacherUid: _teacherUid!,
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppTheme.darkAccent.withOpacity(0.2),
                          AppTheme.darkPrimaryLight.withOpacity(0.1),
                        ]
                      : [
                          AppTheme.primaryColor.withOpacity(0.1),
                          AppTheme.accentColor.withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school,
                size: 28,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meet Your Instructor',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Learn about their background & expertise',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizAssignmentSection() {
    final isDark = AppTheme.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Icon(
                Icons.assignment,
                size: 20,
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Assessments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quiz and Assignment Cards
          Row(
            children: [
              // Quiz Card
              Expanded(
                child: _buildStudentAssessmentCard(
                  icon: Icons.quiz,
                  title: 'Quizzes',
                  subtitle: 'Test your knowledge',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentQuizListScreen(
                          courseId: widget.courseUid,
                          courseName: widget.courseTitle,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Assignment Card
              Expanded(
                child: _buildStudentAssessmentCard(
                  icon: Icons.assignment_turned_in,
                  title: 'Assignments',
                  subtitle: 'Complete tasks',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentAssignmentListScreen(
                          courseId: widget.courseUid,
                          courseName: widget.courseTitle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAssessmentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode(context);

    return Material(
      color: isDark ? AppTheme.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppTheme.getTextSecondary(context),
              ),
            ],
          ),
        ),
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
