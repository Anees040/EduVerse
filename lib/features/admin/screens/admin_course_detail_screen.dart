import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/models/course_model.dart';
import 'package:eduverse/widgets/advanced_video_player.dart';

/// Admin Course Detail Screen - Video-level moderation
/// Features: View all videos, moderate individual videos, audit logging
class AdminCourseDetailScreen extends StatefulWidget {
  final Course course;

  const AdminCourseDetailScreen({super.key, required this.course});

  @override
  State<AdminCourseDetailScreen> createState() => _AdminCourseDetailScreenState();
}

class _AdminCourseDetailScreenState extends State<AdminCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  late TabController _tabController;
  
  String? _teacherName;
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _enrolledStudents = [];
  bool _isLoading = true;
  double _calculatedRating = 0.0;  // Calculated from actual reviews

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
      final teacherSnapshot = await _db.child('teacher')
          .child(widget.course.teacherUid).child('name').get();
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
    final videosSnapshot = await _db.child('courses')
        .child(widget.course.courseUid).child('videos').get();
    
    if (videosSnapshot.exists && videosSnapshot.value != null) {
      final data = videosSnapshot.value;
      final videos = <Map<String, dynamic>>[];
      
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
      
      // Sort by order if available
      videos.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
      
      setState(() => _videos = videos);
    }
  }

  Future<void> _loadReviews() async {
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
      
      // Calculate average rating from actual reviews
      double totalRating = 0.0;
      int ratingCount = 0;
      for (var review in reviews) {
        final rating = review['rating'];
        if (rating != null) {
          totalRating += (rating is num) ? rating.toDouble() : 0.0;
          ratingCount++;
        }
      }
      
      setState(() {
        _reviews = reviews;
        _calculatedRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;
      });
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
      
      setState(() => _enrolledStudents = students);
    }
  }

  /// Convert a full Firebase UID to a short, friendly ID format
  /// Example: "-NxAbc123DefGhi" -> "ABC-123"
  String _getFriendlyId(String fullId) {
    if (fullId.isEmpty) return '-';
    // Remove leading dash if present (Firebase push IDs start with -)
    final cleanId = fullId.startsWith('-') ? fullId.substring(1) : fullId;
    // Take first 6 chars and format as XXX-XXX
    final shortId = cleanId.length >= 6 
        ? '${cleanId.substring(0, 3).toUpperCase()}-${cleanId.substring(3, 6).toUpperCase()}'
        : cleanId.toUpperCase();
    return shortId;
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
                        labelColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                        unselectedLabelColor: AppTheme.getTextSecondary(context),
                        indicatorColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
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
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
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
            const PopupMenuItem(
              value: 'view_teacher',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 20),
                  SizedBox(width: 8),
                  Text('View Teacher Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'contact_teacher',
              child: Row(
                children: [
                  Icon(Icons.mail_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Contact Teacher'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: widget.course.isPublished ? 'unpublish' : 'publish',
              child: Row(
                children: [
                  Icon(
                    widget.course.isPublished ? Icons.visibility_off : Icons.visibility,
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
          
          // Teacher and Category
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1),
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
          
          // Stats Row
          Row(
            children: [
              _buildStatItem(Icons.people, '${widget.course.enrolledCount}', 'Students', isDark),
              _buildStatItem(Icons.video_library, '${_videos.length}', 'Videos', isDark),
              _buildStatItem(
                Icons.star,
                _calculatedRating.toStringAsFixed(1),
                '${_reviews.length} Reviews',
                isDark,
                iconColor: Colors.amber,
              ),
              _buildStatItem(
                Icons.attach_money,
                widget.course.isFree ? 'Free' : '\$${widget.course.price.toStringAsFixed(0)}',
                widget.course.isFree ? '' : 'Price',
                isDark,
                iconColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      widget.course.isPublished ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: widget.course.isPublished ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.course.isPublished ? 'Published' : 'Draft',
                      style: TextStyle(
                        color: widget.course.isPublished ? Colors.green : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildStatItem(IconData icon, String value, String label, bool isDark, {Color? iconColor}) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor ?? AppTheme.getTextSecondary(context)),
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
    final createdDate = DateFormat('MMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(widget.course.createdAt),
    );
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
        
        // Course Details
        _buildSection(
          title: 'Course Details',
          isDark: isDark,
          child: Column(
            children: [
              _buildDetailRow('Course ID', _getFriendlyId(widget.course.courseUid), isDark),
              _buildDetailRow('Teacher ID', _getFriendlyId(widget.course.teacherUid), isDark),
              _buildDetailRow('Created', createdDate, isDark),
              if (updatedDate != null)
                _buildDetailRow('Last Updated', updatedDate, isDark),
              _buildDetailRow('Difficulty', widget.course.difficultyDisplay, isDark),
              _buildDetailRow('Category', widget.course.category, isDark),
              _buildDetailRow('Price', widget.course.priceDisplay, isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
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
                () => _contactTeacher(),
                isDark,
              ),
              _buildActionChip(
                'View Reports',
                Icons.flag,
                () => _viewCourseReports(),
                isDark,
              ),
              _buildActionChip(
                'View Analytics',
                Icons.analytics,
                () => _viewCourseAnalytics(),
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
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
              ),
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
    // Handle duration as either int or double
    final durationValue = video['duration'];
    final duration = durationValue is int 
        ? durationValue 
        : (durationValue is double ? durationValue.toInt() : 0);
    final durationStr = _formatDuration(duration);

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
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1),
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
                            decoration: isHidden ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isHidden)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            
            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppTheme.getTextSecondary(context)),
              onSelected: (action) => _handleVideoAction(video, action),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'preview', child: Text('Preview Video')),
                PopupMenuItem(
                  value: isHidden ? 'show' : 'hide',
                  child: Text(isHidden ? 'Show Video' : 'Hide Video'),
                ),
                const PopupMenuItem(
                  value: 'flag',
                  child: Text('Flag Video'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Video', style: TextStyle(color: Colors.red)),
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
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
              ),
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
                  backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
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
                          ...List.generate(5, (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          )),
                          const SizedBox(width: 8),
                          Text(
                            createdAt != null
                                ? DateFormat('MMM d, y').format(
                                    DateTime.fromMillisecondsSinceEpoch(createdAt))
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  icon: Icon(Icons.more_vert, color: AppTheme.getTextSecondary(context), size: 20),
                  onSelected: (action) => _handleReviewAction(review, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: isHidden ? 'show' : 'hide',
                      child: Text(isHidden ? 'Show Review' : 'Hide Review'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Review', style: TextStyle(color: Colors.red)),
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
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
              ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap, bool isDark) {
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
      case 'view_teacher':
        await _viewTeacherProfile();
        break;
      case 'contact_teacher':
        await _contactTeacher();
        break;
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
    
    await _db.child('courses').child(widget.course.courseUid).update({
      'isPublished': newStatus,
    });
    await _db.child('teacher').child(widget.course.teacherUid)
        .child('courses').child(widget.course.courseUid).update({
      'isPublished': newStatus,
    });
    
    await _logAction(newStatus ? 'publish_course' : 'unpublish_course');
    
    // Send notification to teacher when course is unpublished
    if (!newStatus) {
      await _sendTeacherNotification(
        title: 'Course Unpublished',
        message: 'Your course "${widget.course.title}" has been unpublished by an administrator. Please contact support for more information.',
        type: 'course_unpublished',
      );
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Course ${newStatus ? 'published' : 'unpublished'}')),
      );
      Navigator.pop(context);
    }
  }

  /// View teacher profile in a dialog
  Future<void> _viewTeacherProfile() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );
    
    try {
      final snapshot = await _db.child('teacher').child(widget.course.teacherUid).get();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      if (!snapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher profile not found')),
        );
        return;
      }
      
      final teacherData = Map<String, dynamic>.from(snapshot.value as Map);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor).withOpacity(0.1),
                backgroundImage: teacherData['photoUrl'] != null 
                    ? NetworkImage(teacherData['photoUrl']) 
                    : null,
                child: teacherData['photoUrl'] == null
                    ? Text(
                        (teacherData['name'] ?? 'T')[0].toUpperCase(),
                        style: TextStyle(
                          color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacherData['name'] ?? 'Unknown Teacher',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    if (teacherData['headline'] != null)
                      Text(
                        teacherData['headline'],
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTeacherProfileRow('Email', teacherData['email'] ?? '-', isDark),
                _buildTeacherProfileRow(
                  'Status',
                  teacherData['isVerified'] == true ? 'Verified ✓' : 'Pending Verification',
                  isDark,
                ),
                if (teacherData['bio'] != null && teacherData['bio'].toString().isNotEmpty)
                  _buildTeacherProfileRow('Bio', teacherData['bio'], isDark),
                if (teacherData['subject'] != null)
                  _buildTeacherProfileRow('Subject', teacherData['subject'], isDark),
                if (teacherData['experience'] != null)
                  _buildTeacherProfileRow('Experience', '${teacherData['experience']} years', isDark),
                _buildTeacherProfileRow(
                  'Joined',
                  teacherData['createdAt'] != null
                      ? DateFormat('MMM dd, yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(teacherData['createdAt']))
                      : 'Unknown',
                  isDark,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _contactTeacher();
              },
              icon: const Icon(Icons.mail_outline, size: 18),
              label: const Text('Contact'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading teacher: $e')),
        );
      }
    }
  }

  Widget _buildTeacherProfileRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Contact teacher via email dialog
  Future<void> _contactTeacher() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectController = TextEditingController(
      text: 'Regarding your course: ${widget.course.title}',
    );
    final messageController = TextEditingController();
    
    // First fetch teacher email
    String? teacherEmail;
    String teacherName = _teacherName ?? 'Teacher';
    
    try {
      final snapshot = await _db.child('teacher').child(widget.course.teacherUid).child('email').get();
      if (snapshot.exists) {
        teacherEmail = snapshot.value.toString();
      }
      final nameSnapshot = await _db.child('teacher').child(widget.course.teacherUid).child('name').get();
      if (nameSnapshot.exists) {
        teacherName = nameSnapshot.value.toString();
      }
    } catch (e) {
      debugPrint('Error fetching teacher email: $e');
    }
    
    if (!mounted) return;
    
    if (teacherEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher email not found')),
      );
      return;
    }
    
    final parentContext = context;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.mail_outline,
              color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Contact Teacher',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'To: $teacherName ($teacherEmail)',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDark 
                        ? Colors.grey[800]!.withOpacity(0.3) 
                        : Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter your message to the teacher...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: isDark 
                        ? Colors.grey[800]!.withOpacity(0.3) 
                        : Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a message')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      // Send email via server
      try {
        final response = await http.post(
          Uri.parse('http://localhost:3001/send-admin-email'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'to': teacherEmail,
            'name': teacherName,
            'subject': subjectController.text,
            'emailType': 'admin_message',
            'message': messageController.text,
          }),
        );
        
        if (mounted) {
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email sent successfully'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Log the action
            await _logAction('contact_teacher');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send email: ${response.body}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending email: $e')),
          );
        }
      }
    }
    
    subjectController.dispose();
    messageController.dispose();
  }

  /// View course reports in a dialog
  Future<void> _viewCourseReports() async {
    final isDark = AppTheme.isDarkMode(context);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );
    
    try {
      // Check for reports about this course
      final reportsSnapshot = await _db.child('flagged_content')
          .orderByChild('courseUid')
          .equalTo(widget.course.courseUid)
          .get();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      List<Map<String, dynamic>> reports = [];
      if (reportsSnapshot.exists && reportsSnapshot.value != null) {
        final data = reportsSnapshot.value as Map;
        for (var entry in data.entries) {
          reports.add({
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          });
        }
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.flag, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Course Reports',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 300,
            child: reports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
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
                  )
                : ListView.builder(
                    itemCount: reports.length,
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return ListTile(
                        leading: Icon(Icons.report, color: Colors.red),
                        title: Text(report['reason'] ?? 'No reason'),
                        subtitle: Text(
                          report['createdAt'] != null
                              ? DateFormat('MMM d, yyyy').format(
                                  DateTime.fromMillisecondsSinceEpoch(report['createdAt']))
                              : 'Unknown date',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  /// View course analytics in a dialog
  Future<void> _viewCourseAnalytics() async {
    final isDark = AppTheme.isDarkMode(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.analytics,
              color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Course Analytics',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnalyticsRow(
                  'Total Students',
                  '${widget.course.enrolledCount}',
                  Icons.people,
                  Colors.blue,
                  isDark,
                ),
                _buildAnalyticsRow(
                  'Total Videos',
                  '${_videos.length}',
                  Icons.video_library,
                  Colors.purple,
                  isDark,
                ),
                _buildAnalyticsRow(
                  'Average Rating',
                  _calculatedRating.toStringAsFixed(1),
                  Icons.star,
                  Colors.amber,
                  isDark,
                ),
                _buildAnalyticsRow(
                  'Total Reviews',
                  '${_reviews.length}',
                  Icons.rate_review,
                  Colors.teal,
                  isDark,
                ),
                _buildAnalyticsRow(
                  'Course Price',
                  widget.course.isFree ? 'Free' : '\$${widget.course.price.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                  isDark,
                ),
                _buildAnalyticsRow(
                  'Est. Revenue',
                  widget.course.isFree 
                      ? '\$0.00' 
                      : '\$${(widget.course.price * widget.course.enrolledCount).toStringAsFixed(2)}',
                  Icons.monetization_on,
                  Colors.orange,
                  isDark,
                ),
                _buildAnalyticsRow(
                  'Platform Commission (20%)',
                  widget.course.isFree 
                      ? '\$0.00' 
                      : '\$${(widget.course.price * widget.course.enrolledCount * 0.2).toStringAsFixed(2)}',
                  Icons.account_balance,
                  Colors.indigo,
                  isDark,
                ),
                _buildAnalyticsRow(
                  'Status',
                  widget.course.isPublished ? 'Published' : 'Draft',
                  widget.course.isPublished ? Icons.check_circle : Icons.pending,
                  widget.course.isPublished ? Colors.green : Colors.orange,
                  isDark,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _flagCourse() async {
    // Implementation similar to AdminAllCoursesScreen
  }

  Future<void> _deleteCourse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Are you sure you want to delete "${widget.course.title}"? This action cannot be undone.'),
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
    
    if (confirm == true) {
      try {
        // Archive course before deleting for recovery purposes
        final courseData = (await _db.child('courses').child(widget.course.courseUid).get()).value;
        if (courseData != null) {
          await _db.child('deleted_courses').child(widget.course.courseUid).set({
            ...Map<String, dynamic>.from(courseData as Map),
            'deletedAt': ServerValue.timestamp,
          });
        }
        
        // Delete from courses collection
        await _db.child('courses').child(widget.course.courseUid).remove();
        // Delete from teacher's courses
        await _db.child('teacher').child(widget.course.teacherUid)
            .child('courses').child(widget.course.courseUid).remove();
        // Remove from any enrolled students' data (cascade)
        final enrolledSnapshot = await _db.child('student').get();
        if (enrolledSnapshot.exists && enrolledSnapshot.value != null) {
          final students = Map<String, dynamic>.from(enrolledSnapshot.value as Map);
          for (var studentId in students.keys) {
            // Remove from enrolled courses
            await _db.child('student/$studentId/enrolledCourses/${widget.course.courseUid}').remove();
          }
        }
        
        await _logAction('delete_course');
        
        // Send notification to teacher about course deletion
        await _sendTeacherNotification(
          title: 'Course Deleted',
          message: 'Your course "${widget.course.title}" has been removed by an administrator. If you believe this was an error, please contact support.',
          type: 'course_deleted',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course deleted successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting course: $e')),
          );
        }
      }
    }
  }

  void _handleVideoAction(Map<String, dynamic> video, String action) async {
    final videoId = video['id'];
    
    switch (action) {
      case 'preview':
        // Open video player dialog
        final videoUrl = video['url'] ?? video['videoUrl'];
        if (videoUrl != null && videoUrl.toString().isNotEmpty) {
          _showVideoPreviewDialog(video, videoUrl.toString());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No video URL available')),
          );
        }
        break;
      case 'hide':
      case 'show':
        final isHidden = action == 'hide';
        await _db.child('courses').child(widget.course.courseUid)
            .child('videos').child(videoId).update({'isHidden': isHidden});
        await _logAction(isHidden ? 'hide_video' : 'show_video', videoId);
        _loadVideos();
        break;
      case 'flag':
        // Flag video
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Video'),
            content: const Text('Are you sure? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            // Delete from both courses node and teacher's courses node
            await _db.child('courses').child(widget.course.courseUid)
                .child('videos').child(videoId).remove();
            await _db.child('teacher').child(widget.course.teacherUid)
                .child('courses').child(widget.course.courseUid)
                .child('videos').child(videoId).remove();
            await _logAction('delete_video', videoId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video deleted successfully')),
              );
            }
            _loadVideos();
          } catch (e) {
            debugPrint('Error deleting video: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete video: $e')),
              );
            }
          }
        }
        break;
    }
  }

  void _handleReviewAction(Map<String, dynamic> review, String action) async {
    final reviewId = review['id'];
    
    switch (action) {
      case 'hide':
      case 'show':
        final isHidden = action == 'hide';
        await _db.child('courses').child(widget.course.courseUid)
            .child('reviews').child(reviewId).update({'isHidden': isHidden});
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
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _db.child('courses').child(widget.course.courseUid)
              .child('reviews').child(reviewId).remove();
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _db.child('courses').child(widget.course.courseUid)
          .child('enrolledStudents').child(student['id']).remove();
      await _db.child('student').child(student['id'])
          .child('enrolledCourses').child(widget.course.courseUid).remove();
      await _logAction('remove_student', student['id']);
      _loadEnrolledStudents();
    }
  }

  Future<void> _logAction(String action, [String? targetId]) async {
    await _db.child('admin_logs').push().set({
      'action': action,
      'courseId': widget.course.courseUid,
      'targetId': targetId,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Send notification to teacher about course actions
  Future<void> _sendTeacherNotification({
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      // Add notification to teacher's notifications node
      await _db.child('notifications').child(widget.course.teacherUid).push().set({
        'title': title,
        'message': message,
        'type': type,
        'courseId': widget.course.courseUid,
        'isRead': false,
        'createdAt': ServerValue.timestamp,
      });

      // Also send email notification to teacher
      final teacherSnapshot = await _db.child('teacher').child(widget.course.teacherUid).get();
      if (teacherSnapshot.exists) {
        final teacherData = Map<String, dynamic>.from(teacherSnapshot.value as Map);
        final email = teacherData['email'];
        final name = teacherData['name'] ?? 'Teacher';
        
        if (email != null) {
          await http.post(
            Uri.parse('http://localhost:3001/send-admin-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': email,
              'name': name,
              'subject': 'EduVerse: $title',
              'emailType': 'course_notification',
              'message': message,
              'notificationType': type,
            }),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending teacher notification: $e');
    }
  }

  /// Format duration in a human-readable way
  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Show video preview dialog with actual video player
  void _showVideoPreviewDialog(Map<String, dynamic> video, String videoUrl) {
    final isDark = AppTheme.isDarkMode(context);
    final videoTitle = video['title']?.toString() ?? 'Video';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video['title'] ?? 'Video Preview',
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (video['description'] != null && video['description'].toString().isNotEmpty)
                            Text(
                              video['description'].toString(),
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Duration badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(
                              video['duration'] is int 
                                  ? video['duration'] 
                                  : (video['duration'] is double 
                                      ? (video['duration'] as double).toInt() 
                                      : 0)
                            ),
                            style: TextStyle(
                              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              
              // Video Player
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AdvancedVideoPlayer(
                      videoUrl: videoUrl,
                      videoTitle: videoTitle,
                    ),
                  ),
                ),
              ),
              
              // Footer with video info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.getTextSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin Preview Mode - This is how students will see this video',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Show video moderation options
                        _showVideoModerationOptions(video);
                      },
                      icon: const Icon(Icons.admin_panel_settings, size: 16),
                      label: const Text('Moderate'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Show video moderation options
  void _showVideoModerationOptions(Map<String, dynamic> video) {
    final isDark = AppTheme.isDarkMode(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moderation Options',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video['title'] ?? 'Video',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Flag for Review'),
              subtitle: const Text('Mark this video for content review'),
              onTap: () {
                Navigator.pop(context);
                _flagVideoForReview(video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.amber),
              title: Text(video['isPublic'] == false ? 'Make Public' : 'Make Private'),
              subtitle: Text(video['isPublic'] == false 
                  ? 'Allow students to access this video' 
                  : 'Hide this video from students'),
              onTap: () {
                Navigator.pop(context);
                _toggleVideoVisibility(video);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Video'),
              subtitle: const Text('Permanently remove this video'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteVideo(video);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _flagVideoForReview(Map<String, dynamic> video) async {
    try {
      await _db.child('moderation').child('videos').push().set({
        'videoId': video['id'],
        'courseId': widget.course.courseUid,
        'title': video['title'],
        'reason': 'Flagged by admin for review',
        'flaggedAt': ServerValue.timestamp,
        'status': 'pending',
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video flagged for review'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  void _toggleVideoVisibility(Map<String, dynamic> video) async {
    final newVisibility = !(video['isPublic'] ?? true);
    
    try {
      await _db.child('courses').child(widget.course.courseUid)
          .child('videos').child(video['id']).update({'isPublic': newVisibility});
      await _db.child('teacher').child(widget.course.teacherUid)
          .child('courses').child(widget.course.courseUid)
          .child('videos').child(video['id']).update({'isPublic': newVisibility});
      
      _loadVideos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newVisibility ? 'Video is now public' : 'Video is now private'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  void _confirmDeleteVideo(Map<String, dynamic> video) {
    final isDark = AppTheme.isDarkMode(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Video'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${video['title']}"? This action cannot be undone.',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
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
            onPressed: () async {
              Navigator.pop(context);
              await _deleteVideo(video);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    try {
      await _db.child('courses').child(widget.course.courseUid)
          .child('videos').child(video['id']).remove();
      await _db.child('teacher').child(widget.course.teacherUid)
          .child('courses').child(widget.course.courseUid)
          .child('videos').child(video['id']).remove();
      
      await _logAction('delete_video', video['id']);
      _loadVideos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting video: $e')),
        );
      }
    }
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppTheme.darkSurface : Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
