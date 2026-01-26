import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/models/course_model.dart';
<<<<<<< HEAD
import 'package:eduverse/widgets/advanced_video_player.dart';
import 'package:eduverse/widgets/teacher_public_profile_widget.dart';
import 'package:eduverse/services/notification_service.dart';
import 'package:flutter/services.dart';
=======
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687

/// Admin Course Detail Screen - Video-level moderation
/// Features: View all videos, moderate individual videos, audit logging
class AdminCourseDetailScreen extends StatefulWidget {
  final Course course;

  const AdminCourseDetailScreen({super.key, required this.course});

  @override
<<<<<<< HEAD
  State<AdminCourseDetailScreen> createState() =>
      _AdminCourseDetailScreenState();
=======
  State<AdminCourseDetailScreen> createState() => _AdminCourseDetailScreenState();
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
}

class _AdminCourseDetailScreenState extends State<AdminCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
<<<<<<< HEAD
  final NotificationService _notificationService = NotificationService();

  late TabController _tabController;

=======
  
  late TabController _tabController;
  
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
  String? _teacherName;
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _enrolledStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCourseDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseDetails() async {
    setState(() => _isLoading = true);

    try {
      // Load teacher name
<<<<<<< HEAD
      final teacherSnapshot = await _db
          .child('teacher')
          .child(widget.course.teacherUid)
          .child('name')
          .get();
=======
      final teacherSnapshot = await _db.child('teacher')
          .child(widget.course.teacherUid).child('name').get();
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      if (teacherSnapshot.exists) {
        _teacherName = teacherSnapshot.value.toString();
      }

      // Load videos
      await _loadVideos();

      // Load reviews
      await _loadReviews();

      // Load enrolled students
      await _loadEnrolledStudents();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading course details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVideos() async {
<<<<<<< HEAD
    final videosSnapshot = await _db
        .child('courses')
        .child(widget.course.courseUid)
        .child('videos')
        .get();

    if (videosSnapshot.exists && videosSnapshot.value != null) {
      final data = videosSnapshot.value;
      final videos = <Map<String, dynamic>>[];

=======
    final videosSnapshot = await _db.child('courses')
        .child(widget.course.courseUid).child('videos').get();
    
    if (videosSnapshot.exists && videosSnapshot.value != null) {
      final data = videosSnapshot.value;
      final videos = <Map<String, dynamic>>[];
      
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      if (data is Map) {
        for (var entry in data.entries) {
          videos.add({
            'id': entry.key.toString(),
            ...Map<String, dynamic>.from(entry.value as Map),
          });
        }
      } else if (data is List) {
        for (int i = 0; i < data.length; i++) {
          if (data[i] != null) {
            videos.add({
              'id': i.toString(),
              ...Map<String, dynamic>.from(data[i] as Map),
            });
          }
        }
      }
<<<<<<< HEAD

      // Sort by order if available
      videos.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

=======
      
      // Sort by order if available
      videos.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
      
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      setState(() => _videos = videos);
    }
  }

  Future<void> _loadReviews() async {
<<<<<<< HEAD
    final reviewsSnapshot = await _db
        .child('courses')
        .child(widget.course.courseUid)
        .child('reviews')
        .get();

    final reviews = <Map<String, dynamic>>[];

    if (reviewsSnapshot.exists && reviewsSnapshot.value != null) {
      // Reviews found in course node
      final data = reviewsSnapshot.value as Map;
      for (var entry in data.entries) {
        try {
          reviews.add({
            'id': entry.key.toString(),
            ...Map<String, dynamic>.from(entry.value as Map),
          });
        } catch (e) {
          debugPrint('Error parsing review: $e');
        }
      }
    } else {
      // Fallback: try teacher's reviews node
      final teacherReviewsSnap = await _db
          .child('teacher')
          .child(widget.course.teacherUid)
          .child('reviews')
          .get();

      if (teacherReviewsSnap.exists && teacherReviewsSnap.value != null) {
        final teacherReviews = teacherReviewsSnap.value as Map;
        for (var entry in teacherReviews.entries) {
          try {
            final review = Map<String, dynamic>.from(entry.value as Map);
            // Only include reviews for this course
            if (review['courseUid'] == widget.course.courseUid) {
              reviews.add({'id': entry.key.toString(), ...review});
            }
          } catch (e) {
            debugPrint('Error parsing teacher review: $e');
          }
        }
      }
    }

    // Sort by date descending
    reviews.sort(
      (a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0),
    );

    setState(() => _reviews = reviews);
  }

  Future<void> _loadEnrolledStudents() async {
    final enrolledSnapshot = await _db
        .child('courses')
        .child(widget.course.courseUid)
        .child('enrolledStudents')
        .get();

    if (enrolledSnapshot.exists && enrolledSnapshot.value != null) {
      final data = enrolledSnapshot.value as Map;
      final students = <Map<String, dynamic>>[];

      for (var entry in data.entries) {
        final studentId = entry.key.toString();
        final enrollmentData = entry.value;

        // Load student name
        final studentSnapshot = await _db
            .child('student')
            .child(studentId)
            .child('name')
            .get();

        students.add({
          'id': studentId,
          'name': studentSnapshot.exists
              ? studentSnapshot.value.toString()
              : 'Unknown',
          'enrolledAt': enrollmentData is Map
              ? enrollmentData['enrolledAt']
              : null,
        });
      }

=======
    final reviewsSnapshot = await _db.child('courses')
        .child(widget.course.courseUid).child('reviews').get();
    
    if (reviewsSnapshot.exists && reviewsSnapshot.value != null) {
      final data = reviewsSnapshot.value as Map;
      final reviews = <Map<String, dynamic>>[];
      
      for (var entry in data.entries) {
        reviews.add({
          'id': entry.key.toString(),
          ...Map<String, dynamic>.from(entry.value as Map),
        });
      }
      
      // Sort by date descending
      reviews.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
      
      setState(() => _reviews = reviews);
    }
  }

  Future<void> _loadEnrolledStudents() async {
    final enrolledSnapshot = await _db.child('courses')
        .child(widget.course.courseUid).child('enrolledStudents').get();
    
    if (enrolledSnapshot.exists && enrolledSnapshot.value != null) {
      final data = enrolledSnapshot.value as Map;
      final students = <Map<String, dynamic>>[];
      
      for (var entry in data.entries) {
        final studentId = entry.key.toString();
        final enrollmentData = entry.value;
        
        // Load student name
        final studentSnapshot = await _db.child('student')
            .child(studentId).child('name').get();
        
        students.add({
          'id': studentId,
          'name': studentSnapshot.exists ? studentSnapshot.value.toString() : 'Unknown',
          'enrolledAt': enrollmentData is Map ? enrollmentData['enrolledAt'] : null,
        });
      }
      
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      setState(() => _enrolledStudents = students);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildSliverAppBar(isDark),
                  SliverToBoxAdapter(child: _buildCourseHeader(isDark)),
                  SliverPersistentHeader(
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        controller: _tabController,
<<<<<<< HEAD
                        labelColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.getTextSecondary(
                          context,
                        ),
                        indicatorColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
=======
                        labelColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.getTextSecondary(context),
                        indicatorColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                        tabs: const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Videos'),
                          Tab(text: 'Reviews'),
                          Tab(text: 'Students'),
                        ],
                      ),
                      isDark,
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(isDark),
                  _buildVideosTab(isDark),
                  _buildReviewsTab(isDark),
                  _buildStudentsTab(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.course.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: isDark ? AppTheme.darkCard : Colors.grey.shade300,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
<<<<<<< HEAD
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
=======
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: widget.course.isPublished ? 'unpublish' : 'publish',
              child: Row(
                children: [
                  Icon(
<<<<<<< HEAD
                    widget.course.isPublished
                        ? Icons.visibility_off
                        : Icons.visibility,
=======
                    widget.course.isPublished ? Icons.visibility_off : Icons.visibility,
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.course.isPublished ? 'Unpublish' : 'Publish'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'flag',
              child: Row(
                children: [
                  Icon(Icons.flag, size: 20),
                  SizedBox(width: 8),
                  Text('Flag for Review'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Course', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCourseHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.course.title,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
<<<<<<< HEAD

=======
          
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
          // Teacher and Category
          Row(
            children: [
              CircleAvatar(
                radius: 16,
<<<<<<< HEAD
                backgroundColor: isDark
                    ? AppTheme.darkAccent
                    : AppTheme.primaryColor,
=======
                backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                child: Text(
                  (_teacherName ?? 'T')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _teacherName ?? 'Unknown Teacher',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
<<<<<<< HEAD
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.1),
=======
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.course.category,
                  style: TextStyle(
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
<<<<<<< HEAD

          // Stats Row
          Row(
            children: [
              _buildStatItem(
                Icons.people,
                '${widget.course.enrolledCount}',
                'Students',
                isDark,
              ),
              _buildStatItem(
                Icons.video_library,
                '${_videos.length}',
                'Videos',
                isDark,
              ),
=======
          
          // Stats Row
          Row(
            children: [
              _buildStatItem(Icons.people, '${widget.course.enrolledCount}', 'Students', isDark),
              _buildStatItem(Icons.video_library, '${_videos.length}', 'Videos', isDark),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
              _buildStatItem(
                Icons.star,
                widget.course.averageRating?.toStringAsFixed(1) ?? '0.0',
                '${_reviews.length} Reviews',
                isDark,
                iconColor: Colors.amber,
              ),
              _buildStatItem(
                Icons.attach_money,
<<<<<<< HEAD
                widget.course.isFree
                    ? 'Free'
                    : '\$${widget.course.price.toStringAsFixed(0)}',
=======
                widget.course.isFree ? 'Free' : '\$${widget.course.price.toStringAsFixed(0)}',
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                widget.course.isFree ? '' : 'Price',
                isDark,
                iconColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
<<<<<<< HEAD

=======
          
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
          // Status Badge
          Row(
            children: [
              Container(
<<<<<<< HEAD
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
=======
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                decoration: BoxDecoration(
                  color: widget.course.isPublished
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.course.isPublished
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
<<<<<<< HEAD
                      widget.course.isPublished
                          ? Icons.check_circle
                          : Icons.pending,
                      size: 16,
                      color: widget.course.isPublished
                          ? Colors.green
                          : Colors.orange,
=======
                      widget.course.isPublished ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: widget.course.isPublished ? Colors.green : Colors.orange,
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.course.isPublished ? 'Published' : 'Draft',
                      style: TextStyle(
<<<<<<< HEAD
                        color: widget.course.isPublished
                            ? Colors.green
                            : Colors.orange,
=======
                        color: widget.course.isPublished ? Colors.green : Colors.orange,
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
<<<<<<< HEAD
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
=======
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.course.difficultyDisplay,
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    bool isDark, {
    Color? iconColor,
  }) {
=======
  Widget _buildStatItem(IconData icon, String value, String label, bool isDark, {Color? iconColor}) {
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
<<<<<<< HEAD
              Icon(
                icon,
                size: 18,
                color: iconColor ?? AppTheme.getTextSecondary(context),
              ),
=======
              Icon(icon, size: 18, color: iconColor ?? AppTheme.getTextSecondary(context)),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
<<<<<<< HEAD
    final createdDate = DateFormat(
      'MMM d, yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(widget.course.createdAt));
=======
    final createdDate = DateFormat('MMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(widget.course.createdAt),
    );
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
    final updatedDate = widget.course.updatedAt != null
        ? DateFormat('MMM d, yyyy').format(
            DateTime.fromMillisecondsSinceEpoch(widget.course.updatedAt!),
          )
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Description
        _buildSection(
          title: 'Description',
          isDark: isDark,
          child: Text(
            widget.course.description,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
<<<<<<< HEAD

=======
        
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
        // Course Details
        _buildSection(
          title: 'Course Details',
          isDark: isDark,
          child: Column(
            children: [
              _buildDetailRow('Course ID', widget.course.courseUid, isDark),
              _buildDetailRow('Teacher ID', widget.course.teacherUid, isDark),
              _buildDetailRow('Created', createdDate, isDark),
              if (updatedDate != null)
                _buildDetailRow('Last Updated', updatedDate, isDark),
<<<<<<< HEAD
              _buildDetailRow(
                'Difficulty',
                widget.course.difficultyDisplay,
                isDark,
              ),
=======
              _buildDetailRow('Difficulty', widget.course.difficultyDisplay, isDark),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
              _buildDetailRow('Category', widget.course.category, isDark),
              _buildDetailRow('Price', widget.course.priceDisplay, isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
<<<<<<< HEAD

=======
        
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
        // Quick Actions
        _buildSection(
          title: 'Quick Actions',
          isDark: isDark,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionChip(
                'View Teacher Profile',
                Icons.person,
                () => _viewTeacherProfile(),
                isDark,
              ),
              _buildActionChip(
                'Contact Teacher',
                Icons.email,
<<<<<<< HEAD
                () => _contactTeacher(),
=======
                () {},
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                isDark,
              ),
              _buildActionChip(
                'View Reports',
                Icons.flag,
<<<<<<< HEAD
                () => _viewCourseReports(),
=======
                () {},
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                isDark,
              ),
              _buildActionChip(
                'View Analytics',
                Icons.analytics,
<<<<<<< HEAD
                () => _viewCourseAnalytics(),
=======
                () {},
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab(bool isDark) {
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: AppTheme.getTextSecondary(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No videos in this course',
<<<<<<< HEAD
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
=======
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
              ),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return _buildVideoCard(video, index + 1, isDark);
      },
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, int number, bool isDark) {
    final isHidden = video['isHidden'] == true;
<<<<<<< HEAD
    // Handle duration as int or string
    int durationSeconds = 0;
    final rawDuration = video['duration'];
    if (rawDuration is int) {
      durationSeconds = rawDuration;
    } else if (rawDuration is String) {
      durationSeconds = int.tryParse(rawDuration) ?? 0;
    } else if (rawDuration is double) {
      durationSeconds = rawDuration.toInt();
    }
    final durationStr = _formatDuration(durationSeconds);
=======
    final duration = video['duration'] ?? 0;
    final durationStr = Duration(seconds: duration).toString().split('.')[0];
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHidden
              ? Colors.red.withOpacity(0.3)
              : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Video Number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
<<<<<<< HEAD
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.1),
=======
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
<<<<<<< HEAD

=======
            
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
            // Video Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          video['title'] ?? 'Untitled Video',
                          style: TextStyle(
                            color: isHidden
                                ? AppTheme.getTextSecondary(context)
                                : AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
<<<<<<< HEAD
                            decoration: isHidden
                                ? TextDecoration.lineThrough
                                : null,
=======
                            decoration: isHidden ? TextDecoration.lineThrough : null,
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                          ),
                        ),
                      ),
                      if (isHidden)
                        Container(
<<<<<<< HEAD
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
=======
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HIDDEN',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        durationStr,
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                      if (video['isFree'] == true) ...[
                        const SizedBox(width: 12),
                        Container(
<<<<<<< HEAD
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
=======
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FREE PREVIEW',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
<<<<<<< HEAD

            // Actions
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: AppTheme.getTextSecondary(context),
              ),
              onSelected: (action) => _handleVideoAction(video, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'preview',
                  child: Text('Preview Video'),
                ),
=======
            
            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.getTextSecondary(context)),
              onSelected: (action) => _handleVideoAction(video, action),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'preview', child: Text('Preview Video')),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                PopupMenuItem(
                  value: isHidden ? 'show' : 'hide',
                  child: Text(isHidden ? 'Show Video' : 'Hide Video'),
                ),
<<<<<<< HEAD
                const PopupMenuItem(value: 'flag', child: Text('Flag Video')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete Video',
                    style: TextStyle(color: Colors.red),
                  ),
=======
                const PopupMenuItem(
                  value: 'flag',
                  child: Text('Flag Video'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Video', style: TextStyle(color: Colors.red)),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab(bool isDark) {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: AppTheme.getTextSecondary(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
<<<<<<< HEAD
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
=======
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
              ),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewCard(review, isDark);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final createdAt = review['createdAt'] as int?;
    final isHidden = review['isHidden'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHidden
              ? Colors.red.withOpacity(0.3)
              : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
<<<<<<< HEAD
                  backgroundColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
=======
                  backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                  child: Text(
                    (review['studentName'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['studentName'] ?? 'Unknown',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
<<<<<<< HEAD
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ),
=======
                          ...List.generate(5, (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          )),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                          const SizedBox(width: 8),
                          Text(
                            createdAt != null
                                ? DateFormat('MMM d, y').format(
<<<<<<< HEAD
                                    DateTime.fromMillisecondsSinceEpoch(
                                      createdAt,
                                    ),
                                  )
=======
                                    DateTime.fromMillisecondsSinceEpoch(createdAt))
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                                : '',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isHidden)
                  Container(
<<<<<<< HEAD
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
=======
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HIDDEN',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
<<<<<<< HEAD
                  icon: Icon(
                    Icons.more_vert,
                    color: AppTheme.getTextSecondary(context),
                    size: 20,
                  ),
=======
                  icon: Icon(Icons.more_vert, color: AppTheme.getTextSecondary(context), size: 20),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                  onSelected: (action) => _handleReviewAction(review, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: isHidden ? 'show' : 'hide',
                      child: Text(isHidden ? 'Show Review' : 'Hide Review'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
<<<<<<< HEAD
                      child: Text(
                        'Delete Review',
                        style: TextStyle(color: Colors.red),
                      ),
=======
                      child: Text('Delete Review', style: TextStyle(color: Colors.red)),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review['reviewText'] ?? '',
              style: TextStyle(
                color: isHidden
                    ? AppTheme.getTextSecondary(context)
                    : AppTheme.getTextPrimary(context),
                height: 1.4,
                decoration: isHidden ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab(bool isDark) {
    if (_enrolledStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.getTextSecondary(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No students enrolled',
<<<<<<< HEAD
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
=======
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
              ),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _enrolledStudents.length,
      itemBuilder: (context, index) {
        final student = _enrolledStudents[index];
        return _buildStudentCard(student, isDark);
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isDark) {
    final enrolledAt = student['enrolledAt'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppTheme.darkCard : Colors.white,
<<<<<<< HEAD
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
=======
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          child: Text(
            (student['name'] ?? 'U')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          student['name'] ?? 'Unknown',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          enrolledAt != null
              ? 'Enrolled ${DateFormat('MMM d, y').format(DateTime.fromMillisecondsSinceEpoch(enrolledAt))}'
              : 'Enrollment date unknown',
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 12,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300),
          onPressed: () => _removeStudent(student),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildActionChip(
    String label,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
=======
  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap, bool isDark) {
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: AppTheme.getTextPrimary(context),
        fontSize: 12,
      ),
    );
  }

  void _handleAction(String action) async {
    switch (action) {
      case 'publish':
      case 'unpublish':
        await _togglePublish();
        break;
      case 'flag':
        await _flagCourse();
        break;
      case 'delete':
        await _deleteCourse();
        break;
    }
  }

  Future<void> _togglePublish() async {
    final newStatus = !widget.course.isPublished;
<<<<<<< HEAD

    await _db.child('courses').child(widget.course.courseUid).update({
      'isPublished': newStatus,
    });
    await _db
        .child('teacher')
        .child(widget.course.teacherUid)
        .child('courses')
        .child(widget.course.courseUid)
        .update({'isPublished': newStatus});

    await _logAction(newStatus ? 'publish_course' : 'unpublish_course');

    // Send notification to teacher when unpublishing
    if (!newStatus) {
      await _notificationService.sendNotification(
        toUid: widget.course.teacherUid,
        title: 'Course Unpublished',
        message:
            'Your course "${widget.course.title}" has been unpublished by an administrator. Please review your course content or contact support for more information.',
        type: 'admin_action',
        relatedCourseId: widget.course.courseUid,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course ${newStatus ? 'published' : 'unpublished'}'),
        ),
=======
    
    await _db.child('courses').child(widget.course.courseUid).update({
      'isPublished': newStatus,
    });
    await _db.child('teacher').child(widget.course.teacherUid)
        .child('courses').child(widget.course.courseUid).update({
      'isPublished': newStatus,
    });
    
    await _logAction(newStatus ? 'publish_course' : 'unpublish_course');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course ${newStatus ? 'published' : 'unpublished'}')),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      );
      Navigator.pop(context);
    }
  }

  Future<void> _flagCourse() async {
    // Implementation similar to AdminAllCoursesScreen
  }

  Future<void> _deleteCourse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
<<<<<<< HEAD

    if (confirm == true) {
      // Store course info for notification before deletion
      final courseTitle = widget.course.title;
      final teacherUid = widget.course.teacherUid;

      // Send notification to teacher BEFORE deleting the course
      await _notificationService.sendNotification(
        toUid: teacherUid,
        title: 'Course Deleted',
        message:
            'Your course "$courseTitle" has been removed by an administrator. If you believe this was a mistake, please contact support for assistance.',
        type: 'admin_action',
      );

      await _db.child('courses').child(widget.course.courseUid).remove();
      await _db
          .child('teacher')
          .child(widget.course.teacherUid)
          .child('courses')
          .child(widget.course.courseUid)
          .remove();

      await _logAction('delete_course');

=======
    
    if (confirm == true) {
      await _db.child('courses').child(widget.course.courseUid).remove();
      await _db.child('teacher').child(widget.course.teacherUid)
          .child('courses').child(widget.course.courseUid).remove();
      
      await _logAction('delete_course');
      
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _handleVideoAction(Map<String, dynamic> video, String action) async {
    final videoId = video['id'];
<<<<<<< HEAD

    switch (action) {
      case 'preview':
        final videoUrl = video['url'] ?? video['videoUrl'];
        if (videoUrl != null && videoUrl.toString().isNotEmpty) {
          _showVideoPreviewDialog(video);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video URL not available')),
          );
        }
=======
    
    switch (action) {
      case 'preview':
        // Open video player
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
        break;
      case 'hide':
      case 'show':
        final isHidden = action == 'hide';
<<<<<<< HEAD
        await _db
            .child('courses')
            .child(widget.course.courseUid)
            .child('videos')
            .child(videoId)
            .update({'isHidden': isHidden});
        await _logAction(isHidden ? 'hide_video' : 'show_video', videoId);

        // Notify teacher when video is hidden
        if (isHidden) {
          final videoTitle = video['title'] ?? 'A video';
          await _notificationService.sendNotification(
            toUid: widget.course.teacherUid,
            title: 'Video Hidden',
            message:
                '"$videoTitle" in your course "${widget.course.title}" has been hidden by an administrator. Please review the content or contact support.',
            type: 'admin_action',
            relatedCourseId: widget.course.courseUid,
            relatedVideoId: videoId,
          );
        }

        _loadVideos();
        break;
      case 'flag':
        _showFlagVideoDialog(video);
=======
        await _db.child('courses').child(widget.course.courseUid)
            .child('videos').child(videoId).update({'isHidden': isHidden});
        await _logAction(isHidden ? 'hide_video' : 'show_video', videoId);
        _loadVideos();
        break;
      case 'flag':
        // Flag video
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Video'),
            content: const Text('Are you sure? This cannot be undone.'),
            actions: [
<<<<<<< HEAD
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
=======
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
<<<<<<< HEAD
          // Store video info for notification before deletion
          final videoTitle = video['title'] ?? 'A video';

          // Send notification to teacher
          await _notificationService.sendNotification(
            toUid: widget.course.teacherUid,
            title: 'Video Deleted',
            message:
                '"$videoTitle" from your course "${widget.course.title}" has been removed by an administrator. Contact support if you have questions.',
            type: 'admin_action',
            relatedCourseId: widget.course.courseUid,
          );

          await _db
              .child('courses')
              .child(widget.course.courseUid)
              .child('videos')
              .child(videoId)
              .remove();
=======
          await _db.child('courses').child(widget.course.courseUid)
              .child('videos').child(videoId).remove();
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
          await _logAction('delete_video', videoId);
          _loadVideos();
        }
        break;
    }
  }

  void _handleReviewAction(Map<String, dynamic> review, String action) async {
    final reviewId = review['id'];
<<<<<<< HEAD

=======
    
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
    switch (action) {
      case 'hide':
      case 'show':
        final isHidden = action == 'hide';
<<<<<<< HEAD
        await _db
            .child('courses')
            .child(widget.course.courseUid)
            .child('reviews')
            .child(reviewId)
            .update({'isHidden': isHidden});
=======
        await _db.child('courses').child(widget.course.courseUid)
            .child('reviews').child(reviewId).update({'isHidden': isHidden});
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
        await _logAction(isHidden ? 'hide_review' : 'show_review', reviewId);
        _loadReviews();
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Review'),
            content: const Text('Are you sure? This cannot be undone.'),
            actions: [
<<<<<<< HEAD
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
=======
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
<<<<<<< HEAD
          await _db
              .child('courses')
              .child(widget.course.courseUid)
              .child('reviews')
              .child(reviewId)
              .remove();
=======
          await _db.child('courses').child(widget.course.courseUid)
              .child('reviews').child(reviewId).remove();
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
          await _logAction('delete_review', reviewId);
          _loadReviews();
        }
        break;
    }
  }

  Future<void> _removeStudent(Map<String, dynamic> student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Remove ${student['name']} from this course?'),
        actions: [
<<<<<<< HEAD
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
=======
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
<<<<<<< HEAD

    if (confirm == true) {
      await _db
          .child('courses')
          .child(widget.course.courseUid)
          .child('enrolledStudents')
          .child(student['id'])
          .remove();
      await _db
          .child('student')
          .child(student['id'])
          .child('enrolledCourses')
          .child(widget.course.courseUid)
          .remove();
=======
    
    if (confirm == true) {
      await _db.child('courses').child(widget.course.courseUid)
          .child('enrolledStudents').child(student['id']).remove();
      await _db.child('student').child(student['id'])
          .child('enrolledCourses').child(widget.course.courseUid).remove();
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
      await _logAction('remove_student', student['id']);
      _loadEnrolledStudents();
    }
  }

<<<<<<< HEAD
  void _showVideoPreviewDialog(Map<String, dynamic> video) {
    final videoUrl = video['url'] ?? video['videoUrl'] ?? '';
    final videoTitle = video['title'] ?? 'Video Preview';
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        videoTitle,
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Video Player
              Flexible(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AdvancedVideoPlayer(videoUrl: videoUrl.toString()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showFlagVideoDialog(Map<String, dynamic> video) {
    final videoId = video['id'];
    final videoTitle = video['title'] ?? 'Video';
    final isDark = AppTheme.isDarkMode(context);
    String? selectedReason;
    final reasonController = TextEditingController();

    final reasons = [
      'Inappropriate content',
      'Copyright violation',
      'Misleading information',
      'Low quality content',
      'Spam or promotional',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          title: Text(
            'Flag Video',
            style: TextStyle(color: AppTheme.getTextPrimary(context)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flagging: $videoTitle',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                  hint: Text(
                    'Select a reason',
                    style: TextStyle(color: AppTheme.getTextSecondary(context)),
                  ),
                  items: reasons
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedReason = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'Additional Notes (optional)',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: 'Enter additional details...',
                    hintStyle: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () async {
                      await _db.child('flagged_content').push().set({
                        'type': 'video',
                        'videoId': videoId,
                        'courseId': widget.course.courseUid,
                        'teacherId': widget.course.teacherUid,
                        'reason': selectedReason,
                        'notes': reasonController.text,
                        'flaggedAt': ServerValue.timestamp,
                        'status': 'pending',
                      });
                      await _logAction('flag_video', videoId);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Video flagged successfully'),
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Flag Video'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewTeacherProfile() {
    TeacherPublicProfileWidget.showProfile(
      context: context,
      teacherUid: widget.course.teacherUid,
      teacherName: _teacherName,
    );
  }

  Future<void> _contactTeacher() async {
    // Load teacher email
    final teacherSnapshot = await _db
        .child('teacher')
        .child(widget.course.teacherUid)
        .get();

    if (!teacherSnapshot.exists || teacherSnapshot.value == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher information not available')),
        );
      }
      return;
    }

    final teacherData = Map<String, dynamic>.from(teacherSnapshot.value as Map);
    final teacherEmail = teacherData['email']?.toString();
    final teacherName = teacherData['name']?.toString() ?? 'Teacher';

    if (teacherEmail == null || teacherEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher email not available')),
        );
      }
      return;
    }

    // Show email options dialog
    final isDark = AppTheme.isDarkMode(context);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        title: Text(
          'Contact $teacherName',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email: $teacherEmail',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
            const SizedBox(height: 16),
            Text(
              'How would you like to contact the teacher?',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'copy'),
            child: const Text('Copy Email'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkPrimary
                  : AppTheme.primaryColor,
            ),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: teacherEmail));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Email copied: $teacherEmail')));
      }
    } else if (action == 'email') {
      // Copy email with subject/body info for user to paste
      final emailText =
          'To: $teacherEmail\nSubject: Regarding Course: ${widget.course.title}\n\nHello $teacherName,\n\nThis is regarding your course "${widget.course.title}" on EduVerse.\n\n';
      await Clipboard.setData(ClipboardData(text: emailText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email details copied to clipboard')),
        );
      }
    }
  }

  void _viewCourseReports() {
    final isDark = AppTheme.isDarkMode(context);

    // Show reports for this course
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Course Reports',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
              // Reports List
              Expanded(
                child: FutureBuilder<DataSnapshot>(
                  future: _db
                      .child('flagged_content')
                      .orderByChild('courseId')
                      .equalTo(widget.course.courseUid)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.value == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 64,
                              color: Colors.green.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reports for this course',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final reportsMap = snapshot.data!.value as Map;
                    final reports = reportsMap.entries
                        .map(
                          (e) => {
                            'id': e.key,
                            ...Map<String, dynamic>.from(e.value as Map),
                          },
                        )
                        .toList();

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        return Card(
                          color: isDark
                              ? AppTheme.darkBackground
                              : Colors.grey.shade50,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.report,
                              color: report['status'] == 'pending'
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            title: Text(
                              report['reason'] ?? 'No reason',
                              style: TextStyle(
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            subtitle: Text(
                              'Type: ${report['type'] ?? 'unknown'}',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: report['status'] == 'pending'
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (report['status'] ?? 'pending')
                                    .toString()
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: report['status'] == 'pending'
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewCourseAnalytics() {
    final isDark = AppTheme.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.analytics,
                      color: isDark
                          ? AppTheme.darkPrimary
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Course Analytics',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
              // Analytics Grid
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Key Metrics
                      Row(
                        children: [
                          Expanded(
                            child: _buildAnalyticsTile(
                              'Enrolled Students',
                              _enrolledStudents.length.toString(),
                              Icons.people,
                              Colors.blue,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAnalyticsTile(
                              'Total Videos',
                              _videos.length.toString(),
                              Icons.video_library,
                              Colors.purple,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAnalyticsTile(
                              'Reviews',
                              _reviews.length.toString(),
                              Icons.star,
                              Colors.amber,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAnalyticsTile(
                              'Avg Rating',
                              _calculateAverageRating(),
                              Icons.grade,
                              Colors.orange,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Revenue Info
                      Text(
                        'Revenue',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              color: Colors.green,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estimated Revenue',
                                  style: TextStyle(
                                    color: AppTheme.getTextSecondary(context),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  _calculateEstimatedRevenue(),
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildAnalyticsTile(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateAverageRating() {
    if (_reviews.isEmpty) return 'N/A';

    double total = 0;
    int count = 0;
    for (final review in _reviews) {
      final rating = review['rating'];
      if (rating is num) {
        total += rating.toDouble();
        count++;
      }
    }

    if (count == 0) return 'N/A';
    return (total / count).toStringAsFixed(1);
  }

  String _calculateEstimatedRevenue() {
    final price = widget.course.price;
    final enrolledCount = _enrolledStudents.length;
    final revenue = price * enrolledCount;

    return '\$${revenue.toStringAsFixed(2)}';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
=======
  void _viewTeacherProfile() {
    // Navigate to teacher profile
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
  }

  Future<void> _logAction(String action, [String? targetId]) async {
    await _db.child('admin_logs').push().set({
      'action': action,
      'courseId': widget.course.courseUid,
      'targetId': targetId,
      'timestamp': ServerValue.timestamp,
    });
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  _SliverTabBarDelegate(this.tabBar, this.isDark);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
<<<<<<< HEAD
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
=======
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
>>>>>>> 3425158b508e9f53808be2e5b956e6357df71687
    return Container(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
