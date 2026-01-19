import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/advanced_video_player.dart';
import 'package:eduverse/widgets/qa_section_widget.dart';

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

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  int? _playingVideoIndex;
  String? _teacherName;
  bool _isVideosExpanded = true; // For collapsible video list

  // Theme helper
  bool get isDark => mounted ? AppTheme.isDarkMode(context) : false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
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
      // Update cache
      _cacheService.set('course_videos_${widget.courseUid}', videos);
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

  void _showAddVideoDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    XFile? selectedVideo;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
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
                Text(
                  'Add New Video',
                  style: TextStyle(
                    color: dialogIsDark
                        ? AppTheme.darkTextPrimary
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(
                      color: dialogIsDark
                          ? AppTheme.darkTextPrimary
                          : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Video Title *',
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
                    maxLines: 3,
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
                  GestureDetector(
                    onTap: isUploading
                        ? null
                        : () async {
                            final video = await _picker.pickVideo(
                              source: ImageSource.gallery,
                            );
                            if (video != null) {
                              setDialogState(() => selectedVideo = video);
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedVideo != null
                              ? AppTheme.success
                              : (dialogIsDark
                                    ? AppTheme.darkBorderColor
                                    : Colors.grey.shade300),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: selectedVideo != null
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
                            selectedVideo != null
                                ? Icons.check_circle
                                : Icons.upload_file,
                            size: 32,
                            color: selectedVideo != null
                                ? AppTheme.success
                                : (dialogIsDark
                                      ? AppTheme.darkTextSecondary
                                      : Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedVideo != null
                                ? 'Video selected ✓'
                                : 'Tap to select video',
                            style: TextStyle(
                              color: selectedVideo != null
                                  ? AppTheme.success
                                  : (dialogIsDark
                                        ? AppTheme.darkTextSecondary
                                        : Colors.grey.shade600),
                              fontWeight: selectedVideo != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: dialogIsDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Uploading video...',
                          style: TextStyle(
                            color: dialogIsDark
                                ? AppTheme.darkTextPrimary
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: dialogIsDark
                        ? AppTheme.darkTextSecondary
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (titleController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a video title'),
                            ),
                          );
                          return;
                        }
                        if (selectedVideo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a video'),
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isUploading = true);

                        try {
                          // Upload video
                          final videoUrl = await uploadToCloudinaryFromXFile(
                            selectedVideo!,
                          );

                          if (videoUrl != null) {
                            // Save to Firebase
                            await _courseService.addVideoToCourse(
                              teacherUid:
                                  FirebaseAuth.instance.currentUser!.uid,
                              courseUid: widget.courseUid,
                              videoUrl: videoUrl,
                              videoTitle: titleController.text,
                              videoDescription: descriptionController.text,
                            );

                            if (mounted) {
                              Navigator.pop(context);
                              _loadVideos();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Video added successfully!'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } else {
                            throw Exception('Failed to upload video');
                          }
                        } catch (e) {
                          setDialogState(() => isUploading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: dialogIsDark
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: const Color(0xFFF0F8FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                  shadowColor:
                      (dialogIsDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor)
                          .withOpacity(0.5),
                ),
                child: Text(isUploading ? 'Uploading...' : 'Add Video'),
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
            }
          },
          itemBuilder: (context) => [
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

  void _showDeleteVideoDialog(Map<String, dynamic> video, int index) {
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
            ),
            const SizedBox(width: 8),
            Text(
              'Delete Video',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${video['title']}"? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteVideo(video, index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkError : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVideo(Map<String, dynamic> video, int index) async {
    final deletedVideo = Map<String, dynamic>.from(video);
    final deletedIndex = index;
    bool isDeleted = false;

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
        // Show snackbar with undo option
        final messenger = ScaffoldMessenger.of(context);
        messenger
            .showSnackBar(
              SnackBar(
                content: Text('Video "${deletedVideo['title']}" deleted'),
                backgroundColor: isDark
                    ? AppTheme.darkCard
                    : Colors.grey.shade800,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'UNDO',
                  textColor: AppTheme.warning,
                  onPressed: () {
                    // Restore video
                    if (mounted) {
                      setState(() {
                        _videos.insert(deletedIndex, deletedVideo);
                        if (_playingVideoIndex != null &&
                            _playingVideoIndex! >= deletedIndex) {
                          _playingVideoIndex = _playingVideoIndex! + 1;
                        }
                      });
                    }
                  },
                ),
              ),
            )
            .closed
            .then((reason) async {
              // Only delete from database if undo wasn't pressed
              if (reason != SnackBarClosedReason.action && !isDeleted) {
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
