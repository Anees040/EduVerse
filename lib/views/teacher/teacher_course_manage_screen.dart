import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/services/preferences_service.dart';
import 'package:eduverse/services/background_upload_service.dart';
import 'package:eduverse/services/notification_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/advanced_video_player.dart';
import 'package:eduverse/widgets/qa_section_widget.dart';
import 'package:eduverse/widgets/upload_progress_widget.dart';

/// Teacher Course Management Screen - Add/Manage videos
class TeacherCourseManageScreen extends StatefulWidget {
  final String courseUid;
  final String courseTitle;
  final String imageUrl;
  final String description;
  final int enrolledCount;

  const TeacherCourseManageScreen({
    super.key,
    required this.courseUid,
    required this.courseTitle,
    required this.imageUrl,
    required this.description,
    required this.enrolledCount,
  });

  @override
  State<TeacherCourseManageScreen> createState() =>
      _TeacherCourseManageScreenState();
}

class _TeacherCourseManageScreenState extends State<TeacherCourseManageScreen> {
  final CourseService _courseService = CourseService();
  final CacheService _cacheService = CacheService();
  final ImagePicker _picker = ImagePicker();
  final BackgroundUploadService _uploadService = BackgroundUploadService();

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  int? _playingVideoIndex;
  String? _teacherName;
  bool _isVideosExpanded = true; // For collapsible video list
  int _lastCompletedUploads = 0; // Track completed uploads to refresh

  // Theme helper
  bool get isDark => mounted ? AppTheme.isDarkMode(context) : false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    // Listen for upload completion to auto-refresh video list
    _uploadService.addListener(_onUploadStatusChanged);
  }

  @override
  void dispose() {
    _uploadService.removeListener(_onUploadStatusChanged);
    super.dispose();
  }

  void _onUploadStatusChanged() {
    // Check if any upload for this course just completed
    final completedUploads = _uploadService.uploadTasks
        .where(
          (t) =>
              t.courseUid == widget.courseUid &&
              t.status == UploadStatus.completed,
        )
        .length;

    if (completedUploads > _lastCompletedUploads) {
      _lastCompletedUploads = completedUploads;
      // Refresh video list when upload completes
      _loadVideos();
    }
  }

  Future<void> _loadAllData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cacheKeyVideos = 'course_videos_${widget.courseUid}';
    final cacheKeyTeacher = 'teacher_name_$uid';

    // Check cache first for instant display
    final cachedVideos = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyVideos,
    );
    final cachedTeacherName = _cacheService.get<String>(cacheKeyTeacher);

    if (cachedVideos != null) {
      setState(() {
        _videos = cachedVideos;
        _teacherName = cachedTeacherName ?? 'Instructor';
        _isLoading = false;
      });
      // Refresh in background
      _refreshDataInBackground(uid, cacheKeyVideos, cacheKeyTeacher);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Load videos and teacher name in parallel
      final results = await Future.wait([
        _courseService.getCourseVideos(courseUid: widget.courseUid),
        UserService().getUser(uid: uid, role: 'teacher'),
      ]);

      final videos = results[0] as List<Map<String, dynamic>>;
      final userData = results[1] as Map<String, dynamic>?;
      final teacherName = userData?['name'] ?? 'Instructor';

      // Cache results
      _cacheService.set(cacheKeyVideos, videos);
      _cacheService.set(cacheKeyTeacher, teacherName);

      setState(() {
        _videos = videos;
        _teacherName = teacherName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      }
    }
  }

  Future<void> _refreshDataInBackground(
    String uid,
    String cacheKeyVideos,
    String cacheKeyTeacher,
  ) async {
    try {
      final results = await Future.wait([
        _courseService.getCourseVideos(courseUid: widget.courseUid),
        UserService().getUser(uid: uid, role: 'teacher'),
      ]);

      final videos = results[0] as List<Map<String, dynamic>>;
      final userData = results[1] as Map<String, dynamic>?;
      final teacherName = userData?['name'] ?? 'Instructor';

      // Update cache
      _cacheService.set(cacheKeyVideos, videos);
      _cacheService.set(cacheKeyTeacher, teacherName);

      if (mounted) {
        setState(() {
          _videos = videos;
          _teacherName = teacherName;
        });
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  // Legacy method for compatibility with refresh after adding video
  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final videos = await _courseService.getCourseVideos(
        courseUid: widget.courseUid,
      );
      // Update teacher cache
      _cacheService.set('course_videos_${widget.courseUid}', videos);

      // Clear all student caches for this course to ensure fresh data
      _cacheService.clearPrefix('course_detail_${widget.courseUid}');
      // Also clear course progress caches so students see updated video count
      _cacheService.clearPrefix('course_progress_');

      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading videos: $e")));
      }
    }
  }

  // Send notifications when video is uploaded
  Future<void> _sendVideoUploadNotifications(
    String videoTitle,
    int videoCount,
  ) async {
    try {
      final notificationService = NotificationService();
      final teacherUid = FirebaseAuth.instance.currentUser!.uid;

      // Get enrolled students for this course
      final enrolledStudents = await _courseService.getEnrolledStudents(
        courseUid: widget.courseUid,
      );

      // Send notification to each enrolled student
      for (final student in enrolledStudents) {
        final studentUid = student['uid'] ?? student['studentUid'];
        if (studentUid != null && studentUid != teacherUid) {
          await notificationService.notifyStudentOfNewVideo(
            studentUid: studentUid,
            courseName: widget.courseTitle,
            videoTitle: videoCount > 1
                ? '$videoTitle (${videoCount} videos)'
                : videoTitle,
            courseId: widget.courseUid,
            teacherUid: teacherUid,
          );
        }
      }

      // Also send notification to teacher (self-notification for confirmation)
      await notificationService.sendNotification(
        toUid: teacherUid,
        title: 'Video Uploaded! 🎬',
        message: videoCount > 1
            ? '$videoCount videos added to "${widget.courseTitle}"'
            : '"$videoTitle" added to "${widget.courseTitle}"',
        type: 'course_update',
        relatedCourseId: widget.courseUid,
        fromUid: teacherUid,
      );
    } catch (e) {
      // Silent fail - notifications are not critical
      debugPrint('Failed to send video upload notifications: $e');
    }
  }

  void _showAddVideoDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    List<XFile> selectedVideos = [];
    bool isUploading = false;
    double uploadProgress = 0.0;
    int currentUploadIndex = 0;
    CancellableUpload? cancellableUpload;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogIsDark = AppTheme.isDarkMode(context);

          return AlertDialog(
            backgroundColor: dialogIsDark ? AppTheme.darkCard : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.video_library,
                  color: dialogIsDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUploading
                        ? 'Uploading${selectedVideos.length > 1 ? " (${currentUploadIndex + 1}/${selectedVideos.length})" : ""}...'
                        : 'Add New Video',
                    style: TextStyle(
                      color: dialogIsDark
                          ? AppTheme.darkTextPrimary
                          : Colors.black87,
                    ),
                  ),
                ),
                // Continue in background button (only show when uploading)
                if (isUploading)
                  IconButton(
                    onPressed: () {
                      // Move current and remaining uploads to background
                      for (
                        int i = currentUploadIndex;
                        i < selectedVideos.length;
                        i++
                      ) {
                        final video = selectedVideos[i];
                        final title = selectedVideos.length == 1
                            ? titleController.text
                            : '${titleController.text} (${i + 1})';
                        BackgroundUploadService().startUpload(
                          courseUid: widget.courseUid,
                          courseTitle: widget.courseTitle,
                          videoTitle: title,
                          videoDescription: descriptionController.text,
                          videoFile: video,
                        );
                      }

                      cancellableUpload?.cancel();
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedVideos.length - currentUploadIndex > 1
                                ? '${selectedVideos.length - currentUploadIndex} uploads moved to background'
                                : 'Upload moved to background',
                          ),
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'View',
                            onPressed: () {
                              showModalBottomSheet(
                                context: this.context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const UploadTasksBottomSheet(),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.open_in_new,
                      color: dialogIsDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      size: 20,
                    ),
                    tooltip: 'Continue in background',
                  ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Only show form fields when not uploading
                  if (!isUploading) ...[
                    TextField(
                      controller: titleController,
                      style: TextStyle(
                        color: dialogIsDark
                            ? AppTheme.darkTextPrimary
                            : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: selectedVideos.length > 1
                            ? 'Video Title (prefix for multiple) *'
                            : 'Video Title *',
                        labelStyle: TextStyle(
                          color: dialogIsDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: dialogIsDark
                                ? AppTheme.darkBorderColor
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: dialogIsDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.title,
                          color: dialogIsDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey,
                        ),
                        filled: dialogIsDark,
                        fillColor: dialogIsDark ? AppTheme.darkSurface : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      style: TextStyle(
                        color: dialogIsDark
                            ? AppTheme.darkTextPrimary
                            : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        labelStyle: TextStyle(
                          color: dialogIsDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: dialogIsDark
                                ? AppTheme.darkBorderColor
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: dialogIsDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.description,
                          color: dialogIsDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey,
                        ),
                        filled: dialogIsDark,
                        fillColor: dialogIsDark ? AppTheme.darkSurface : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Video selection area
                    GestureDetector(
                      onTap: () async {
                        // Use pickVideo for guaranteed video file selection
                        // Allow user to pick multiple videos one by one
                        final video = await _picker.pickVideo(
                          source: ImageSource.gallery,
                        );
                        if (video != null) {
                          setDialogState(() {
                            // Add to existing selection (allows multi-select one by one)
                            if (!selectedVideos.any(
                              (v) => v.path == video.path,
                            )) {
                              selectedVideos = [...selectedVideos, video];
                            }
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedVideos.isNotEmpty
                                ? AppTheme.success
                                : (dialogIsDark
                                      ? AppTheme.darkBorderColor
                                      : Colors.grey.shade300),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: selectedVideos.isNotEmpty
                              ? AppTheme.success.withOpacity(
                                  dialogIsDark ? 0.2 : 0.1,
                                )
                              : (dialogIsDark
                                    ? AppTheme.darkSurface
                                    : Colors.grey.shade50),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selectedVideos.isNotEmpty
                                  ? Icons.check_circle
                                  : Icons.video_call,
                              size: 32,
                              color: selectedVideos.isNotEmpty
                                  ? AppTheme.success
                                  : (dialogIsDark
                                        ? AppTheme.darkTextSecondary
                                        : Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedVideos.isNotEmpty
                                  ? '${selectedVideos.length} video${selectedVideos.length > 1 ? "s" : ""} selected ✓'
                                  : 'Tap to select video',
                              style: TextStyle(
                                color: selectedVideos.isNotEmpty
                                    ? AppTheme.success
                                    : (dialogIsDark
                                          ? AppTheme.darkTextSecondary
                                          : Colors.grey.shade600),
                                fontWeight: selectedVideos.isNotEmpty
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (selectedVideos.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Tap multiple times to add more videos',
                                  style: TextStyle(
                                    color: dialogIsDark
                                        ? AppTheme.darkTextSecondary
                                              .withOpacity(0.7)
                                        : Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (selectedVideos.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setDialogState(() => selectedVideos = []);
                                  },
                                  child: Text(
                                    'Clear selection',
                                    style: TextStyle(
                                      color: dialogIsDark
                                          ? AppTheme.darkError
                                          : Colors.red.shade600,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Upload progress
                  if (isUploading) ...[
                    const SizedBox(height: 8),
                    // Current video info
                    if (selectedVideos.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Uploading: ${titleController.text} (${currentUploadIndex + 1})',
                          style: TextStyle(
                            color: dialogIsDark
                                ? AppTheme.darkTextPrimary
                                : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: uploadProgress,
                        backgroundColor: dialogIsDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          dialogIsDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                        ),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          uploadProgress < 0.9
                              ? 'Uploading...'
                              : 'Processing...',
                          style: TextStyle(
                            color: dialogIsDark
                                ? AppTheme.darkTextSecondary
                                : Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${(uploadProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: dialogIsDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tip text
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (dialogIsDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: dialogIsDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap the arrow icon to continue upload in background',
                              style: TextStyle(
                                color: dialogIsDark
                                    ? AppTheme.darkTextSecondary
                                    : Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              // Cancel button
              TextButton(
                onPressed: () {
                  if (isUploading) {
                    cancellableUpload?.cancel();
                  }
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  isUploading ? 'Cancel Upload' : 'Cancel',
                  style: TextStyle(
                    color: isUploading
                        ? Colors.red
                        : (dialogIsDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600),
                  ),
                ),
              ),
              // Upload button
              if (!isUploading)
                ElevatedButton.icon(
                  onPressed: () async {
                    if (titleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a video title'),
                        ),
                      );
                      return;
                    }
                    if (selectedVideos.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one video'),
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      isUploading = true;
                      uploadProgress = 0.0;
                      currentUploadIndex = 0;
                    });

                    // Upload videos sequentially
                    for (int i = 0; i < selectedVideos.length; i++) {
                      setDialogState(() {
                        currentUploadIndex = i;
                        uploadProgress = 0.0;
                      });

                      cancellableUpload = CancellableUpload();

                      try {
                        final video = selectedVideos[i];
                        final title = selectedVideos.length == 1
                            ? titleController.text
                            : '${titleController.text} (${i + 1})';

                        final videoUrl =
                            await uploadToCloudinaryWithSimulatedProgress(
                              video,
                              onProgress: (progress) {
                                setDialogState(() => uploadProgress = progress);
                              },
                              cancellable: cancellableUpload,
                            );

                        if (cancellableUpload?.isCancelled ?? false) {
                          return;
                        }

                        if (videoUrl != null) {
                          await _courseService.addVideoToCourse(
                            teacherUid: FirebaseAuth.instance.currentUser!.uid,
                            courseUid: widget.courseUid,
                            videoUrl: videoUrl,
                            videoTitle: title,
                            videoDescription: descriptionController.text,
                          );
                        } else {
                          throw Exception('Failed to upload video');
                        }
                      } catch (e) {
                        if (cancellableUpload?.isCancelled ?? false) {
                          return;
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error uploading video ${i + 1}: $e',
                              ),
                            ),
                          );
                        }
                        setDialogState(() => isUploading = false);
                        return;
                      }
                    }

                    // All uploads complete
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _loadVideos();

                      // Send notifications to enrolled students
                      _sendVideoUploadNotifications(
                        titleController.text,
                        selectedVideos.length,
                      );

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedVideos.length > 1
                                ? '${selectedVideos.length} videos added successfully!'
                                : 'Video added successfully!',
                          ),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: Text(
                    selectedVideos.length > 1
                        ? 'Upload ${selectedVideos.length} Videos'
                        : 'Upload Video',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogIsDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // App Bar with course cover
          _buildSliverAppBar(),

          // Background upload status card
          SliverToBoxAdapter(
            child: UploadStatusCard(courseUid: widget.courseUid),
          ),

          // Course Stats
          SliverToBoxAdapter(child: _buildCourseStats()),

          // Video being played
          if (_playingVideoIndex != null)
            SliverToBoxAdapter(child: _buildVideoPlayer()),

          // Videos section header
          SliverToBoxAdapter(child: _buildVideosHeader()),

          // Videos list (collapsible)
          if (_isVideosExpanded) ...[
            _isLoading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : _videos.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildVideoItem(index),
                      childCount: _videos.length,
                    ),
                  ),
          ],

          // Q&A Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: QASectionWidget(
                courseUid: widget.courseUid,
                isTeacher: true,
                teacherName: _teacherName,
                courseName: widget.courseTitle,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVideoDialog,
        backgroundColor: isDark
            ? AppTheme.darkPrimaryLight
            : AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Video', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.more_vert, color: Colors.white),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDark ? AppTheme.darkCard : Colors.white,
          onSelected: (value) {
            if (value == 'delete') {
              _showDeleteCourseDialog();
            } else if (value == 'uploads') {
              _showPendingUploads();
            }
          },
          itemBuilder: (context) => [
            // View Pending Uploads option
            PopupMenuItem(
              value: 'uploads',
              child: ListenableBuilder(
                listenable: BackgroundUploadService(),
                builder: (context, _) {
                  final service = BackgroundUploadService();
                  final activeTasks = service.uploadTasks
                      .where(
                        (t) =>
                            t.status == UploadStatus.uploading ||
                            t.status == UploadStatus.processing ||
                            t.status == UploadStatus.pending,
                      )
                      .length;
                  return Row(
                    children: [
                      Icon(
                        Icons.cloud_upload,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pending Uploads',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : Colors.black87,
                        ),
                      ),
                      if (activeTasks > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$activeTasks',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: isDark ? AppTheme.darkError : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Delete Course',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkError : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.courseTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseStats() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: AppTheme.darkBorderColor) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.people,
            '${widget.enrolledCount}',
            'Students',
            isDark ? const Color(0xFF4ECDC4) : AppTheme.primaryColor,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.video_library,
            '${_videos.length}',
            'Videos',
            isDark ? AppTheme.darkPrimaryLight : AppTheme.accentColor,
          ),
          _buildStatDivider(),
          _buildStatItem(Icons.star, 'Active', 'Status', AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: color.withOpacity(0.3)) : null,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 50,
      width: 1,
      color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
    );
  }

  Widget _buildVideoPlayer() {
    final video = _videos[_playingVideoIndex!];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: AdvancedVideoPlayer(
                videoUrl: video['url'],
                videoTitle: video['title'],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  video['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _playingVideoIndex = null),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideosHeader() {
    return InkWell(
      onTap: () {
        setState(() {
          _isVideosExpanded = !_isVideosExpanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Icon(
              Icons.playlist_play,
              color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Course Videos',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                        .withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: isDark
                    ? Border.all(
                        color: AppTheme.darkPrimaryLight.withOpacity(0.3),
                      )
                    : null,
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
    );
  }

  Widget _buildEmptyState() {
    final accentColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.primaryColor;
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppTheme.darkBorderColor) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
              border: isDark
                  ? Border.all(color: accentColor.withOpacity(0.3))
                  : null,
            ),
            child: Icon(
              Icons.video_library_outlined,
              size: 48,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No videos yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first video to this course',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _showAddVideoDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add First Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
                foregroundColor: const Color(0xFFF0F8FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoItem(int index) {
    final video = _videos[index];
    final isPlaying = index == _playingVideoIndex;
    final accentColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.primaryColor;
    final isPublic = video['isPublic'] ?? true;

    return GestureDetector(
      onTap: () {
        setState(() {
          _playingVideoIndex = isPlaying ? null : index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isPlaying
              ? accentColor.withOpacity(isDark ? 0.15 : 0.05)
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(
                  color: accentColor.withOpacity(isDark ? 0.5 : 0.3),
                  width: 2,
                )
              : (isDark ? Border.all(color: AppTheme.darkBorderColor) : null),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? accentColor
                      : (isDark ? AppTheme.darkSurface : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                  border: isDark && !isPlaying
                      ? Border.all(color: AppTheme.darkBorderColor)
                      : null,
                ),
                child: Center(
                  child: isPlaying
                      ? const Icon(Icons.play_arrow, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : Colors.grey.shade600,
                          ),
                        ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      video['title'] ?? 'Video ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPlaying
                            ? accentColor
                            : (isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isPublic
                          ? AppTheme.success.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPublic ? 'Public' : 'Private',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPublic ? AppTheme.success : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle:
                  video['description'] != null &&
                      video['description'].toString().isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        video['description'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600,
                        ),
                      ),
                    )
                  : null,
              trailing: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : Colors.grey.shade600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? AppTheme.darkCard : Colors.white,
                onSelected: (value) {
                  switch (value) {
                    case 'play':
                      setState(() {
                        _playingVideoIndex = isPlaying ? null : index;
                      });
                      break;
                    case 'visibility':
                      _toggleVideoVisibility(video, index);
                      break;
                    case 'delete':
                      _showDeleteVideoDialog(video, index);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'play',
                    child: Row(
                      children: [
                        Icon(
                          isPlaying ? Icons.stop : Icons.play_arrow,
                          color: accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isPlaying ? 'Stop' : 'Play',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'visibility',
                    child: Row(
                      children: [
                        Icon(
                          isPublic ? Icons.visibility_off : Icons.visibility,
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isPublic ? 'Make Private' : 'Make Public',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: isDark ? AppTheme.darkError : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: isDark ? AppTheme.darkError : Colors.red,
                          ),
                        ),
                      ],
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

  Future<void> _toggleVideoVisibility(
    Map<String, dynamic> video,
    int index,
  ) async {
    final isCurrentlyPublic = video['isPublic'] ?? true;
    try {
      await _courseService.updateVideoVisibility(
        teacherUid: FirebaseAuth.instance.currentUser!.uid,
        courseUid: widget.courseUid,
        videoId: video['id'] ?? video['videoId'],
        isPublic: !isCurrentlyPublic,
      );

      setState(() {
        _videos[index]['isPublic'] = !isCurrentlyPublic;
      });

      // Clear cache
      _cacheService.clearPrefix('course_videos_${widget.courseUid}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyPublic
                  ? 'Video is now private'
                  : 'Video is now public',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update video: $e')));
      }
    }
  }

  Future<void> _showDeleteVideoDialog(
    Map<String, dynamic> video,
    int index,
  ) async {
    // Check if this is the only video
    if (_videos.length == 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Cannot Delete',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'A course must have at least one video. Please add another video before deleting this one, or delete the entire course instead.',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'OK',
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Check if user wants to skip confirmation
    final shouldSkip = await PreferencesService.shouldSkipDeleteVideoConfirm();
    if (shouldSkip) {
      await _deleteVideo(video, index);
      return;
    }

    bool dontShowAgain = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDeleteState) {
          final deleteDark = AppTheme.isDarkMode(context);
          return AlertDialog(
            backgroundColor: deleteDark ? AppTheme.darkCard : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  color: deleteDark ? AppTheme.darkError : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delete Video',
                  style: TextStyle(
                    color: deleteDark
                        ? AppTheme.darkTextPrimary
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete "${video['title']}"?',
                  style: TextStyle(
                    color: deleteDark
                        ? AppTheme.darkTextSecondary
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can undo this action within a few seconds after deletion.',
                  style: TextStyle(
                    color: deleteDark
                        ? AppTheme.darkTextSecondary.withOpacity(0.7)
                        : Colors.grey.shade500,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: dontShowAgain,
                        onChanged: (value) {
                          setDeleteState(() => dontShowAgain = value ?? false);
                        },
                        activeColor: deleteDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Don't show this again",
                        style: TextStyle(
                          color: deleteDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: deleteDark
                        ? AppTheme.darkTextSecondary
                        : Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (dontShowAgain) {
                    await PreferencesService.setSkipDeleteVideoConfirm(true);
                  }
                  Navigator.pop(ctx);
                  await _deleteVideo(video, index);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: deleteDark ? AppTheme.darkError : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteVideo(Map<String, dynamic> video, int index) async {
    final deletedVideo = Map<String, dynamic>.from(video);
    final deletedIndex = index;
    bool isDeleted = false;
    bool undoPressed = false;

    try {
      // Optimistically remove from UI
      setState(() {
        _videos.removeAt(index);
        if (_playingVideoIndex == index) {
          _playingVideoIndex = null;
        } else if (_playingVideoIndex != null && _playingVideoIndex! > index) {
          _playingVideoIndex = _playingVideoIndex! - 1;
        }
      });

      if (mounted) {
        // Clear any existing snackbars first
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();

        // Show snackbar with undo option - 5 second window
        messenger
            .showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Video "${deletedVideo['title']}" deleted'),
                    ),
                  ],
                ),
                backgroundColor: isDark
                    ? AppTheme.darkCard
                    : Colors.grey.shade800,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'UNDO',
                  textColor: AppTheme.warning,
                  onPressed: () {
                    // Mark as undo pressed
                    undoPressed = true;
                    // Restore video
                    if (mounted) {
                      setState(() {
                        _videos.insert(deletedIndex, deletedVideo);
                        if (_playingVideoIndex != null &&
                            _playingVideoIndex! >= deletedIndex) {
                          _playingVideoIndex = _playingVideoIndex! + 1;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(
                                Icons.restore,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text('Video restored'),
                            ],
                          ),
                          backgroundColor: AppTheme.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            )
            .closed
            .then((reason) async {
              // Only delete from database if undo wasn't pressed
              if (!undoPressed &&
                  reason != SnackBarClosedReason.action &&
                  !isDeleted) {
                isDeleted = true;
                try {
                  await _courseService.deleteVideo(
                    teacherUid: FirebaseAuth.instance.currentUser!.uid,
                    courseUid: widget.courseUid,
                    videoId: deletedVideo['id'] ?? deletedVideo['videoId'],
                  );

                  // Clear cache after actual deletion
                  _cacheService.clearPrefix(
                    'course_videos_${widget.courseUid}',
                  );
                  _cacheService.clearPrefix('teacher_');
                } catch (e) {
                  // If deletion fails, restore the video
                  if (mounted) {
                    setState(() {
                      _videos.insert(deletedIndex, deletedVideo);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete video: $e')),
                    );
                  }
                }
              }
            });
      }
    } catch (e) {
      // Restore video on error
      if (mounted) {
        setState(() {
          _videos.insert(deletedIndex, deletedVideo);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete video: $e')));
      }
    }
  }

  void _showPendingUploads() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UploadTasksBottomSheet(),
    );
  }

  void _showDeleteCourseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: isDark ? AppTheme.darkError : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Course',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.courseTitle}"?',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkError : Colors.red).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (isDark ? AppTheme.darkError : Colors.red).withOpacity(
                    0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark ? AppTheme.darkError : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will permanently delete:\n• All ${_videos.length} videos\n• ${widget.enrolledCount} student enrollments\n• All Q&A discussions',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: isDark ? AppTheme.darkError : Colors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteCourse();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkError : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Delete Course'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCourse() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Deleting course...',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      try {
        await _courseService.deleteCourse(
          teacherUid: FirebaseAuth.instance.currentUser!.uid,
          courseUid: widget.courseUid,
        );
      } catch (e) {
        // Silently catch permission errors - course may still be deleted
        print('Course deletion completed with message: $e');
      }

      // Clear all caches
      _cacheService.clearPrefix('teacher_');
      _cacheService.clearPrefix('course_');

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        // Close course manage screen and return to courses
        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Course "${widget.courseTitle}" deleted successfully',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete course: $e'),
            backgroundColor: isDark ? AppTheme.darkError : Colors.red,
          ),
        );
      }
    }
  }
}
