import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/user_service.dart';
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
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;
  int? _playingVideoIndex;
  String? _teacherName;

  // Theme helper
  bool get isDark => mounted ? AppTheme.isDarkMode(context) : false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _loadTeacherName();
  }

  Future<void> _loadTeacherName() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userData = await UserService().getUser(uid: uid, role: 'teacher');
    if (mounted && userData != null) {
      setState(() {
        _teacherName = userData['name'] ?? 'Instructor';
      });
    }
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final videos = await _courseService.getCourseVideos(
        courseUid: widget.courseUid,
      );
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

          // Videos list
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
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.courseTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    return Padding(
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

    return Container(
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
            : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: ListTile(
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
        title: Text(
          video['title'] ?? 'Video ${index + 1}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPlaying
                ? accentColor
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          ),
        ),
        subtitle:
            video['description'] != null &&
                video['description'].toString().isNotEmpty
            ? Text(
                video['description'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : Colors.grey.shade600,
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(
            isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
            color: accentColor,
            size: 36,
          ),
          onPressed: () {
            setState(() {
              _playingVideoIndex = isPlaying ? null : index;
            });
          },
        ),
      ),
    );
  }
}
