import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/theme_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:eduverse/services/preferences_service.dart';
import 'package:eduverse/services/analytics_service.dart';
import 'package:eduverse/views/signin_screen.dart';
import 'package:eduverse/views/student/courses_screen.dart';
import 'package:eduverse/views/student/home_tab.dart';
import 'package:eduverse/views/student/student_edit_profile_screen.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;
  final String role;
  const ProfileScreen({super.key, required this.uid, required this.role});

  // Static cache to persist data across widget rebuilds
  static Map<String, dynamic>? cachedProfileData;
  static String? cachedUid; // Track which user's data is cached
  static bool hasLoadedOnce = false;

  /// Clear static cache from outside - call this when progress changes
  static void clearCache() {
    cachedProfileData = null;
    cachedUid = null;
    hasLoadedOnce = false;
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final _cacheService = CacheService();

  bool _isInitialLoading = true;

  String userName = "...";
  String userRole = "student";
  String email = "...";
  int? enrolledCourses;
  int? joinedDate;
  int completedCourses = 0;
  double overallProgress = 0.0;

  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Timer? _autoRefreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 10);

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Use cached data immediately if available
    if (ProfileScreen.hasLoadedOnce &&
        ProfileScreen.cachedProfileData != null) {
      userName = ProfileScreen.cachedProfileData!['userName'] ?? "...";
      email = ProfileScreen.cachedProfileData!['email'] ?? "...";
      userRole = widget.role;
      joinedDate = ProfileScreen.cachedProfileData!['joinedDate'];
      enrolledCourses = ProfileScreen.cachedProfileData!['enrolledCourses'];
      completedCourses =
          ProfileScreen.cachedProfileData!['completedCourses'] ?? 0;
      overallProgress =
          ProfileScreen.cachedProfileData!['overallProgress'] ?? 0.0;
      _isInitialLoading = false;
    }

    fetchUserData();

    // Start periodic auto-refresh
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        fetchUserData(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData({bool forceRefresh = false}) async {
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cacheKey = 'profile_data_$uid';

    // Use static cache if available and not forcing refresh
    // IMPORTANT: Verify cached data belongs to current user
    if (!forceRefresh &&
        ProfileScreen.hasLoadedOnce &&
        ProfileScreen.cachedProfileData != null &&
        ProfileScreen.cachedUid == uid) {
      if (mounted) {
        setState(() {
          userName = ProfileScreen.cachedProfileData!['userName'] ?? "...";
          email = ProfileScreen.cachedProfileData!['email'] ?? "...";
          userRole = widget.role;
          joinedDate = ProfileScreen.cachedProfileData!['joinedDate'];
          enrolledCourses = ProfileScreen.cachedProfileData!['enrolledCourses'];
          completedCourses =
              ProfileScreen.cachedProfileData!['completedCourses'] ?? 0;
          overallProgress =
              ProfileScreen.cachedProfileData!['overallProgress'] ?? 0.0;
          _isInitialLoading = false;
        });
      }
      return;
    }

    // Check cache first for instant display
    if (!forceRefresh) {
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        ProfileScreen.cachedProfileData = cachedData;
        ProfileScreen.cachedUid = uid;
        ProfileScreen.hasLoadedOnce = true;

        if (mounted) {
          setState(() {
            userName = cachedData['userName'] ?? "...";
            email = cachedData['email'] ?? "...";
            userRole = widget.role;
            joinedDate = cachedData['joinedDate'];
            enrolledCourses = cachedData['enrolledCourses'];
            completedCourses = cachedData['completedCourses'] ?? 0;
            overallProgress = cachedData['overallProgress'] ?? 0.0;
            _isInitialLoading = false;
          });
        }
        // Refresh in background
        _refreshProfileInBackground(uid, cacheKey);
        return;
      }
    }

    // Show loading only if no data yet
    if (!mounted) return;
    if (userName == "...") {
      setState(() => _isInitialLoading = true);
    }

    try {
      final userData = await UserService().getUser(uid: uid, role: widget.role);

      if (!mounted) return;

      if (userData != null) {
        // Calculate course progress in parallel for faster loading
        final courseService = CourseService();
        final enrolledCoursesList = await courseService.getEnrolledCourses(
          studentUid: uid,
        );

        if (!mounted) return;

        int completed = 0;
        double totalProgress = 0.0;

        // Calculate progress in parallel instead of sequential
        if (enrolledCoursesList.isNotEmpty) {
          final progressFutures = enrolledCoursesList
              .map(
                (course) => courseService.calculateCourseProgress(
                  studentUid: uid,
                  courseUid: course['courseUid'],
                ),
              )
              .toList();

          final progressResults = await Future.wait(progressFutures);

          for (final progress in progressResults) {
            totalProgress += progress;
            if (progress >= 1.0) completed++;
          }
        }

        final avgProgress = enrolledCoursesList.isNotEmpty
            ? totalProgress / enrolledCoursesList.length
            : 0.0;

        if (!mounted) return;

        // Cache the data
        final profileData = {
          'userName': userData['name'],
          'email': userData['email'],
          'joinedDate': userData['createdAt'],
          'enrolledCourses': enrolledCoursesList.length,
          'completedCourses': completed,
          'overallProgress': avgProgress,
        };

        _cacheService.set(cacheKey, profileData);

        // Update static cache
        ProfileScreen.cachedProfileData = profileData;
        ProfileScreen.hasLoadedOnce = true;

        setState(() {
          userName = userData['name'] ?? "...";
          email = userData['email'] ?? "...";
          userRole = widget.role;
          joinedDate = userData['createdAt'];
          enrolledCourses = enrolledCoursesList.length;
          completedCourses = completed;
          overallProgress = avgProgress;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load user data: $e")));
    }
  }

  Future<void> _refreshProfileInBackground(String uid, String cacheKey) async {
    try {
      final userData = await UserService().getUser(uid: uid, role: widget.role);
      if (userData == null) return;

      final courseService = CourseService();
      final enrolledCoursesList = await courseService.getEnrolledCourses(
        studentUid: uid,
      );

      int completed = 0;
      double totalProgress = 0.0;

      // Calculate progress in parallel instead of sequential
      if (enrolledCoursesList.isNotEmpty) {
        final progressFutures = enrolledCoursesList
            .map(
              (course) => courseService.calculateCourseProgress(
                studentUid: uid,
                courseUid: course['courseUid'],
              ),
            )
            .toList();

        final progressResults = await Future.wait(progressFutures);

        for (final progress in progressResults) {
          totalProgress += progress;
          if (progress >= 1.0) completed++;
        }
      }

      final avgProgress = enrolledCoursesList.isNotEmpty
          ? totalProgress / enrolledCoursesList.length
          : 0.0;

      final profileData = {
        'userName': userData['name'],
        'email': userData['email'],
        'joinedDate': userData['createdAt'],
        'enrolledCourses': enrolledCoursesList.length,
        'completedCourses': completed,
        'overallProgress': avgProgress,
      };

      _cacheService.set(cacheKey, profileData);

      // Update static cache
      ProfileScreen.cachedProfileData = profileData;
      ProfileScreen.cachedUid = uid;
      ProfileScreen.hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          userName = userData['name'] ?? "...";
          email = userData['email'] ?? "...";
          joinedDate = userData['createdAt'];
          enrolledCourses = enrolledCoursesList.length;
          completedCourses = completed;
          overallProgress = avgProgress;
        });
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  void _showEditProfileDialog() async {
    // Fetch current user data to pre-populate the edit form
    final userData = await UserService().getUser(uid: widget.uid, role: widget.role);
    
    if (!mounted) return;
    
    // Navigate to comprehensive edit profile screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentEditProfileScreen(
          uid: widget.uid,
          currentName: userName,
          currentPhotoUrl: userData?['photoUrl'],
          currentHeadline: userData?['headline'],
          currentBio: userData?['bio'],
          currentInterests: userData?['interests'] != null
              ? List<String>.from(userData!['interests'] as List)
              : null,
          currentLinkedIn: userData?['linkedIn'],
          currentGitHub: userData?['gitHub'],
        ),
      ),
    );

    // Refresh profile if updated
    if (result == true) {
      fetchUserData(forceRefresh: true);
    }
  }

  void _showChangePasswordDialog() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    final isDark = AppTheme.isDarkMode(context);

    // State variables for the dialog
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    String? currentPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Check password match
          void validatePasswords() {
            setDialogState(() {
              if (_newPasswordController.text.isNotEmpty &&
                  _newPasswordController.text.length < 6) {
                newPasswordError = 'Password must be at least 6 characters';
              } else {
                newPasswordError = null;
              }

              if (_confirmPasswordController.text.isNotEmpty &&
                  _newPasswordController.text !=
                      _confirmPasswordController.text) {
                confirmPasswordError = 'Passwords do not match';
              } else {
                confirmPasswordError = null;
              }
            });
          }

          return AlertDialog(
            backgroundColor: AppTheme.getCardColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lock,
                  color: isDark
                      ? AppTheme.darkPrimaryLight
                      : AppTheme.primaryColor,
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
                  // Current Password
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    onChanged: (_) {
                      if (currentPasswordError != null) {
                        setDialogState(() => currentPasswordError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                      errorText: currentPasswordError,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: currentPasswordError != null
                            ? Theme.of(context).colorScheme.error
                            : AppTheme.getTextSecondary(context),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrentPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureCurrentPassword = !obscureCurrentPassword;
                          });
                        },
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
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Password
                  TextField(
                    controller: _newPasswordController,
                    obscureText: obscureNewPassword,
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    onChanged: (_) => validatePasswords(),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                      errorText: newPasswordError,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: newPasswordError != null
                            ? Theme.of(context).colorScheme.error
                            : AppTheme.getTextSecondary(context),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureNewPassword = !obscureNewPassword;
                          });
                        },
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
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm New Password
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    onChanged: (_) => validatePasswords(),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                      errorText: confirmPasswordError,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: confirmPasswordError != null
                            ? Theme.of(context).colorScheme.error
                            : (_confirmPasswordController.text.isNotEmpty &&
                                  _newPasswordController.text ==
                                      _confirmPasswordController.text)
                            ? Colors.green
                            : AppTheme.getTextSecondary(context),
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Match indicator
                          if (_confirmPasswordController.text.isNotEmpty)
                            Icon(
                              _newPasswordController.text ==
                                      _confirmPasswordController.text
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color:
                                  _newPasswordController.text ==
                                      _confirmPasswordController.text
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                          IconButton(
                            icon: Icon(
                              obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.getTextSecondary(context),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureConfirmPassword =
                                    !obscureConfirmPassword;
                              });
                            },
                          ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _confirmPasswordController.text.isNotEmpty
                              ? (_newPasswordController.text ==
                                        _confirmPasswordController.text
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error)
                              : AppTheme.getBorderColor(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _confirmPasswordController.text.isNotEmpty
                              ? (_newPasswordController.text ==
                                        _confirmPasswordController.text
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error)
                              : (isDark
                                    ? AppTheme.darkPrimaryLight
                                    : AppTheme.primaryColor),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
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
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        // Validate all fields
                        bool hasError = false;

                        if (_currentPasswordController.text.isEmpty) {
                          setDialogState(
                            () => currentPasswordError =
                                'Please enter current password',
                          );
                          hasError = true;
                        }

                        if (_newPasswordController.text.isEmpty) {
                          setDialogState(
                            () =>
                                newPasswordError = 'Please enter new password',
                          );
                          hasError = true;
                        } else if (_newPasswordController.text.length < 6) {
                          setDialogState(
                            () => newPasswordError =
                                'Password must be at least 6 characters',
                          );
                          hasError = true;
                        }

                        if (_confirmPasswordController.text.isEmpty) {
                          setDialogState(
                            () => confirmPasswordError =
                                'Please confirm new password',
                          );
                          hasError = true;
                        } else if (_newPasswordController.text !=
                            _confirmPasswordController.text) {
                          setDialogState(
                            () =>
                                confirmPasswordError = 'Passwords do not match',
                          );
                          hasError = true;
                        }

                        if (hasError) return;

                        setDialogState(() => isLoading = true);

                        try {
                          final user = FirebaseAuth.instance.currentUser!;
                          final credential = EmailAuthProvider.credential(
                            email: user.email!,
                            password: _currentPasswordController.text,
                          );
                          await user.reauthenticateWithCredential(credential);
                          await user.updatePassword(
                            _newPasswordController.text,
                          );

                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              currentPasswordError =
                                  'Incorrect current password';
                            } else {
                              currentPasswordError =
                                  e.message ?? 'Authentication failed';
                            }
                          });
                        } catch (e) {
                          setDialogState(() {
                            isLoading = false;
                            currentPasswordError =
                                'Failed to change password. Please check your current password.';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: const Color(0xFFF0F8FF),
                  elevation: 6,
                  shadowColor:
                      (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                          .withOpacity(0.5),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Change'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isDark = AppTheme.isDarkMode(context);

    if (_isInitialLoading) {
      return const Center(
        child: EngagingLoadingIndicator(
          message: 'Loading profile...',
          size: 70,
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
                    child: Text(
                      userRole.toUpperCase(),
                      style: const TextStyle(
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        "Enrolled",
                        enrolledCourses?.toString() ?? "0",
                        Icons.book,
                      ),
                      Container(
                        height: 50,
                        width: 1,
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                      ),
                      _buildStatItem(
                        "Completed",
                        completedCourses.toString(),
                        Icons.check_circle_outline,
                      ),
                      Container(
                        height: 50,
                        width: 1,
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                      ),
                      _buildStatItem(
                        "Progress",
                        "${(overallProgress * 100).toInt()}%",
                        Icons.trending_up,
                      ),
                    ],
                  ),
                  if (enrolledCourses != null && enrolledCourses! > 0) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: overallProgress,
                        backgroundColor: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overallProgress >= 1.0
                              ? AppTheme.success
                              : (isDark
                                    ? AppTheme.darkAccentColor
                                    : AppTheme.accentColor),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overallProgress >= 1.0
                          ? '🎉 All courses completed!'
                          : '$completedCourses of $enrolledCourses courses completed',
                      style: TextStyle(
                        color: overallProgress >= 1.0
                            ? AppTheme.success
                            : AppTheme.getTextSecondary(context),
                        fontSize: 12,
                        fontWeight: overallProgress >= 1.0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
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
                    _showHelpSupportDialog,
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

  void _showLogoutDialog(BuildContext context) async {
    // Check if user wants to skip confirmation
    final shouldSkip = await PreferencesService.shouldSkipLogoutConfirm();
    if (shouldSkip) {
      _performLogout();
      return;
    }

    bool dontShowAgain = false;
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLogoutState) {
          return AlertDialog(
            backgroundColor: AppTheme.getCardColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.logout,
                  color: isDark ? AppTheme.darkError : AppTheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  "Logout",
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Are you sure you want to logout?",
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
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
                          setLogoutState(() => dontShowAgain = value ?? false);
                        },
                        activeColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Don't show this again",
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
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
                  "Cancel",
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (dontShowAgain) {
                    await PreferencesService.setSkipLogoutConfirm(true);
                  }
                  Navigator.pop(ctx);
                  _performLogout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.error,
                  foregroundColor: const Color(0xFFF0F8FF),
                  elevation: 6,
                  shadowColor: (isDark ? AppTheme.darkAccent : AppTheme.error)
                      .withOpacity(0.5),
                ),
                child: const Text("Logout"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      // Clear all static caches to prevent data leakage between users
      // Do this BEFORE signing out so we still have user context if needed
      try {
        ProfileScreen.clearCache();
        CoursesScreen.clearCache();
        HomeTab.clearCache();
        AnalyticsService.clearCache();
        CacheService().clearAllOnLogout();
      } catch (cacheError) {
        debugPrint('Cache clearing error: $cacheError');
        // Continue with logout even if cache clearing fails
      }

      // Sign out from Firebase
      try {
        await FirebaseAuth.instance.signOut();
      } catch (signOutError) {
        debugPrint('Sign out error: $signOutError');
        // Continue to navigate away even if signout throws
      }

      if (!mounted) return;

      // Navigate to sign in screen and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SigninScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
    }
  }

  void _showHelpSupportDialog() {
    final isDark = AppTheme.isDarkMode(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppTheme.darkAccent, AppTheme.darkPrimaryLight]
                        : [AppTheme.primaryColor, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.help_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Help & Support',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'How can we assist you?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FAQs Section
                      Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFaqItem(
                        'How do I enroll in a course?',
                        'Browse courses in the Explore section, tap on any course you like, and click "Enroll" to start learning immediately.',
                        isDark,
                      ),
                      _buildFaqItem(
                        'How can I track my progress?',
                        'Your course progress is shown on each course card and in the course player. You can also see overall progress in your profile.',
                        isDark,
                      ),
                      _buildFaqItem(
                        'How do I leave a review?',
                        'After completing some videos in a course, you can leave a review by going to the course details and tapping the review option.',
                        isDark,
                      ),
                      _buildFaqItem(
                        'Can I download videos for offline viewing?',
                        'Currently, videos are available for streaming only. Offline viewing feature is coming soon!',
                        isDark,
                      ),
                      _buildFaqItem(
                        'How do I change my profile information?',
                        'Go to Profile > Edit Profile to update your name, profile picture, and other details.',
                        isDark,
                      ),

                      const SizedBox(height: 20),
                      Divider(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade300,
                      ),
                      const SizedBox(height: 20),

                      // Contact Section
                      Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildContactTile(
                        Icons.email_outlined,
                        'Email Support',
                        'eduverse.company@gmail.com',
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email copied to clipboard'),
                            ),
                          );
                        },
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildContactTile(
                        Icons.access_time,
                        'Response Time',
                        'Usually within 24-48 hours',
                        null,
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildContactTile(
                        Icons.info_outline,
                        'App Version',
                        '1.0.0',
                        null,
                        isDark,
                      ),

                      const SizedBox(height: 20),
                      Divider(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade300,
                      ),
                      const SizedBox(height: 20),

                      // Tips Section
                      Text(
                        'Learning Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTipItem(
                        '📚',
                        'Set a daily learning goal to stay consistent',
                        isDark,
                      ),
                      _buildTipItem(
                        '⭐',
                        'Leave reviews to help other students and instructors',
                        isDark,
                      ),
                      _buildTipItem(
                        '🔔',
                        'Enable notifications to never miss course updates',
                        isDark,
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

  Widget _buildFaqItem(String question, String answer, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          iconColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          collapsedIconColor: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.textSecondary,
          children: [
            Text(
              answer,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy,
                size: 16,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String emoji, String tip, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
