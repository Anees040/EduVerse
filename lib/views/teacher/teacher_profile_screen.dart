import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/theme_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/views/signin_screen.dart';
import 'package:eduverse/utils/app_theme.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String uid;
  final String role;
  const TeacherProfileScreen({
    super.key,
    required this.uid,
    required this.role,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  final _cacheService = CacheService();
  String userName = "...";
  String email = "...";
  int? joinedDate;
  int totalCourses = 0;
  int totalStudents = 0;
  double averageRating = 0.0;
  int reviewCount = 0;

  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cacheKey = 'teacher_profile_$uid';

    // Check cache first
    final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
    if (cachedData != null) {
      setState(() {
        userName = cachedData['userName'] ?? "Teacher";
        email = cachedData['email'] ?? "...";
        joinedDate = cachedData['joinedDate'];
        totalCourses = cachedData['totalCourses'] ?? 0;
        totalStudents = cachedData['totalStudents'] ?? 0;
        averageRating = cachedData['averageRating'] ?? 0.0;
        reviewCount = cachedData['reviewCount'] ?? 0;
        isLoading = false;
      });
      // Refresh in background
      _refreshProfileInBackground(uid, cacheKey);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Load all data in parallel
      final results = await Future.wait([
        UserService().getUser(uid: uid, role: widget.role),
        CourseService().getTeacherCourses(teacherUid: uid),
        CourseService().getUniqueStudentCount(teacherUid: uid),
        CourseService().getTeacherRatingStats(teacherUid: uid),
      ]);

      final userData = results[0] as Map<String, dynamic>?;
      final courses = results[1] as List<Map<String, dynamic>>;
      final uniqueStudents = results[2] as int;
      final ratingStats = results[3] as Map<String, dynamic>;

      if (userData != null) {
        // Cache the data
        _cacheService.set(cacheKey, {
          'userName': userData['name'],
          'email': userData['email'],
          'joinedDate': userData['createdAt'],
          'totalCourses': courses.length,
          'totalStudents': uniqueStudents,
          'averageRating': ratingStats['averageRating'] ?? 0.0,
          'reviewCount': ratingStats['reviewCount'] ?? 0,
        });

        setState(() {
          userName = userData['name'] ?? "Teacher";
          email = userData['email'] ?? "...";
          joinedDate = userData['createdAt'];
          totalCourses = courses.length;
          totalStudents = uniqueStudents;
          averageRating = ratingStats['averageRating'] ?? 0.0;
          reviewCount = ratingStats['reviewCount'] ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load user data: $e")));
    }
  }

  Future<void> _refreshProfileInBackground(String uid, String cacheKey) async {
    try {
      final results = await Future.wait([
        UserService().getUser(uid: uid, role: widget.role),
        CourseService().getTeacherCourses(teacherUid: uid),
        CourseService().getUniqueStudentCount(teacherUid: uid),
        CourseService().getTeacherRatingStats(teacherUid: uid),
      ]);

      final userData = results[0] as Map<String, dynamic>?;
      final courses = results[1] as List<Map<String, dynamic>>;
      final uniqueStudents = results[2] as int;
      final ratingStats = results[3] as Map<String, dynamic>;

      if (userData != null) {
        _cacheService.set(cacheKey, {
          'userName': userData['name'],
          'email': userData['email'],
          'joinedDate': userData['createdAt'],
          'totalCourses': courses.length,
          'totalStudents': uniqueStudents,
          'averageRating': ratingStats['averageRating'] ?? 0.0,
          'reviewCount': ratingStats['reviewCount'] ?? 0,
        });

        if (mounted) {
          setState(() {
            userName = userData['name'] ?? "Teacher";
            email = userData['email'] ?? "...";
            joinedDate = userData['createdAt'];
            totalCourses = courses.length;
            totalStudents = uniqueStudents;
            averageRating = ratingStats['averageRating'] ?? 0.0;
            reviewCount = ratingStats['reviewCount'] ?? 0;
          });
        }
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  void _showEditProfileDialog() {
    _nameController.text = userName;
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.edit,
              color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
            ),
            const SizedBox(width: 10),
            Text(
              'Edit Profile',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                ),
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: AppTheme.getTextSecondary(context),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
              try {
                await UserService().updateUserName(
                  uid: widget.uid,
                  role: widget.role,
                  name: _nameController.text.trim(),
                );
                Navigator.pop(ctx);
                fetchUserData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update profile: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkPrimaryLight
                  : AppTheme.primaryColor,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.lock,
              color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
            ),
            const SizedBox(width: 10),
            Text(
              'Change Password',
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
              if (_newPasswordController.text !=
                  _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match')),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser!;
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: _currentPasswordController.text,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(_newPasswordController.text);

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password changed successfully!'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to change password: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkPrimaryLight
                  : AppTheme.primaryColor,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isDark = AppTheme.isDarkMode(context);

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
        ),
      );
    }

    return Container(
      color: AppTheme.getBackgroundColor(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.darkPrimaryGradient
                    : AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor)
                            .withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : "?",
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "TEACHER",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User Details Card
            Container(
              decoration: AppTheme.getCardDecoration(context),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildInfoRow(Icons.email_outlined, "Email", email),
                  Divider(height: 24, color: AppTheme.getBorderColor(context)),
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    "Joined",
                    joinedDate != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            joinedDate!,
                          ).toLocal().toString().split(' ')[0]
                        : "N/A",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Statistics Card
            Container(
              decoration: AppTheme.getCardDecoration(context),
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    "Courses",
                    totalCourses.toString(),
                    Icons.book,
                  ),
                  Container(
                    height: 50,
                    width: 1,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  ),
                  _buildStatItem(
                    "Students",
                    totalStudents.toString(),
                    Icons.people,
                  ),
                  Container(
                    height: 50,
                    width: 1,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  ),
                  _buildStatItem(
                    "Rating",
                    reviewCount > 0
                        ? "${averageRating.toStringAsFixed(1)} ($reviewCount)"
                        : "No reviews",
                    Icons.star,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Actions Card
            Container(
              decoration: AppTheme.getCardDecoration(context),
              child: Column(
                children: [
                  // Dark Mode Toggle
                  Consumer<ThemeService>(
                    builder: (context, themeService, child) {
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppTheme.darkPrimaryLight
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            themeService.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          "Dark Mode",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          themeService.isDarkMode ? "On" : "Off",
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Switch(
                          value: themeService.isDarkMode,
                          onChanged: (_) => themeService.toggleTheme(),
                          activeColor: isDark
                              ? AppTheme.darkAccentColor
                              : AppTheme.accentColor,
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: AppTheme.getBorderColor(context)),
                  _buildActionTile(
                    Icons.lock_outline,
                    "Change Password",
                    "Update your security credentials",
                    _showChangePasswordDialog,
                  ),
                  Divider(height: 1, color: AppTheme.getBorderColor(context)),
                  _buildActionTile(
                    Icons.help_outline,
                    "Help & Support",
                    "Get assistance and FAQs",
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Help & Support coming soon"),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: AppTheme.getBorderColor(context)),
                  _buildActionTile(
                    Icons.logout,
                    "Logout",
                    "Sign out of your account",
                    () => _showLogoutDialog(context),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = AppTheme.isDarkMode(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    final isDark = AppTheme.isDarkMode(context);
    return Column(
      children: [
        Icon(
          icon,
          color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    final color = isDestructive
        ? AppTheme.error
        : (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive
              ? AppTheme.error
              : AppTheme.getTextPrimary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppTheme.getTextSecondary(context),
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppTheme.getTextSecondary(context),
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Logout",
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SigninScreen()),
                  (route) => false,
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}
