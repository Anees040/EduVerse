import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/views/student/ai_camera_screen.dart';
import 'package:eduverse/views/student/ai_chat_screen.dart';
import 'package:eduverse/views/student/student_course_detail_screen.dart';
import 'package:eduverse/utils/app_theme.dart';

class HomeTab extends StatefulWidget {
  final String uid;
  final String role;
  final VoidCallback? onSeeAllCourses;
  const HomeTab({
    super.key,
    required this.uid,
    required this.role,
    this.onSeeAllCourses,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with AutomaticKeepAliveClientMixin {
  final userService = UserService();
  final _cacheService = CacheService();
  String userName = "...";

  List<Map<String, dynamic>> featuredCourses = [];
  List<Map<String, dynamic>> continueCourses = [];
  bool isLoading = true;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Keep tab alive to avoid reloading
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load all data in parallel for faster loading
  Future<void> _loadAllData() async {
    final studentUid = FirebaseAuth.instance.currentUser!.uid;
    final cacheKeyName = 'user_name_${widget.uid}';
    final cacheKeyCourses = 'enrolled_courses_$studentUid';

    // Check cache first for instant display
    final cachedName = _cacheService.get<String>(cacheKeyName);
    final cachedCourses = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyCourses,
    );

    if (cachedName != null && cachedCourses != null) {
      setState(() {
        userName = cachedName;
        featuredCourses = cachedCourses;
        isLoading = false;
      });
      // Refresh in background
      _refreshDataInBackground(studentUid, cacheKeyName, cacheKeyCourses);
      return;
    }

    // Load in parallel
    try {
      final results = await Future.wait([
        userService.getUserName(uid: widget.uid, role: widget.role),
        CourseService().getEnrolledCourses(studentUid: studentUid),
      ]);

      final name = results[0] as String? ?? "Student";
      final courses = results[1] as List<Map<String, dynamic>>;

      // Cache the results
      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, courses);

      if (mounted) {
        setState(() {
          userName = name;
          featuredCourses = courses;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load data: $e")));
      }
    }
  }

  /// Refresh data in background without blocking UI
  Future<void> _refreshDataInBackground(
    String studentUid,
    String cacheKeyName,
    String cacheKeyCourses,
  ) async {
    try {
      final results = await Future.wait([
        userService.getUserName(uid: widget.uid, role: widget.role),
        CourseService().getEnrolledCourses(studentUid: studentUid),
      ]);

      final name = results[0] as String? ?? "Student";
      final courses = results[1] as List<Map<String, dynamic>>;

      _cacheService.set(cacheKeyName, name);
      _cacheService.set(cacheKeyCourses, courses);

      if (mounted) {
        setState(() {
          userName = name;
          featuredCourses = courses;
        });
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  List<Map<String, dynamic>> get filteredCourses {
    if (searchQuery.isEmpty) return featuredCourses;
    return featuredCourses.where((course) {
      final title = (course['title'] as String? ?? '').toLowerCase();
      final description = (course['description'] as String? ?? '')
          .toLowerCase();
      final query = searchQuery.toLowerCase();
      return title.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final isDark = AppTheme.isDarkMode(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.getGradient(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello, $userName!",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Continue your learning journey today",
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: isDark
                  ? Border.all(color: AppTheme.darkBorderColor)
                  : null,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Search your courses...",
                hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchQuery = "";
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.getCardColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Featured Courses
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Your Courses",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              TextButton(
                onPressed: widget.onSeeAllCourses,
                child: const Text("See All"),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 200,
            child: filteredCourses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.book_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? "No courses match '$searchQuery'"
                              : "No enrolled courses yet",
                          style: TextStyle(color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredCourses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final course = filteredCourses[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentCourseDetailScreen(
                                courseUid: course['courseUid'],
                                courseTitle: course['title'] ?? 'Course',
                                imageUrl: course['imageUrl'] ?? '',
                                description: course['description'] ?? '',
                                createdAt: course['createdAt'],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 170,
                          decoration: BoxDecoration(
                            color: AppTheme.getCardColor(context),
                            borderRadius: BorderRadius.circular(20),
                            border: isDark
                                ? Border.all(color: AppTheme.darkBorderColor)
                                : null,
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                                child: Image.network(
                                  course['imageUrl'] as String,
                                  height: 100,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.1,
                                    ),
                                    child: const Icon(
                                      Icons.image,
                                      size: 40,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course['title'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.getTextPrimary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    // Teacher info
                                    if (course['teacherName'] != null) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              course['teacherName'],
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    // Teacher rating
                                    if (course['teacherRating'] != null &&
                                        course['teacherRating'] > 0) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 11,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${(course['teacherRating'] as num).toStringAsFixed(1)}${course['reviewCount'] != null ? ' (${course['reviewCount']})' : ''}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.getTextSecondary(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 28),

          // AI Learning Section
          Text(
            "AI Learning Tools",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),

          // Study with AI Card
          _buildFeatureCard(
            icon: Icons.smart_toy_outlined,
            title: "Study with AI",
            subtitle: "Chat with our AI assistant for personalized help",
            color: AppTheme.primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIChatScreen()),
              );
            },
          ),

          const SizedBox(height: 12),

          // Homework Help Card
          _buildFeatureCard(
            icon: Icons.camera_alt_outlined,
            title: "Homework Help",
            subtitle: "Snap a photo and get step-by-step solutions",
            color: AppTheme.accentColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MathwayHelpScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    
    // Use brighter, more vibrant colors in dark mode
    final displayColor = isDark 
        ? (color == AppTheme.primaryColor 
            ? const Color(0xFF9B7DFF) // Brighter purple/violet for AI
            : const Color(0xFF4ECDC4)) // Vibrant teal for homework
        : color;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? displayColor.withOpacity(0.3) : color.withOpacity(0.2),
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: displayColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isDark 
                    ? LinearGradient(
                        colors: [
                          displayColor.withOpacity(0.25),
                          displayColor.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isDark ? null : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: isDark 
                    ? Border.all(color: displayColor.withOpacity(0.3))
                    : null,
              ),
              child: Icon(icon, color: displayColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? displayColor.withOpacity(0.7) : AppTheme.getTextSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
